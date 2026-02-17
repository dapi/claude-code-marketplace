.PHONY: reinstall reinstall-all \
        install-plugin uninstall-plugin reinstall-plugin \
        install-scripts uninstall-scripts \
        release release-patch release-minor release-major version \
        install-zellij-tab-status \
        list-claude-profiles \
        lint lint-emoji lint-emoji-fix

# ============================================================================
# CONFIGURATION
# ============================================================================

# Plugins to install (override: make PLUGINS="a b c")
PLUGINS = github-workflow zellij-workflow bugsnag-skill spec-reviewer \
          cluster-efficiency doc-validate media-upload long-running-harness \
          himalaya requirements task-router skill-finder

PLUGIN_JSON = github-workflow/.claude-plugin/plugin.json
MARKETPLACE_PATH = $(shell pwd)
PLUGIN ?= github-workflow

# Allow running claude CLI from within a Claude Code session
CLAUDE = env -u CLAUDECODE claude

# Scripts installed to ~/.local/bin
SCRIPTS = start-issue zellij-rename-tab-to-issue-number

# Get current version from plugin.json
CURRENT_VERSION = $(shell grep '"version"' $(PLUGIN_JSON) | sed 's/.*"version": "\([^"]*\)".*/\1/')

# ============================================================================
# DEFAULT TARGET: reinstall all plugins (idempotent)
# ============================================================================

all: reinstall-all install-scripts

# Default: clean reinstall of all PLUGINS for current profile
# Works identically on clean Claude and on Claude with existing marketplace
reinstall:
	@echo "Reinstalling dapi marketplace plugins..."
	@echo "   Plugins: $(PLUGINS)"
	@echo ""
	@for plugin in $(PLUGINS); do \
		echo "-> Uninstalling $$plugin@dapi..."; \
		$(CLAUDE) plugin uninstall $$plugin@dapi 2>/dev/null || echo "   (not installed, skipping)"; \
	done
	@echo ""
	@echo "-> Resetting marketplace..."
	@$(CLAUDE) plugin marketplace remove dapi 2>/dev/null || true
	@$(CLAUDE) plugin marketplace add $(MARKETPLACE_PATH)
	@echo ""
	@failed=""; \
	for plugin in $(PLUGINS); do \
		echo "-> Installing $$plugin@dapi..."; \
		if ! $(CLAUDE) plugin install $$plugin@dapi; then \
			failed="$$failed $$plugin"; \
		fi; \
	done; \
	echo ""; \
	if [ -n "$$failed" ]; then \
		echo "[FAIL] Failed to install:$$failed"; \
		exit 1; \
	else \
		echo "[OK] Reinstalled $(words $(PLUGINS)) plugin(s). Restart Claude to apply."; \
	fi

# Same as reinstall, but for ALL Claude profiles
reinstall-all:
	@echo "Reinstalling dapi marketplace plugins for ALL profiles..."
	@echo "   Plugins: $(PLUGINS)"
	@echo ""
	@for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		echo "--- Profile: $$profile_name ---"; \
		for plugin in $(PLUGINS); do \
			echo "-> Uninstalling $$plugin@dapi..."; \
			CLAUDE_CONFIG_DIR="$$abs_dir" $(CLAUDE) plugin uninstall $$plugin@dapi 2>/dev/null || echo "   (not installed, skipping)"; \
		done; \
		echo "-> Resetting marketplace..."; \
		CLAUDE_CONFIG_DIR="$$abs_dir" $(CLAUDE) plugin marketplace remove dapi 2>/dev/null || true; \
		CLAUDE_CONFIG_DIR="$$abs_dir" $(CLAUDE) plugin marketplace add $(MARKETPLACE_PATH); \
		for plugin in $(PLUGINS); do \
			echo "-> Installing $$plugin@dapi..."; \
			CLAUDE_CONFIG_DIR="$$abs_dir" $(CLAUDE) plugin install $$plugin@dapi || true; \
		done; \
		echo ""; \
	done; \
	echo "[OK] Done. Restart Claude to apply."

# ============================================================================
# SINGLE PLUGIN TARGETS
# ============================================================================

# Install single plugin: make install-plugin PLUGIN=zellij-workflow
install-plugin:
	@$(CLAUDE) plugin marketplace remove dapi 2>/dev/null || true
	@$(CLAUDE) plugin marketplace add $(MARKETPLACE_PATH)
	$(CLAUDE) plugin install $(PLUGIN)@dapi

# Uninstall single plugin: make uninstall-plugin PLUGIN=zellij-workflow
uninstall-plugin:
	$(CLAUDE) plugin uninstall $(PLUGIN)@dapi || true

# Reinstall single plugin: make reinstall-plugin PLUGIN=zellij-workflow
reinstall-plugin:
	@$(CLAUDE) plugin uninstall $(PLUGIN)@dapi 2>/dev/null || true
	@$(CLAUDE) plugin marketplace remove dapi 2>/dev/null || true
	@$(CLAUDE) plugin marketplace add $(MARKETPLACE_PATH)
	$(CLAUDE) plugin install $(PLUGIN)@dapi

# ============================================================================
# SCRIPTS
# ============================================================================

