.PHONY: update update-marketplace update-plugin deploy \
        install install-scripts install-plugins-all install-marketplace-all install-all install-dry-run \
        uninstall uninstall-scripts uninstall-plugins-all uninstall-marketplace-all uninstall-all uninstall-dry-run \
        reinstall reinstall-all reinstall-dry-run \
        release release-patch release-minor release-major ensure-marketplace list-claude-profiles update-all \
        install-zellij-tab-name

PLUGIN_JSON = github-workflow/.claude-plugin/plugin.json
MARKETPLACE_PATH = $(shell pwd)
MARKETPLACE_JSON = $(MARKETPLACE_PATH)/.claude-plugin/marketplace.json
PLUGIN ?= github-workflow

# List of all plugins in marketplace (extracted from marketplace.json)
ALL_PLUGINS = $(shell jq -r '.plugins[].name' $(MARKETPLACE_JSON) 2>/dev/null)

# Scripts installed to ~/.local/bin
SCRIPTS = do-issue zellij-rename-tab zellij-rename-tab-to-issue-number

# Get current version from plugin.json
CURRENT_VERSION = $(shell grep '"version"' $(PLUGIN_JSON) | sed 's/.*"version": "\([^"]*\)".*/\1/')

# Update marketplace and plugin
update: update-marketplace update-plugin
	@echo "✅ Marketplace and plugin updated. Restart Claude to apply changes."

# Update local marketplace
update-marketplace:
	claude plugin marketplace update dapi

# Update all installed plugins from dapi marketplace
update-plugin:
	@echo "🔄 Updating all plugins from dapi marketplace..."
	@plugins=$$(claude plugin list 2>/dev/null | grep "@dapi" | sed 's/.*❯ //'); \
	if [ -z "$$plugins" ]; then \
		echo "⚠️  No plugins from dapi marketplace installed"; \
		exit 0; \
	fi; \
	count=0; \
	for plugin in $$plugins; do \
		echo "→ Updating $$plugin..."; \
		claude plugin update "$$plugin" && count=$$((count + 1)); \
	done; \
	echo "✅ Updated $$count plugin(s)"

# Deploy any plugin: make deploy or make deploy PLUGIN=zellij-claude-status
deploy: ensure-marketplace
	claude plugin uninstall $(PLUGIN)@dapi || true
	claude plugin install $(PLUGIN)@dapi
	@echo "🚀 $(PLUGIN) deployed. Restart Claude to apply changes."

# ============================================================================
# INSTALL TARGETS
# ============================================================================

# Install single plugin (legacy, for current profile only)
install: ensure-marketplace
	claude plugin install github-workflow@dapi

# Install scripts to ~/.local/bin
install-scripts:
	@echo "📦 Installing scripts to ~/.local/bin/"
	@mkdir -p ~/.local/bin
	@for script in $(SCRIPTS); do \
		if [ -f "scripts/$$script" ]; then \
			cp "scripts/$$script" ~/.local/bin/; \
			chmod +x ~/.local/bin/$$script; \
			echo "   ✓ $$script"; \
		else \
			echo "   ⚠️  scripts/$$script not found"; \
		fi; \
	done
	@echo ""
	@if echo "$$PATH" | grep -q "$$HOME/.local/bin"; then \
		echo "✓ ~/.local/bin is in your PATH"; \
	else \
		echo "⚠️  Add to your shell profile:"; \
		echo "   export PATH=\"\$$HOME/.local/bin:\$$PATH\""; \
	fi

# Add marketplace to all Claude profiles
install-marketplace-all:
	@echo "📦 Adding marketplace 'dapi' to all Claude profiles..."
	@echo ""
	@added=0; \
	skipped=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace list 2>/dev/null | grep -q "dapi"; then \
			echo "📁 $$profile_name: ✓ already registered"; \
			skipped=$$((skipped + 1)); \
		else \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace add $(MARKETPLACE_PATH) 2>/dev/null; then \
				echo "📁 $$profile_name: ✅ added"; \
				added=$$((added + 1)); \
			else \
				echo "📁 $$profile_name: ⚠️  failed"; \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Added: $$added, Already registered: $$skipped"

# Install all plugins to all Claude profiles
install-plugins-all: install-marketplace-all
	@echo ""
	@echo "📦 Installing all plugins to all Claude profiles..."
	@echo "   Plugins: $(ALL_PLUGINS)"
	@echo ""
	@installed=0; \
	skipped=0; \
	failed=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📁 Profile: $$profile_name"; \
		for plugin in $(ALL_PLUGINS); do \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin list 2>/dev/null | grep -q "$$plugin@dapi"; then \
				echo "   ✓ $$plugin (already installed)"; \
				skipped=$$((skipped + 1)); \
			else \
				if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin install $$plugin@dapi 2>/dev/null; then \
					echo "   ✅ $$plugin"; \
					installed=$$((installed + 1)); \
				else \
					echo "   ⚠️  $$plugin (failed)"; \
					failed=$$((failed + 1)); \
				fi; \
			fi; \
		done; \
		echo ""; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Installed: $$installed, Skipped: $$skipped, Failed: $$failed"

