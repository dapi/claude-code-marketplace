---
allowed-tools: Bash
description: Display only open (unresolved) Bugsnag errors
---

Execute the bugsnag skill to show only open (unresolved) errors.

Use Bash tool to run the bugsnag.rb script with the `open` command and any provided arguments. The script is located in the dev-tools plugin at `skills/bugsnag/bugsnag.rb`.

Supported arguments: `--limit N`, `--severity error|warning`

Display the output directly to the user without any additional commentary.
