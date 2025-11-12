# Production Scripts Reference

This document covers the two main production scripts, their purpose, configuration, and how to use them.

## Quick Start

Both production scripts are interactive and will prompt for confirmation before making destructive changes:

```bash
# Checkmk server upgrade (full backup + version check + rollback capability)
# Current versions: checkmk_upgrade_to_2.4.sh supports 2.4.0p1 → 2.4.0p2+
sudo ./checkmk_upgrade_to_2.4.sh

# Update Checkmk agents (menu-driven: select hosts or bulk update all)
# Automatically detects Debian (deb) vs RHEL/CentOS (rpm) systems
./update_checkmk_agents.sh
```

## Before Running Any Script

Always validate syntax and review configuration:

```bash
# Syntax validation (REQUIRED before any modifications)
bash -n script.sh

# Review version and host configuration
head -30 script.sh  # Check UPPER_CASE variables at top

# Simulate: read the script to understand what it will do
less script.sh
```

## Script Validation and Testing

Before running or modifying scripts, validate syntax and understand the scripts:

```bash
# Syntax check (required before any script modification)
bash -n script.sh

# Code quality check (optional but recommended)
shellcheck script.sh

# Preview what the script will do (read-only, safe to run)
less checkmk_upgrade_to_2.4.sh  # Review version config and pre-flight checks
less update_checkmk_agents.sh    # Review host list and package paths
```

**Safety Note:** Both scripts use `set -e` and `set -o pipefail` - they will halt immediately on any error and provide clear logging. Check `/tmp/` for timestamped log files after execution.

## Prerequisites

- **Bash 4.0+** on control host (where scripts run)
- **SSH access** to managed hosts with passwordless key authentication
- **Standard utilities**: `grep`, `awk`, `sed`, `tar`, `gzip`, `scp`, `ssh`
- **Checkmk server**: `omd` CLI tool available for diagnostics
- **DNS testing**: `dig` command (part of `bind-tools`)
- **Root access** for local system changes (upgrade scripts use `sudo`)

## Most-Used Commands Reference

| Task | Command |
|------|---------|
| Validate script syntax | `bash -n script.sh` |
| Check Checkmk version | `sudo su - monitoring -c 'omd version'` |
| Test host connectivity | `ssh brian@<host> 'echo ok'` |
| Test DNS resolution | `dig @10.10.10.4 hostname.lan +short` |
| Force service discovery | `sudo su - monitoring -c 'cmk -I <hostname>'` |
| Check agent version | `ssh brian@<host> 'dpkg -l \| grep check-mk-agent'` (Debian) |
| View Checkmk logs | `tail /tmp/checkmk_upgrade_*.log` |
| Reload BIND9 | `ssh brian@10.10.10.4 'sudo rndc reload'` |
| Check backup exists | `ls -la /tmp/checkmk_upgrade_backups/` |
| Test NPM service | `curl -I https://checkmk.ratlm.com` |

## Script Details

### `checkmk_upgrade_to_2.4.sh` - Checkmk Server Upgrade

**Purpose**: Upgrade Checkmk Raw Edition server from one version to another

**Requires**: `sudo` (runs as root for system package operations)

**Entry Point**: Line ~360 - `check_root`, then upgrade flow

**Key Functions** (in order of use):
- `check_checkmk_running()` - Verify OMD site is running
- `check_version()` - Compare current vs target version, skip if already at target
- `backup_site()` - Create timestamped backup of entire monitoring site
- `download_package()` - Fetch Checkmk DEB from download.checkmk.com
- `install_package()` - Use dpkg to install upgrade
- `verify_upgrade()` - Check site started cleanly post-upgrade

**Version Configuration** (Lines 18-22):
- `CHECKMK_VERSION_SHORT="2.4.0p1"` - What version to upgrade TO (update this)
- `DOWNLOAD_URL` - Derives from version, usually doesn't need changes

**Safety Checks**: Pre-flight validation (lines ~200-250) checks for:
- Required tools availability
- Existing backups
- Current version detection

### `update_checkmk_agents.sh` - Checkmk Agent Distribution

**Purpose**: Deploy Checkmk agents to monitored hosts for metrics collection

**Requires**: No sudo (SSH to remote hosts as `brian` user with key auth)

