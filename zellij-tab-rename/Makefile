.PHONY: build install clean

PLUGIN_NAME = zellij-tab-rename
TARGET = target/wasm32-wasip1/release/zellij-tab-rename.wasm
INSTALL_DIR = $(HOME)/.config/zellij/plugins

build:
	cargo build --release --target wasm32-wasip1

install: build
	mkdir -p $(INSTALL_DIR)
	cp $(TARGET) $(INSTALL_DIR)/$(PLUGIN_NAME).wasm
	@echo "Installed to $(INSTALL_DIR)/$(PLUGIN_NAME).wasm"
	@echo ""
	@echo "Add to ~/.config/zellij/config.kdl:"
	@echo '  load_plugins {'
	@echo '      "file:$(INSTALL_DIR)/$(PLUGIN_NAME).wasm"'
	@echo '  }'

clean:
	cargo clean

# Test rename (run after installing and restarting zellij)
test:
	zellij pipe --name tab-rename -- '{"pane_id": "$(ZELLIJ_PANE_ID)", "name": "Test-Rename"}'
	sleep 0.5
	zellij action query-tab-names
