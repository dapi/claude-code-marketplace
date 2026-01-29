.PHONY: update update-marketplace update-plugin reinstall release release-patch release-minor release-major ensure-marketplace list-claude-profiles install-all update-all

PLUGIN_JSON = dev-tools/.claude-plugin/plugin.json
MARKETPLACE_PATH = $(shell pwd)

# Get current version from plugin.json
CURRENT_VERSION = $(shell grep '"version"' $(PLUGIN_JSON) | sed 's/.*"version": "\([^"]*\)".*/\1/')

# Update marketplace and plugin
update: update-marketplace update-plugin
	@echo "✅ Marketplace and plugin updated. Restart Claude to apply changes."

# Update local marketplace
update-marketplace:
	claude plugin marketplace update dapi

# Update dev-tools plugin
update-plugin:
	claude plugin update dev-tools@dapi

# Full reinstall (uninstall + install)
reinstall: uninstall install

uninstall:
	claude plugin uninstall dev-tools@dapi || true

# Ensure marketplace is registered
ensure-marketplace:
	@claude plugin marketplace list 2>/dev/null | grep -q "dapi" || \
		(echo "📦 Adding marketplace 'dapi'..." && claude plugin marketplace add $(MARKETPLACE_PATH))

install: ensure-marketplace
	claude plugin install dev-tools@dapi

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
	sed -i 's/"version": "[^"]*"/"version": "'$$NEW_VERSION'"/' $(PLUGIN_JSON); \
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
	sed -i 's/"version": "[^"]*"/"version": "'$$NEW_VERSION'"/' $(PLUGIN_JSON); \
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
		[ -f "$$dir/.credentials.json" ] || continue; \
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

# Install plugin to all Claude profiles
install-all:
	@echo "📦 Installing dev-tools@dapi to all Claude profiles..."
	@echo ""
	@installed=0; \
	skipped=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📁 Profile: $$profile_name"; \
		if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace list 2>/dev/null | grep -q "dapi"; then \
			echo "   ✓ Marketplace 'dapi' already registered"; \
		else \
			echo "   → Adding marketplace 'dapi'..."; \
			CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace add $(MARKETPLACE_PATH) || { echo "   ⚠️  Failed to add marketplace"; continue; }; \
		fi; \
		if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin list 2>/dev/null | grep -q "dev-tools@dapi"; then \
			echo "   ✓ Plugin already installed"; \
			skipped=$$((skipped + 1)); \
		else \
			echo "   → Installing dev-tools@dapi..."; \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin install dev-tools@dapi; then \
				echo "   ✅ Installed successfully"; \
				installed=$$((installed + 1)); \
			else \
				echo "   ⚠️  Installation failed"; \
			fi; \
		fi; \
		echo ""; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Installed: $$installed, Already installed: $$skipped"

# Update plugin in all Claude profiles
update-all:
	@echo "🔄 Updating dev-tools@dapi in all Claude profiles..."
	@echo ""
	@updated=0; \
	skipped=0; \
	failed=0; \
	for dir in ~/.claude*/; do \
		[ -f "$$dir/.credentials.json" ] || continue; \
		profile_name=$$(basename "$$dir"); \
		abs_dir=$$(cd "$$dir" && pwd); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📁 Profile: $$profile_name"; \
		if ! CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin list 2>/dev/null | grep -q "dev-tools@dapi"; then \
			echo "   ⚠️  Plugin not installed, skipping"; \
			skipped=$$((skipped + 1)); \
		else \
			echo "   → Updating marketplace 'dapi'..."; \
			CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin marketplace update dapi 2>/dev/null || true; \
			echo "   → Updating dev-tools@dapi..."; \
			if CLAUDE_CONFIG_DIR="$$abs_dir" claude plugin update dev-tools@dapi; then \
				echo "   ✅ Updated successfully"; \
				updated=$$((updated + 1)); \
			else \
				echo "   ⚠️  Update failed"; \
				failed=$$((failed + 1)); \
			fi; \
		fi; \
		echo ""; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "✅ Updated: $$updated, Skipped: $$skipped, Failed: $$failed"
