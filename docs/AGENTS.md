# AGENTS.md - Repository Guidelines

## Build/Lint/Test Commands

This repository contains system administration scripts and documentation. No build process exists.

**Shell Script Validation:**
```bash
bash -n script.sh  # Syntax check shell scripts
shellcheck script.sh  # Lint shell scripts (if shellcheck is installed)
```

**Single Test Execution:**
```bash
# Test individual functions by sourcing and calling directly
source script.sh && function_name arg1 arg2
```

## Code Style Guidelines

### Shell Scripts
- Use `#!/bin/bash` shebang with header comments explaining purpose
- Set `set -e` and `set -o pipefail` for error handling
- Use UPPER_CASE for constants, lower_case for locals
- Implement color-coded logging: log_success(), log_error(), log_warning(), log_info()
- Quote all variables: `"$variable"` not `$variable`
- Use `[[ ]]` for string tests, `(( ))` for arithmetic
- Include error_exit() functions with cleanup and logging
- Add timestamps to all log messages

### Markdown Documentation
- Use ATX headers: `# Header` not `Header\n===`
- Include creation dates and version info in document footers
- Use code blocks with language specifiers: ```bash
- Add table of contents for documents >5 sections

### Naming Conventions
- Scripts: lowercase with underscores (e.g., `update_checkmk_agents.sh`)
- Functions: lower_case with underscores (e.g., `log_success()`)
- Files: descriptive names matching content purpose

### Error Handling & Security
- Exit on errors with `set -e`, use custom error functions
- Avoid hardcoded passwords, use SSH key authentication
- Validate user input, clean up temporary files
- Log errors with timestamps and context

### Agent-Specific Rules
- **Checkmk Agent**: Use .claude/agents/Checkmk.md for Checkmk questions
- **Ansible Agent**: Use .claude/agents/ansible.md for Ansible automation
- **Network Engineer Agent**: Use .claude/agents/network_engineer.md for network, DNS, BIND, Pi-hole questions
- Always cite official documentation URLs in responses