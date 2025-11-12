# Development Guide

This document covers adding new scripts, modifying existing scripts, and general development tasks.

## Common Development Tasks

### Adding a New Bash Script

When creating a new operational script (beyond the two existing ones):

1. **Start with the template structure:**
   - Shebang: `#!/bin/bash`
   - Error handling: `set -e` and `set -o pipefail` at top
   - Color definitions for logging (copy from existing scripts)
   - Configuration block with `UPPER_CASE` variables

2. **Implement standard functions:**
   ```bash
   log_success "Message"    # Green - operation succeeded
   log_error "Message"      # Red - operation failed
   log_warning "Message"    # Yellow - warning/caution
   log_info "Message"       # Blue - informational
   error_exit "Message"     # Log error and exit with code 1
   ```

3. **For destructive operations:**
   - Create backups before modifications
   - Use `read -p "Continue? (y/N): "` for confirmation
   - Log the backup location clearly
   - Provide manual rollback instructions if needed

4. **Before committing:**
   - Run `bash -n script.sh` to validate syntax
   - Test on non-critical hosts first
   - Document any new configuration variables at the top
   - Verify all logging calls use standard functions

### Modifying Existing Scripts

Follow these rules to maintain code consistency:

1. **Never remove the logging system** - All user-facing output goes through `log_*()` functions
2. **Preserve error handling** - Keep `set -e`, `set -o pipefail`, and error handlers intact
3. **Update configuration block** - If changing versions, IPs, or paths, update the variables at the top
4. **Test syntax immediately** - Run `bash -n script.sh` after any change
5. **Document changes in comments** - Add context for why modifications were made

**Example workflow for a version update:**
```bash
# 1. Edit the VERSION variable at the top of script
CHECKMK_VERSION_SHORT="2.4.0p2"  # Updated from p1
CHECKMK_VERSION="2.4.0p2.cre"

# 2. Update download URL if needed
DOWNLOAD_URL="https://download.checkmk.com/checkmk/${CHECKMK_VERSION_SHORT}/..."

# 3. Validate syntax
bash -n script.sh

# 4. Test on non-critical host
sudo ./script.sh

# 5. Document what changed and why
```

### Script Modification Checklist

1. **Preserve error handling structure:**
   - Keep `set -e` and `set -o pipefail` at the top
   - Maintain `error_exit()` function and error handlers
   - All subprocess calls should have `|| { error handler }`

2. **Update logging consistently:**
   - Use existing logging functions: `log_success()`, `log_error()`, `log_warning()`, `log_info()`
   - All user-facing messages go through logging functions (not bare `echo`)
   - Include context in log messages (hostname, version, file path, etc.)

3. **Maintain configuration block:**
   - All dynamic values (IPs, versions, paths) at top of script in `UPPER_CASE`
   - Version strings should match actual target versions
   - Update comments when configuration changes

4. **Preserve backup strategy:**
   - Critical file changes must create timestamped backups before modification
   - Backup path should be documented in logs
   - Include backup file content verification in pre-flight checks

5. **Before committing changes:**
   - Run syntax check: `bash -n script.sh`
   - Review all variable assignments for proper quoting
   - Verify backup/restore logic works as intended
   - Test on non-critical host first

### Script Testing Guidelines

**Safe to test immediately:**
- Syntax validation (bash -n)
- Version detection (check_version function)
- Connectivity checks (ssh -O check)
- Read-only operations (dig, curl, status commands)

**Requires careful testing:**
- Backup/restore logic (test on non-critical host)
- Agent updates (test on one host before rolling out)
- Checkmk configuration changes (test in staging first)

**Emergency procedures if script fails:**
1. Stop the script immediately (Ctrl+C)
2. Check log file in `/tmp/` for error location
3. Review backup in `/tmp/checkmk_upgrade_backups/` if applicable
4. Restore from backup manually using documented commands
5. Investigate root cause before retrying

## Updating Documentation

Documentation should reflect the current state of infrastructure and scripts:

- Update IP addresses when hosts change
- Update version numbers when software is upgraded
- Add new procedures when operational patterns change
- Remove or mark procedures as archived if they become obsolete
- Include dates in status tables so readers know how current information is

### Documentation Validation

Before committing documentation changes:
1. Commands referenced are tested and working
2. IP addresses match actual infrastructure
3. Version numbers match deployed software
4. Step numbers are sequential and complete
5. Table data is current (check dates)
6. Links to external docs still resolve

### Documentation Standards

All documentation follows this structure:
- **Overview section**: Purpose and context
- **Current Status tables**: For tracking multi-host operations (with dates)
- **Step-by-step procedures**: Commands with expected output
- **Troubleshooting section**: Common issues and solutions
- **Metadata footer**: Creation date and version info

#### When to Update Documentation

Update operational docs when:
- Infrastructure IPs or hostnames change
- Versions are upgraded (Checkmk, Pi-hole, BIND9)
- New hosts are added to the homelab
- Procedures are discovered to have missing steps
- Commands change due to OS or software updates
- Status of systems changes (online/offline, active/retired)

**Important:** Keep documentation in sync with actual infrastructure. Stale docs cause confusion and operational errors.
