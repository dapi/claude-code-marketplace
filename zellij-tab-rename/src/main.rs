use serde::Deserialize;
use std::collections::BTreeMap;
use zellij_tile::prelude::*;

#[derive(Debug, Deserialize)]
struct RenamePayload {
    pane_id: String,
    name: String,
}

#[derive(Debug, Deserialize)]
struct StatusPayload {
    pane_id: String,
    action: String,
    #[serde(default)]
    emoji: String,
}

#[derive(Default)]
struct State {
    /// Maps pane_id -> (tab_position, tab_name)
    pane_to_tab: BTreeMap<u32, (usize, String)>,

    /// Current tabs info
    tabs: Vec<TabInfo>,

    /// Current panes info
    panes: PaneManifest,
}

register_plugin!(State);

impl ZellijPlugin for State {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        eprintln!("[tab-rename] Plugin loaded");

        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
        subscribe(&[EventType::TabUpdate, EventType::PaneUpdate]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::TabUpdate(tabs) => {
                eprintln!("[tab-rename] TabUpdate: {} tabs", tabs.len());
                self.tabs = tabs;
                self.rebuild_mapping();
            }
            Event::PaneUpdate(panes) => {
                eprintln!("[tab-rename] PaneUpdate: {} tab entries", panes.panes.len());
                self.panes = panes;
                self.rebuild_mapping();
            }
            _ => {}
        }
        false
    }

    fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
        eprintln!("[tab-rename] Pipe: name={}, payload={:?}",
            pipe_message.name, pipe_message.payload);

        match pipe_message.name.as_str() {
            "tab-rename" => self.handle_rename(&pipe_message.payload),
            "tab-status" => self.handle_status(&pipe_message.payload),
            _ => false,
        }
    }

    fn render(&mut self, _rows: usize, _cols: usize) {}
}

impl State {
    fn handle_rename(&mut self, payload: &Option<String>) -> bool {
        let Some(payload) = payload else {
            eprintln!("[tab-rename] ERROR: missing payload");
            return false;
        };

        let rename: RenamePayload = match serde_json::from_str(payload) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("[tab-rename] ERROR: invalid JSON: {}", e);
                return false;
            }
        };

        let pane_id: u32 = match rename.pane_id.parse() {
            Ok(id) => id,
            Err(_) => {
                eprintln!("[tab-rename] ERROR: pane_id must be a number");
                return false;
            }
        };

        eprintln!("[tab-rename] Looking for pane_id={} in {} mappings",
            pane_id, self.pane_to_tab.len());

        let Some(&(tab_position, _)) = self.pane_to_tab.get(&pane_id) else {
            eprintln!("[tab-rename] ERROR: pane {} not found. Known panes: {:?}",
                pane_id, self.pane_to_tab.keys().collect::<Vec<_>>());
            return false;
        };

        // tab_id for rename_tab is 1-indexed position
        let tab_id = (tab_position + 1) as u32;

        eprintln!("[tab-rename] Renaming tab {} (position {}) to '{}'",
            tab_id, tab_position, rename.name);

        rename_tab(tab_id, rename.name);

        false
    }

    fn handle_status(&mut self, payload: &Option<String>) -> bool {
        let Some(payload) = payload else {
            eprintln!("[tab-status] ERROR: missing payload");
            return false;
        };

        let status: StatusPayload = match serde_json::from_str(payload) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("[tab-status] ERROR: invalid JSON: {}", e);
                return false;
            }
        };

        let pane_id: u32 = match status.pane_id.parse() {
            Ok(id) => id,
            Err(_) => {
                eprintln!("[tab-status] ERROR: pane_id must be a number");
                return false;
            }
        };

        let Some(&(tab_position, ref current_name)) = self.pane_to_tab.get(&pane_id) else {
            eprintln!("[tab-status] ERROR: pane {} not found. Known panes: {:?}",
                pane_id, self.pane_to_tab.keys().collect::<Vec<_>>());
            return false;
        };

        let base_name = Self::extract_base_name(current_name);
        let tab_id = (tab_position + 1) as u32;

        match status.action.as_str() {
            "set_status" => {
                if status.emoji.is_empty() {
                    eprintln!("[tab-status] ERROR: emoji is required for 'set_status' action");
                    return false;
                }
                let new_name = format!("{} {}", status.emoji, base_name);
                eprintln!("[tab-status] set_status on tab {} (position {}): '{}' -> '{}'",
                    tab_id, tab_position, current_name, new_name);
                rename_tab(tab_id, new_name);
            }
            "clear_status" => {
                let new_name = base_name.to_string();
                eprintln!("[tab-status] clear_status on tab {} (position {}): '{}' -> '{}'",
                    tab_id, tab_position, current_name, new_name);
                rename_tab(tab_id, new_name);
            }
            "get_status" => {
                let emoji = Self::extract_status(current_name);
                eprintln!("[tab-status] get_status: '{}'", emoji);
                cli_pipe_output("tab-status", emoji);
                unblock_cli_pipe_input("tab-status");
            }
            "get_name" => {
                eprintln!("[tab-status] get_name: '{}'", base_name);
                cli_pipe_output("tab-status", base_name);
                unblock_cli_pipe_input("tab-status");
            }
            _ => {
                eprintln!("[tab-status] ERROR: unknown action '{}'. Use 'set_status', 'clear_status', 'get_status', or 'get_name'", status.action);
                return false;
            }
        };

        false
    }

    /// Extract base name from tab name.
    /// Status is the first character followed by a space.
    /// "🤖 Working" -> "Working"
    /// "Working" -> "Working"
    fn extract_base_name(name: &str) -> &str {
        let mut chars = name.chars();
        if let Some(_first_char) = chars.next() {
            let rest = chars.as_str();
            if rest.starts_with(' ') {
                // First char + space = status prefix, return the rest without leading space
                return &rest[1..];
            }
        }
        // No status prefix, return as is
        name
    }

    /// Extract status emoji from tab name.
    /// Status is the first character if followed by a space.
    /// "🤖 Working" -> "🤖"
    /// "Working" -> ""
    fn extract_status(name: &str) -> &str {
        let mut chars = name.chars();
        if let Some(first_char) = chars.next() {
            let rest = chars.as_str();
            if rest.starts_with(' ') {
                // First char + space = status prefix
                let char_len = first_char.len_utf8();
                return &name[..char_len];
            }
        }
        // No status prefix
        ""
    }

    fn rebuild_mapping(&mut self) {
        self.pane_to_tab.clear();

        for (display_index, tab) in self.tabs.iter().enumerate() {
            if let Some(pane_list) = self.panes.panes.get(&tab.position) {
                for pane in pane_list {
                    // Skip plugin panes
                    if pane.is_plugin {
                        continue;
                    }

                    self.pane_to_tab.insert(
                        pane.id,
                        (display_index, tab.name.clone())
                    );

                    eprintln!("[tab-rename] Mapped pane {} -> tab {} '{}'",
                        pane.id, display_index, tab.name);
                }
            }
        }

        eprintln!("[tab-rename] Total mappings: {}", self.pane_to_tab.len());
    }
}