# Full install: marketplace + all plugins + scripts (all profiles)
install-all: install-plugins-all install-scripts
	@echo ""
	@echo "🎉 Full installation complete. Restart Claude to apply changes."

# Dry-run: show what would be installed
install-dry-run:
	@echo "🔍 Install dry-run (no changes will be made)"
	@echo ""
	@echo "📦 Marketplace: dapi → $(MARKETPLACE_PATH)"
	@echo ""
	@echo "🔌 Plugins to install:"
	@for plugin in $(ALL_PLUGINS); do \
		echo "   • $$plugin@dapi"; \
	done
	@echo ""
	@echo "📜 Scripts to install in ~/.local/bin:"
	@for script in $(SCRIPTS); do \
		if [ -f "scripts/$$script" ]; then \
			echo "   • $$script"; \
		else \
			echo "   • $$script (⚠️  not found)"; \
		fi; \
	done
	@echo ""
	@echo "📁 Target profiles:"
	@for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		echo "   • $$dir"; \
	done
	@echo ""
	@echo "Run 'make install-all' to perform installation."

# ============================================================================
# UNINSTALL TARGETS
# ============================================================================

# Uninstall single plugin (legacy, for current profile only)
uninstall:
	claude plugin uninstall github-workflow@dapi || true

# Remove scripts from ~/.local/bin
uninstall-scripts:
	@echo "🗑️  Removing scripts from ~/.local/bin/"
	@removed=0; \
	for script in $(SCRIPTS); do \
		if [ -f ~/.local/bin/$$script ]; then \
			rm ~/.local/bin/$$script; \
			echo "   ✓ $$script removed"; \
			removed=$$((removed + 1)); \
		else \
			echo "   - $$script (not found)"; \
		fi; \
	done; \
	echo ""; \
	echo "✅ Removed: $$removed scripts"

# Remove all dapi plugins from all Claude profiles
uninstall-plugins-all:
	@echo "🗑️  Uninstalling all dapi plugins from all Claude profiles..."
	@echo "   Plugins: $(ALL_PLUGINS)"
	@echo ""
	@removed=0; \
	skipped=0; \
	failed=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📁 Profile: $$profile_name"; \
		for plugin in $(ALL_PLUGINS); do \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin list 2>/dev/null | grep -q "$$plugin@dapi"; then \
				if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin uninstall $$plugin@dapi 2>/dev/null; then \
					echo "   ✓ $$plugin removed"; \
					removed=$$((removed + 1)); \
				else \
					echo "   ⚠️  $$plugin (failed)"; \
					failed=$$((failed + 1)); \
				fi; \
			else \
				echo "   - $$plugin (not installed)"; \
				skipped=$$((skipped + 1)); \
			fi; \
		done; \
		echo ""; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Removed: $$removed, Skipped: $$skipped, Failed: $$failed"

