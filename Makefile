.PHONY: update update-marketplace update-plugin reinstall

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
reinstall:
	claude plugin uninstall dev-tools@dapi || true
	claude plugin install dev-tools@dapi
	@echo "✅ Plugin reinstalled. Restart Claude to apply changes."
