---
allowed-tools: Bash
description: Display list of Bugsnag errors with optional filtering
---

Execute the bugsnag skill to list errors from the project.

Use Bash tool to run the bugsnag.rb script with the `list` command and any provided arguments. The script is located in the dev-tools plugin at `skills/bugsnag/bugsnag.rb`.

Supported arguments: `--limit N`, `--status open|resolved|ignored`, `--severity error|warning`

Display the output directly to the user without any additional commentary.
