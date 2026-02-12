use serde::Deserialize;
use std::collections::BTreeMap;
use zellij_tile::prelude::*;

#[derive(Debug, Deserialize)]
struct RenamePayload {
    pane_id: String,
    name: String,
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

        if pipe_message.name != "tab-rename" {
            return false;
        }

        let Some(payload) = pipe_message.payload else {
            eprintln!("[tab-rename] ERROR: missing payload");
            return false;
        };

        let rename: RenamePayload = match serde_json::from_str(&payload) {
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

    fn render(&mut self, _rows: usize, _cols: usize) {}
}

impl State {
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