**Entry Point**: Line ~300 - Menu-driven interface with host selection

**Key Functions**:
- `menu_interface()` - Interactive menu to select individual hosts or bulk update
- `download_agent_package()` - Fetch DEB/RPM from Checkmk server's agent directory
- `detect_os()` - SSH to host and check if Debian (dpkg) or RHEL (rpm)
- `install_agent()` - SCP package to host and install via dpkg/rpm
- `verify_agent()` - SSH back to host and verify agent connectivity

**Host List** (Lines 23-30): Array of target hosts (IP addresses)

**Version Configuration** (Lines 16-22):
- `TARGET_VERSION="2.4.0p2"` - Version of agents to deploy (update when distributing new agents)
- `AGENT_DEB` and `AGENT_RPM` - Paths on Checkmk server's agent directory

**Important**: Script auto-detects OS type; check at lines ~270 for how it handles mixed Debian/RHEL infrastructure

## Script Modification Reference

When modifying scripts, always update these sections in order:

1. **Configuration variables** (top 30 lines) - Version numbers, IPs, paths
2. **Logging functions** (skip unless changing output format)
3. **Utility functions** (skip unless fixing bugs)
4. **Main function** - The actual operation logic
5. **Test syntax**: `bash -n script.sh`
6. **Test on non-critical host**: Run preview or with test flag if available

### Example: Update Agent Distribution Target Version

```bash
# 1. Edit the TARGET_VERSION in update_checkmk_agents.sh
TARGET_VERSION="2.4.0p3"  # Changed from p2

# 2. Verify the agent packages exist on Checkmk server
#    Check that /omd/sites/monitoring/share/check_mk/agents/ has:
#    - check-mk-agent_2.4.0p3-1_all.deb
#    - check-mk-agent-2.4.0p3-1.noarch.rpm

# 3. Validate syntax
bash -n update_checkmk_agents.sh

# 4. Test on a single host first (use menu to select one)
./update_checkmk_agents.sh
```

## Quick Reference: Operations Checklist

### Upgrading Checkmk Server

**Pre-Upgrade Checklist:**
- [ ] Verify current version: `sudo su - monitoring -c 'omd version'`
- [ ] Check site is healthy: `sudo su - monitoring -c 'omd status'`
- [ ] Verify backup directory exists: `ls -d /tmp/checkmk_upgrade_backups`
- [ ] Verify network connectivity to checkmk.download.com: `curl -I https://download.checkmk.com/`
- [ ] Edit `checkmk_upgrade_to_2.4.sh` line 18 with target version (if needed)

**Execution:**
```bash
bash -n ./checkmk_upgrade_to_2.4.sh  # Validate first
sudo ./checkmk_upgrade_to_2.4.sh      # Run upgrade (will prompt for confirmation)
```

**Post-Upgrade:**
- [ ] Check version upgraded: `sudo su - monitoring -c 'omd version'`
- [ ] Review backup location in logs: `tail /tmp/checkmk_upgrade_*.log`
- [ ] Test Checkmk web UI: `curl -I https://checkmk.ratlm.com`
- [ ] Force host rediscovery if needed: `sudo su - monitoring -c 'cmk -I <hostname>'`

### Updating Checkmk Agents

**Pre-Update Checklist:**
- [ ] Verify target version packages exist on Checkmk server:
  ```bash
  ssh brian@10.10.10.5 'ls -la /omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2*'
  ```
- [ ] Test SSH access to at least one target host: `ssh brian@<host> 'echo ok'`
- [ ] Edit `update_checkmk_agents.sh` lines 16-22 if updating target version

**Execution:**
```bash
bash -n ./update_checkmk_agents.sh   # Validate first
./update_checkmk_agents.sh            # Run with interactive menu
# Select single host to test, then "Bulk update all" when confident
```

**Post-Update:**
- [ ] Verify agent installed: `ssh brian@<host> 'dpkg -l | grep check-mk-agent'` (Debian)
- [ ] Or for RPM: `ssh brian@<host> 'rpm -qa | grep check-mk-agent'` (RHEL/CentOS)
- [ ] Force service discovery on hosts: `sudo su - monitoring -c 'cmk -I <hostname>'`
