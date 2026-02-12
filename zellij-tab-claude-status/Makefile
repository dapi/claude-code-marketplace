.PHONY: install-deps install all clean

ZELLIJ_PLUGIN_REPO = https://github.com/dapi/zellij-tab-status.git
ZELLIJ_PLUGIN_DIR = /tmp/zellij-tab-status

# Install everything
all: install-deps install

# Install zellij-tab-status Zellij plugin (Rust/WASM dependency)
install-deps:
	@echo "Installing zellij-tab-status plugin..."
	@if [ -d "$(ZELLIJ_PLUGIN_DIR)" ]; then \
		cd $(ZELLIJ_PLUGIN_DIR) && git pull; \
	else \
		git clone $(ZELLIJ_PLUGIN_REPO) $(ZELLIJ_PLUGIN_DIR); \
	fi
	@cd $(ZELLIJ_PLUGIN_DIR) && make install
	@echo ""
	@echo "Done! Add to ~/.config/zellij/config.kdl:"
	@echo '  load_plugins {'
	@echo '      "file:~/.config/zellij/plugins/zellij-tab-status.wasm"'
	@echo '  }'
	@echo ""
	@echo "Then restart Zellij."

# Install Claude Code plugin
install:
	@echo "Installing Claude Code plugin..."
	claude /plugin install zellij-tab-claude-status@dapi

clean:
	rm -rf $(ZELLIJ_PLUGIN_DIR)