# Remove marketplace from all Claude profiles
uninstall-marketplace-all:
	@echo "🗑️  Removing marketplace 'dapi' from all Claude profiles..."
	@echo ""
	@removed=0; \
	skipped=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace list 2>/dev/null | grep -q "dapi"; then \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace remove dapi 2>/dev/null; then \
				echo "📁 $$profile_name: ✓ removed"; \
				removed=$$((removed + 1)); \
			else \
				echo "📁 $$profile_name: ⚠️  failed"; \
			fi; \
		else \
			echo "📁 $$profile_name: - not registered"; \
			skipped=$$((skipped + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Removed: $$removed, Skipped: $$skipped"

# Full uninstall: plugins + marketplace + scripts (all profiles)
uninstall-all: uninstall-plugins-all uninstall-marketplace-all uninstall-scripts
	@echo ""
	@echo "🧹 Full uninstall complete."

# Dry-run: show what would be uninstalled
uninstall-dry-run:
	@echo "🔍 Uninstall dry-run (no changes will be made)"
	@echo ""
	@echo "🔌 Plugins to uninstall:"
	@for plugin in $(ALL_PLUGINS); do \
		echo "   • $$plugin@dapi"; \
	done
	@echo ""
	@echo "📦 Marketplace to remove: dapi"
	@echo ""
	@echo "📜 Scripts to remove from ~/.local/bin:"
	@for script in $(SCRIPTS); do \
		if [ -f ~/.local/bin/$$script ]; then \
			echo "   • $$script ✓"; \
		else \
			echo "   • $$script (not installed)"; \
		fi; \
	done
	@echo ""
	@echo "📁 Target profiles:"
	@for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		installed_count=0; \
		for plugin in $(ALL_PLUGINS); do \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin list 2>/dev/null | grep -q "$$plugin@dapi"; then \
				installed_count=$$((installed_count + 1)); \
			fi; \
		done; \
		has_marketplace="no"; \
		if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace list 2>/dev/null | grep -q "dapi"; then \
			has_marketplace="yes"; \
		fi; \
		echo "   • $$profile_name (plugins: $$installed_count, marketplace: $$has_marketplace)"; \
	done
	@echo ""
	@echo "Run 'make uninstall-all' to perform uninstallation."

# ============================================================================
# REINSTALL TARGETS
# ============================================================================

# Reinstall single plugin (legacy, for current profile only)
reinstall: uninstall install

# Full reinstall: uninstall-all + install-all
reinstall-all: uninstall-all install-all
	@echo ""
	@echo "🔄 Full reinstall complete. Restart Claude to apply changes."

# Dry-run: show reinstall plan
reinstall-dry-run:
	@echo "🔍 Reinstall dry-run (no changes will be made)"
	@echo ""
	@echo "Step 1: Uninstall all"
	@echo "─────────────────────"
	@$(MAKE) -s uninstall-dry-run | sed 's/^/  /'
	@echo ""
	@echo "Step 2: Install all"
	@echo "───────────────────"
	@$(MAKE) -s install-dry-run | sed 's/^/  /'
	@echo ""
	@echo "Run 'make reinstall-all' to perform reinstallation."

# ============================================================================
# HELPER TARGETS
# ============================================================================

# Ensure marketplace points to current directory (works from worktrees too)
ensure-marketplace:
	@claude plugin marketplace remove dapi 2>/dev/null || true
	@claude plugin marketplace add $(MARKETPLACE_PATH)

# Release targets
# Usage: make release (auto minor) or make release VERSION=1.3.0

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
	echo "📦 Releasing v$$NEW_VERSION..."; \
	sed -i '' 's/"version": "[^"]*"/"version": "'$$NEW_VERSION'"/' $(PLUGIN_JSON); \
	git add $(PLUGIN_JSON); \
	git commit -m "Bump version to $$NEW_VERSION"; \
	git tag v$$NEW_VERSION; \
	git push origin master --tags; \
	echo "✅ Released v$$NEW_VERSION"
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
	echo "📦 Releasing v$$NEW_VERSION (was $(CURRENT_VERSION))..."; \
	sed -i '' 's/"version": "[^"]*"/"version": "'$$NEW_VERSION'"/' $(PLUGIN_JSON); \
	git add $(PLUGIN_JSON); \
	git commit -m "Bump version to $$NEW_VERSION"; \
	git tag v$$NEW_VERSION; \
	git push origin master --tags; \
	echo "✅ Released v$$NEW_VERSION"
endif

# Show current version
version:
	@echo "Current version: $(CURRENT_VERSION)"

# List all Claude Code profiles
list-claude-profiles:
	@echo "🔍 Scanning for Claude Code profiles..."
	@echo ""
	@found=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		found=$$((found + 1)); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📁 Profile: $$dir"; \
		config_file=""; \
		if [ -f "$$dir/.claude.json" ]; then \
			config_file="$$dir/.claude.json"; \
		elif [ "$$dir" = "$(HOME)/.claude/" ] && [ -f "$(HOME)/.claude.json" ]; then \
			config_file="$(HOME)/.claude.json"; \
		fi; \
		if [ -n "$$config_file" ]; then \
			email=$$(grep -o '"emailAddress"[[:space:]]*:[[:space:]]*"[^"]*"' "$$config_file" | sed 's/.*"\([^"]*\)"$$/\1/'); \
			display=$$(grep -o '"displayName"[[:space:]]*:[[:space:]]*"[^"]*"' "$$config_file" | sed 's/.*"\([^"]*\)"$$/\1/'); \
			org=$$(grep -o '"organizationName"[[:space:]]*:[[:space:]]*"[^"]*"' "$$config_file" | sed 's/.*"\([^"]*\)"$$/\1/'); \
			[ -n "$$display" ] && echo "   👤 User: $$display"; \
			[ -n "$$email" ] && echo "   📧 Email: $$email"; \
			[ -n "$$org" ] && echo "   🏢 Organization: $$org"; \
		fi; \
		if [ -f "$$dir/.credentials.json" ]; then \
			sub=$$(grep -o '"subscriptionType"[[:space:]]*:[[:space:]]*"[^"]*"' "$$dir/.credentials.json" | sed 's/.*"\([^"]*\)"$$/\1/'); \
			tier=$$(grep -o '"rateLimitTier"[[:space:]]*:[[:space:]]*"[^"]*"' "$$dir/.credentials.json" | sed 's/.*"\([^"]*\)"$$/\1/'); \
			expires=$$(grep -o '"expiresAt"[[:space:]]*:[[:space:]]*[0-9]*' "$$dir/.credentials.json" | sed 's/.*:[[:space:]]*//'); \
			[ -n "$$sub" ] && echo "   💳 Subscription: $$sub"; \
			[ -n "$$tier" ] && echo "   ⚡ Rate Limit: $$tier"; \
			if [ -n "$$expires" ]; then \
				exp_date=$$(date -d @$$((expires / 1000)) '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown"); \
				echo "   ⏰ Token Expires: $$exp_date"; \
			fi; \
		fi; \
		stable_id_file=$$(ls "$$dir/statsig/statsig.stable_id."* 2>/dev/null | head -1); \
		if [ -n "$$stable_id_file" ] && [ -f "$$stable_id_file" ]; then \
			uuid=$$(cat "$$stable_id_file" | tr -d '"'); \
			echo "   🆔 UUID: $$uuid"; \
		fi; \
		if [ -n "$$config_file" ]; then \
			startups=$$(grep -o '"numStartups"[[:space:]]*:[[:space:]]*[0-9]*' "$$config_file" | sed 's/.*:[[:space:]]*//'); \
			[ -n "$$startups" ] && echo "   🚀 Startups: $$startups"; \
		fi; \
		if [ -d "$$dir/plugins" ]; then \
			plugin_count=$$(ls -1 "$$dir/plugins" 2>/dev/null | wc -l); \
			echo "   🔌 Plugins: $$plugin_count installed"; \
		else \
			echo "   🔌 Plugins: none (dir not created)"; \
		fi; \
		echo ""; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Found $$found Claude Code profile(s)"

