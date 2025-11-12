# Style Guidelines and Standards

This document defines coding standards, documentation style, and security practices for the repository.

## Shell Scripts

### Naming and Structure

- **Shebang**: `#!/bin/bash`
- **Variables**: `UPPER_CASE` for constants and configuration, `lower_case` for local variables
- **Functions**: `lower_case_with_underscores()` - declare functions before main logic
- **Quote all variables**: `"$variable"` - prevents word splitting and glob expansion bugs
- **Use `[[ ]]` for all string comparisons** (not `[ ]` or `test`)
- **Use `(( ))` for all arithmetic operations**

### Safety Practices

- Enable error handling at the top: `set -e` (exit on error) and `set -o pipefail` (exit on pipe failure)
- Define an `error_exit()` function that logs and cleans up before exiting
- For optional operations that might fail, use `|| { error_handler }` to catch failures
- Never use interactive commands in loops - causes scripts to hang
- Always quote loop variables: `for host in "${HOSTS[@]}"` not `for host in $HOSTS`
- Use explicit exit codes: `exit 0` for success, `exit 1` for errors

### Common Patterns

```bash
#!/bin/bash
set -e
set -o pipefail

# Configuration (top of file)
VERSION="2.4.0p2"
BACKUP_DIR="/tmp/backups"

# Logging functions
log_success() { echo "✓ $1"; }

# Main execution
main() {
    # Pre-flight checks
    check_root
    validate_config

    # Operation with error handling
    backup_data || error_exit "Backup failed"
    apply_changes || { restore_backup; error_exit "Changes failed"; }
}

main "$@"
```

### Error Handling Pattern

```bash
# For operations that might fail:
command_that_might_fail || {
    error_exit "Failed to do X: check log at /path/to/log"
}

# For cleanup operations:
cleanup() {
    # Remove temporary files
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT
```

### Logging Pattern

Use consistent logging functions throughout scripts:

```bash
log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

error_exit() {
    log_error "$1"
    exit 1
}
```

## Markdown

### Formatting

- **Headers**: Use ATX-style headers: `# H1`, `## H2`, `### H3` (not underline style)
- **Table of contents**: Include for documentation with >5 sections
- **Code blocks**: Use language specifiers: ` ```bash `, ` ```yaml `, ` ```dns `
- **Tables**: Use for structured data (host lists, status tracking, configuration comparisons)
- **Bold**: For important terms, file names, and technical concepts
- **Links**: Should be specific (e.g., docs URL + topic, not just homepage)

### Content Standards

- Keep docs in sync with actual infrastructure state - stale docs cause operational errors
- Include metadata: creation date, last updated, software versions
- Step-by-step procedures should be numbered and tested before documentation
- Organize troubleshooting sections by symptom → diagnosis → solution
- Examples should be realistic and tested (not theoretical)

### Documentation Structure

For operational procedures:
1. **Scenario** - What problem are we solving?
2. **Checklist** - Pre-flight checks before proceeding
3. **Procedure** - Numbered steps with code blocks
4. **Validation** - How to verify success
5. **Rollback** - How to undo if needed (for destructive operations)

### Example Procedure Template

```markdown
## Task: [Brief Title]

**Scenario**: [What problem is this solving?]

**Checklist:**
- [ ] Prerequisite 1
- [ ] Prerequisite 2

**Procedure:**

**1. First step**
\`\`\`bash
command-here
\`\`\`

**2. Second step**
\`\`\`bash
another-command
\`\`\`

**Validation:**
\`\`\`bash
# How to verify it worked
verification-command
\`\`\`
```

## Security Practices

### Access Control

- **No hardcoded passwords** in scripts or documentation
- **SSH key authentication required** (password-based auth disabled)
- **Validate user input** before processing (especially `read` prompts - check for empty/invalid values)
- **Document SSH access requirements** or key setup needed

### Safe Operations

- Clean up temporary files after execution, especially in error handlers
- Use `sudo` only when necessary, with specific user context: `sudo su - monitoring -c 'command'`
- Set restrictive permissions on sensitive files: `chmod 700` for private directories, `chmod 600` for files
- Log operations for audit trail - include timestamps and context in all log messages
- Never log sensitive data (passwords, API tokens, private keys)

### Examples of Safe Pattern

