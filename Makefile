.PHONY: update update-marketplace update-plugin reinstall release release-patch release-minor release-major ensure-marketplace

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