# Update all plugins in all Claude profiles
update-all:
	@echo "🔄 Updating all dapi plugins in all Claude profiles..."
	@echo ""
	@total_updated=0; \
	total_failed=0; \
	profiles=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/settings.json" ] || [ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📁 Profile: $$profile_name"; \
		plugins=$$(CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin list 2>/dev/null | grep "@dapi" | sed 's/.*❯ //'); \
		if [ -z "$$plugins" ]; then \
			echo "   ⚠️  No dapi plugins installed"; \
			continue; \
		fi; \
		profiles=$$((profiles + 1)); \
		echo "   → Updating marketplace..."; \
		CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace update dapi 2>/dev/null || true; \
		for plugin in $$plugins; do \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin update "$$plugin" 2>/dev/null; then \
				echo "   ✅ $$plugin"; \
				total_updated=$$((total_updated + 1)); \
			else \
				echo "   ⚠️  $$plugin (failed)"; \
				total_failed=$$((total_failed + 1)); \
			fi; \
		done; \
		echo ""; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Profiles: $$profiles, Updated: $$total_updated, Failed: $$total_failed"

# ============================================================================
# ZELLIJ PLUGIN TARGETS
# ============================================================================

ZELLIJ_TAB_NAME_VERSION = v0.4.1
ZELLIJ_TAB_NAME_URL = https://github.com/Cynary/zellij-tab-name/releases/download/$(ZELLIJ_TAB_NAME_VERSION)/zellij-tab-name.wasm
ZELLIJ_PLUGINS_DIR = $(HOME)/.config/zellij/plugins

# Install zellij-tab-name plugin for cross-tab renaming
install-zellij-tab-name:
	@echo "📦 Installing zellij-tab-name plugin..."
	@mkdir -p $(ZELLIJ_PLUGINS_DIR)
	@if [ -f "$(ZELLIJ_PLUGINS_DIR)/zellij-tab-name.wasm" ]; then \
		echo "   ✓ Already installed at $(ZELLIJ_PLUGINS_DIR)/zellij-tab-name.wasm"; \
	else \
		echo "   → Downloading $(ZELLIJ_TAB_NAME_VERSION)..."; \
		curl -sL "$(ZELLIJ_TAB_NAME_URL)" -o "$(ZELLIJ_PLUGINS_DIR)/zellij-tab-name.wasm"; \
		echo "   ✅ Downloaded to $(ZELLIJ_PLUGINS_DIR)/zellij-tab-name.wasm"; \
	fi
	@echo ""
	@echo "📝 Add to your zellij config (~/.config/zellij/config.kdl):"
	@echo ""
	@echo '   load_plugins {'
	@echo '       "file:$(ZELLIJ_PLUGINS_DIR)/zellij-tab-name.wasm"'
	@echo '   }'
	@echo ""
	@echo "   Then restart zellij."
