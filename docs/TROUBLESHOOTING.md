# Troubleshooting Guide

This document covers debugging scripts, fixing issues, and diagnostic commands.

## When a Script Fails

**Immediate Actions:**
1. Check the timestamped log file: `ls -lt /tmp/checkmk_*.log | head -1`
2. Review the error message and log context
3. If backup exists, check: `ls -la /tmp/checkmk_upgrade_backups/`
4. Both scripts use `set -e` and `set -o pipefail` - they halt on any error with exit code 1

**Common Failure Scenarios:**

| Failure | Cause | Fix |
|---------|-------|-----|
| "command not found" (omd, dpkg, ssh) | Missing prerequisite tool | Install tool on control host or target host |
| "Permission denied (publickey)" | SSH key auth not working | Verify `~/.ssh/id_rsa` exists and SSH agent is running |
| "Connection refused" | Target host unreachable | Test: `ping <host>` and `ssh brian@<host> 'echo ok'` |
| "Already at version 2.4.0p1" | Script detected version match | This is safe - script auto-skips duplicate upgrades |
| "dpkg: error processing" | Checkmk package conflict | Check if site is running: `sudo su - monitoring -c 'omd status'` |

## Script Failure Recovery

Scripts are **idempotent where safe**:
- **Upgrade script**: Version check prevents duplicate upgrades; backups in `/tmp/checkmk_upgrade_backups/` for manual rollback
- **Agent script**: Failed installs on specific hosts don't prevent remaining hosts from updating (menu-driven selection)
- **No partial state**: Both scripts halt immediately on error - no inconsistent partial changes

**To Debug a Specific Line:**
```bash
# Add debug flag and run with set -x to trace execution
bash -x ./checkmk_upgrade_to_2.4.sh 2>&1 | tee debug.log

# Or run individual functions directly (after sourcing the script):
source ./checkmk_upgrade_to_2.4.sh
check_version    # Run just this function
verify_prerequisites  # Check dependencies
```

## Making Quick Fixes

**Pattern for fixing a bug in a script:**
```bash
# 1. Read the problematic section
head -100 checkmk_upgrade_to_2.4.sh | tail -20  # Lines 80-100 for example

# 2. Identify the issue (syntax, logic, version mismatch)

# 3. Make minimal edit
# Example: Fix a version number
OLD_TEXT='CHECKMK_VERSION_SHORT="2.4.0p1"'
NEW_TEXT='CHECKMK_VERSION_SHORT="2.4.0p2"'

# 4. Validate syntax immediately
bash -n checkmk_upgrade_to_2.4.sh

# 5. Review the change worked
grep "CHECKMK_VERSION_SHORT" checkmk_upgrade_to_2.4.sh
```

## Common Troubleshooting Commands

### Script Development Quick Reference

```bash
# Validate syntax before committing
bash -n checkmk_upgrade_to_2.4.sh
bash -n update_checkmk_agents.sh

# Check script structure (see configuration block)
head -30 script.sh

# Run syntax check AND test dependencies
bash -n script.sh && echo "✓ Syntax valid"

# Trace execution (for debugging specific lines)
bash -x ./script.sh 2>&1 | tee debug.log

# Check if tools are available
which bash ssh scp dpkg rpm curl dig tar gzip
```

### Checkmk Diagnostics

```bash
# Check agent connectivity from monitoring server
sudo su - monitoring -c 'cmk -d <hostname>'

# View site status
omd status

# Check Checkmk version
omd version

# List all monitored hosts
sudo su - monitoring -c 'cmk --list-hosts'

# Force service discovery on a host
sudo su - monitoring -c 'cmk -I <hostname>'
```

### DNS Diagnostics

```bash
# Test Pi-hole DNS resolution (primary and secondary)
dig @10.10.10.22 example.lan
dig @10.10.10.23 example.lan

# Test wildcard DNS for .ratlm.com
dig @10.10.10.22 test.ratlm.com

# Check dnsmasq wildcard config
cat /etc/dnsmasq.d/02-ratlm-local.conf

# Pi-hole logs (tail mode)
pihole -t

# Check BIND9 zone transfer status
sudo rndc status
dig @10.10.10.4 example.lan AXFR
```

### Network Connectivity

```bash
# Test SSH access to managed hosts
ssh brian@<host-ip> 'hostname && uptime'

# Check service availability via NPM
curl -I https://checkmk.ratlm.com
curl -I https://proxmox.ratlm.com

# Verify DNS servers are responding
for dns in 10.10.10.22 10.10.10.23; do
  echo "=== Testing DNS $dns ==="
  dig @$dns google.com +short
done

# Test agent port connectivity
nc -zv <host-ip> 6556
```

## Pre-Commit Validation

Before committing any changes, follow this checklist to ensure quality and safety:

### Script Changes
- [ ] Syntax is valid: `bash -n script.sh`
- [ ] All variables are quoted: `"$variable"` not `$variable`
- [ ] Error handling preserved: `set -e` and `set -o pipefail` present
- [ ] Logging functions used: No bare `echo` statements for user output
- [ ] Configuration block updated: Version numbers, IPs, paths at top
- [ ] Comments added: Explain what changed and why
- [ ] Tested on non-critical host first (if making changes to agent/upgrade logic)

### Documentation Changes
- [ ] IP addresses match actual infrastructure
- [ ] Version numbers match deployed software
- [ ] Commands referenced are tested and working
- [ ] External links still resolve
- [ ] Step numbers are sequential
- [ ] Table data is current (check dates)

### Agent Changes
- [ ] YAML metadata is valid (test with `---` delimiters)
- [ ] Documentation sources URLs are correct
- [ ] Activation trigger description is clear
- [ ] Examples provided for topic-based routing
- [ ] No trailing whitespace