# Install scripts to ~/.local/bin
install-scripts:
	@echo "Installing scripts to ~/.local/bin/"
	@mkdir -p ~/.local/bin
	@for script in $(SCRIPTS); do \
		if [ -f "scripts/$$script" ]; then \
			cp "scripts/$$script" ~/.local/bin/; \
			chmod +x ~/.local/bin/$$script; \
			echo "   + $$script"; \
		else \
			echo "   ! scripts/$$script not found"; \
		fi; \
	done

# Remove scripts from ~/.local/bin
uninstall-scripts:
	@echo "Removing scripts from ~/.local/bin/"
	@for script in $(SCRIPTS); do \
		if [ -f ~/.local/bin/$$script ]; then \
			rm ~/.local/bin/$$script; \
			echo "   - $$script"; \
		fi; \
	done

# ============================================================================
# RELEASE TARGETS
# ============================================================================

release: release-minor

release-patch:
	@$(MAKE) _release INCREMENT=patch

release-minor:
	@$(MAKE) _release INCREMENT=minor

release-major:
	@$(MAKE) _release INCREMENT=major

_release:
ifdef VERSION
	@NEW_VERSION=$(VERSION); \
	echo "Releasing v$$NEW_VERSION..."; \
	sed -i 's/"version": "[^"]*"/"version": "'$$NEW_VERSION'"/' $(PLUGIN_JSON); \
	git add $(PLUGIN_JSON); \
	git commit -m "Bump version to $$NEW_VERSION"; \
	git tag v$$NEW_VERSION; \
	git push origin master --tags; \
	echo "[OK] Released v$$NEW_VERSION"
else
	@MAJOR=$$(echo $(CURRENT_VERSION) | cut -d. -f1); \
	MINOR=$$(echo $(CURRENT_VERSION) | cut -d. -f2); \
	PATCH=$$(echo $(CURRENT_VERSION) | cut -d. -f3); \
	if [ "$(INCREMENT)" = "major" ]; then \
		NEW_VERSION=$$((MAJOR + 1)).0.0; \
	elif [ "$(INCREMENT)" = "minor" ]; then \
		NEW_VERSION=$$MAJOR.$$((MINOR + 1)).0; \
	else \
		NEW_VERSION=$$MAJOR.$$MINOR.$$((PATCH + 1)); \
	fi; \
	echo "Releasing v$$NEW_VERSION (was $(CURRENT_VERSION))..."; \
	sed -i 's/"version": "[^"]*"/"version": "'$$NEW_VERSION'"/' $(PLUGIN_JSON); \
	git add $(PLUGIN_JSON); \
	git commit -m "Bump version to $$NEW_VERSION"; \
	git tag v$$NEW_VERSION; \
	git push origin master --tags; \
	echo "[OK] Released v$$NEW_VERSION"
endif

version:
	@echo "Current version: $(CURRENT_VERSION)"

# ============================================================================
# ZELLIJ PLUGIN TARGETS
# ============================================================================

ZELLIJ_PLUGINS_DIR = $(HOME)/.config/zellij/plugins
SCRIPTS_DIR = $(HOME)/.local/bin

ZELLIJ_TAB_STATUS_VERSION = v0.3.5
ZELLIJ_TAB_STATUS_WASM_URL = https://github.com/dapi/zellij-tab-status/releases/download/$(ZELLIJ_TAB_STATUS_VERSION)/zellij-tab-status.wasm
ZELLIJ_TAB_STATUS_RAW_URL = https://raw.githubusercontent.com/dapi/zellij-tab-status/$(ZELLIJ_TAB_STATUS_VERSION)/scripts
ZELLIJ_TAB_STATUS_SCRIPTS = zellij-tab-status

install-zellij-tab-status:
	@echo "Installing zellij-tab-status $(ZELLIJ_TAB_STATUS_VERSION)..."
	@mkdir -p $(ZELLIJ_PLUGINS_DIR)
	@mkdir -p $(SCRIPTS_DIR)
	@echo "   -> Downloading WASM plugin..."
	@curl -sL "$(ZELLIJ_TAB_STATUS_WASM_URL)" -o "$(ZELLIJ_PLUGINS_DIR)/zellij-tab-status.wasm"
	@echo "   -> Downloading scripts..."
	@for script in $(ZELLIJ_TAB_STATUS_SCRIPTS); do \
		curl -sL "$(ZELLIJ_TAB_STATUS_RAW_URL)/$$script" -o "$(SCRIPTS_DIR)/$$script"; \
		chmod +x "$(SCRIPTS_DIR)/$$script"; \
	done
	@echo ""
	@echo "Installed:"
	@echo "   Plugin: $(ZELLIJ_PLUGINS_DIR)/zellij-tab-status.wasm"
	@echo "   Script: $(SCRIPTS_DIR)/zellij-tab-status"

# ============================================================================
# UTILITY TARGETS
# ============================================================================

list-claude-profiles:
	@echo "Scanning for Claude Code profiles..."
	@for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		plugins=$$(CLAUDE_CONFIG_DIR="$$abs_dir" $(CLAUDE) plugin list 2>/dev/null | grep "@dapi" | sed 's/.*❯ //' | tr '\n' ' '); \
		echo "   $$profile_name: $$plugins"; \
	done

# ============================================================================
# LINT TARGETS
# ============================================================================

lint: lint-emoji

lint-emoji:
	@./scripts/lint_no_emoji.sh

lint-emoji-fix:
	@./scripts/lint_no_emoji.sh --fix