```bash
# Good: Specific sudo context
sudo su - monitoring -c 'cmk -d hostname'

# Good: Restrictive permissions
chmod 700 /sensitive/directory
chmod 600 /sensitive/file

# Good: Input validation
read -p "Continue? (y/N): " response
[[ "$response" == "y" ]] || error_exit "User cancelled"

# Bad: Bare password
sudo -u root password='secret' command

# Bad: Insecure permissions
chmod 777 /sensitive/directory
```

## Commit Message Guidelines

Follow conventional commit style for consistency:

**Format:**
```
TYPE: Brief description

Longer explanation if needed (max 72 chars per line)

- Bullet point 1
- Bullet point 2
```

**Types:**
- `FEAT`: New feature or functionality
- `FIX`: Bug fix
- `DOCS`: Documentation changes only
- `REFACTOR`: Code restructuring without feature change
- `PERF`: Performance improvement
- `TEST`: Test additions or updates
- `CHORE`: Maintenance tasks, dependency updates
- `INFRA`: Infrastructure/deployment changes

**Examples:**
```
FEAT: Add DNS check for Pi-hole primary

Implements automatic validation of Pi-hole DNS resolution
on startup for infrastructure health monitoring.

- Checks Pi-hole primary (10.10.10.22)
- Checks Pi-hole secondary (10.10.10.23)
- Logs failures with retry instructions
```

```
FIX: Correct serial number format in BIND9 documentation

Fixed examples showing serial number format. YYYYMMDDNN format
was not clearly indicated in zone update procedures.
```

## Configuration Management

### Variable Naming

In scripts, group configuration at the top:

```bash
# === VERSION CONFIGURATION ===
CHECKMK_VERSION_SHORT="2.4.0p2"
CHECKMK_VERSION="2.4.0p2.cre"
DOWNLOAD_URL="https://download.checkmk.com/checkmk/${CHECKMK_VERSION_SHORT}/..."

# === INFRASTRUCTURE IPs ===
CHECKMK_SERVER="10.10.10.5"
BIND_PRIMARY="10.10.10.4"
BIND_SECONDARY="10.10.10.2"

# === PATH CONFIGURATION ===
BACKUP_DIR="/tmp/checkmk_upgrade_backups"
LOG_FILE="/tmp/checkmk_upgrade_${DATE}.log"

# === OPERATIONAL CONFIGURATION ===
RETRY_COUNT=3
RETRY_DELAY=5
```

**Rules:**
- All uppercase for configuration constants
- Group related variables together with comments
- Include units where relevant (timeouts in seconds, paths as absolute)
- Update comments when changing values
- Version numbers should match actual deployed versions

## Documentation Synchronization

Keep these in sync with actual state:
- Infrastructure IP addresses and hostnames
- Software versions (Checkmk, Pi-hole, BIND9, etc.)
- Configuration file paths
- Port numbers and protocol information
- Command syntax and flags

**Sync Points:**
- After upgrading any software component
- After changing IP addressing or DNS
- After adding new hosts or services
- After modifying configuration files
- When operational procedures change

## Testing Standards

### Pre-Deployment Testing

For scripts:
1. **Syntax validation**: `bash -n script.sh`
2. **Shellcheck**: `shellcheck script.sh` (optional but recommended)
3. **Read-only operations**: Test connectivity, version detection
4. **Non-critical host**: Always test on non-production host first
5. **Rollback plan**: Document how to undo if it fails

For documentation:
1. **Link verification**: Check external documentation links resolve
2. **Command testing**: Verify all referenced commands work
3. **IP/hostname validation**: Confirm against current infrastructure
4. **Version matching**: Verify version numbers match deployed software
5. **Step sequencing**: Ensure procedures follow correct order

## Code Review Checklist

Before merging any changes:

### Scripts
- [ ] Syntax is valid (`bash -n`)
- [ ] Variables are properly quoted
- [ ] Error handling is complete
- [ ] Logging is consistent
- [ ] Configuration is at top of file
- [ ] Tested on non-critical host
- [ ] Commit message is clear

### Documentation
- [ ] Information is current and accurate
- [ ] Commands are tested and working
- [ ] IPs and hostnames match infrastructure
- [ ] External links are valid
- [ ] Formatting is consistent
- [ ] Steps are clear and numbered

### Agents
- [ ] YAML metadata is valid
- [ ] Documentation sources are cited
- [ ] Activation trigger is clear
- [ ] Examples are realistic
- [ ] No hardcoded secrets
