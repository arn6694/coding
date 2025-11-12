# Architecture Guide

This document describes the code architecture, design patterns, and infrastructure components of this repository.

## Code Architecture

### Shell Scripts Design Pattern

All shell scripts follow this standardized architecture for safety and auditability:

**File Structure:**
```bash
#!/bin/bash
set -e           # Line 1: Exit on error
set -o pipefail  # Line 2: Exit on pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
...

# === CONFIGURATION BLOCK ===
VARIABLE_NAME="value"  # ALL dynamic values here (versions, IPs, paths)
CHECKMK_VERSION_SHORT="2.4.0p2"  # Example: version to upgrade TO
CHECKMK_SERVER="10.10.10.5"      # Example: server IP
BACKUP_DIR="/tmp/checkmk_upgrade_backups"

# === LOGGING FUNCTIONS ===
log() { ... }           # Internal logging with timestamps
log_success() { ... }   # Green ✓ - success
log_error() { ... }     # Red - failure
log_warning() { ... }   # Yellow - caution
log_info() { ... }      # Blue - information
error_exit() { ... }    # Log error and exit(1)

# === UTILITY FUNCTIONS ===
check_root() { ... }              # Verify sudo/root
check_connectivity() { ... }      # Test SSH access
verify_prerequisites() { ... }    # Check all required tools

# === MAIN LOGIC ===
main() {
    pre_flight_checks
    backup_state
    apply_changes
    verify_changes
    cleanup
}

main "$@"  # Execute with command line args
```

**Execution Flow:**
1. **Shebang + Error Handling** - Script fails immediately on any error
2. **Configuration Block** - All `UPPER_CASE` variables grouped at top
3. **Logging Functions** - Color-coded, timestamped output for all user messages
4. **Utility Functions** - Reusable checks and helpers
5. **Pre-flight Validation** - Root check, connectivity, dependencies, version detection
6. **Main Operation** - Backup → Execute → Verify → Cleanup
7. **Error Recovery** - Scripts halt on failure; logs provide rollback instructions

**Key Safety Features:**
- **Atomic Changes**: Backup before any modification; restore if needed
- **Explicit Confirmations**: Interactive prompts for destructive operations with context
- **Timestamped Logs**: Every operation logged to `/tmp/` for audit trail and debugging
- **No Silent Failures**: Color-coded output + comprehensive logging
- **Clear Error Context**: Error messages include what failed and where to find logs

### Infrastructure State Pattern

Scripts maintain idempotent operations where appropriate:
- **Safe to Re-Run**: Version detection before upgrades prevents duplicate upgrades
- **Destructive Operations**: Always require explicit confirmation (read prompts)
- **Failed Operations**: Script halts immediately; no partial state changes
- **Recovery Options**: Backup in `/tmp/checkmk_upgrade_backups/` for manual restoration

## Specialized AI Agents

The repository uses AI agents configured in `.claude/agents/` that automatically activate for relevant question domains:

- **Agents auto-activate** based on question topic (no manual invocation needed)
- Each agent has YAML metadata (name, description trigger, model preference, color)
- Agents automatically search and cite official documentation for their domain

### Available Agents

1. **Checkmk Agent** (`Checkmk.md`)
   - Activates for: Checkmk monitoring, alerting, APIs, checks, configuration
   - Expertise: Checkmk 2.4 administration, REST API integration, custom checks
   - Behavior: Automatically searches official Checkmk docs (https://docs.checkmk.com/latest/en/)
   - Key capability: Always cites specific official documentation sources in responses

2. **Network Engineer Agent** (`network_engineer.md`)
   - Activates for: DNS, BIND9, Pi-hole, network infrastructure questions
   - Expertise: BIND9 configuration, DNS architecture, Pi-hole setup, network monitoring
   - Behavior: Automatically references BIND9 docs (https://bind9.readthedocs.io/) and Pi-hole docs (https://docs.pi-hole.net/)
   - Key capability: Provides complete network infrastructure guidance with official sources

3. **Ansible Agent** (`ansible.md`)
   - Activates for: Ansible automation, infrastructure-as-code, playbooks
   - Expertise: Infrastructure automation, configuration management, network automation
   - Behavior: References Ansible official documentation at https://docs.ansible.com/
   - Key capability: Production-ready patterns with idempotency and error handling

### Modifying or Creating Agents

Agents use YAML metadata at the top for configuration:
```yaml
---
name: Agent Name
description: whenever [topic] questions are asked
model: sonnet
color: blue
---
```

**Metadata fields:**
- `name`: Display name for the agent
- `description`: Activation trigger (e.g., "whenever DNS or network questions are asked")
- `model`: Claude model to use (haiku, sonnet, opus)
- `color`: Visual indicator in UI (blue, green, yellow, red)

**To create or modify an agent:**

1. **Create file:** `.claude/agents/agent-name.md`
2. **Add metadata block** with YAML frontmatter (see example above)
3. **Include documentation section** with primary sources:
   ```
   PRIMARY DOCUMENTATION SOURCES (ALWAYS SEARCH THESE):
   - Official docs: https://docs.example.com/
   ```
4. **Implement topic-based URL routing:**
   ```
   AUTOMATIC URL ROUTING - USE THESE BASED ON QUESTION TOPIC:
   When the user asks about [topic]:
   → ALWAYS cite https://docs.example.com/specific-page
   ```
5. **Add core expertise section** describing what agent specializes in
6. **Save and test** - No restart needed; agents load dynamically when questions match the `description` trigger

**Example activation patterns:**
- `"whenever checkmk questions are asked"` - Matches Checkmk monitoring queries
- `"whenever DNS or BIND or network questions are asked"` - Matches DNS infrastructure queries
- `"whenever ansible or automation questions are asked"` - Matches infrastructure-as-code queries

## Infrastructure Components

### Checkmk Monitoring
- **Host**: `checkmk` (10.10.10.5)
- **Version**: 2.4.0p2 (scripts support p1 and p2)
- **Site name**: `monitoring`
- **Agent distribution path**: `/omd/sites/monitoring/share/check_mk/agents/`
- **Management**: Via `cmk` CLI and REST API

### Pi-hole DNS
- **Primary**: `zero` (10.10.10.22, Proxmox LXC 105)
- **Secondary**: `zeus` (10.10.10.23, Docker on Zeus)
- **Version**: Pi-hole v6 with custom dnsmasq configuration
- **Wildcard DNS**: `*.ratlm.com` → NPM
- **Configuration file**: `/etc/dnsmasq.d/02-ratlm-local.conf`
- **Pihole config**: `etc_dnsmasq_d = true` in `/etc/pihole/pihole.toml`
- **Behavior**: Forwards `.lan` queries to BIND9 servers

### BIND9 DNS
- **Primary**: 10.10.10.4 (Proxmox LXC 119)
- **Secondary**: 10.10.10.2 (Zeus Docker)
- **Purpose**: Authoritative DNS for `.lan` domain
- **Replication**: Master-slave zone replication for redundancy
- **Access**: SSH as brian (passwordless), sudo enabled
- **Zone file**: `/etc/bind/zones/db.lan`
- **Access methods:**
  - Direct SSH: `ssh brian@10.10.10.4`
  - Via Proxmox container: `ssh brian@10.10.10.17 && sudo pct enter 119`

### Nginx Proxy Manager
- **Host**: 10.10.10.3
- **Function**: Receives all `*.ratlm.com` traffic via wildcard DNS
- **Role**: SSL/TLS termination for internal services

### Home Assistant
- **Host**: 10.10.10.6
- **Platform**: Home Assistant OS (Alpine Linux base)
- **Monitoring**: Via Checkmk with SSH-based agent

### Network Architecture

The homelab uses internal `10.10.10.0/24` network with `.ratlm.com` domain for services:
- **DNS resolution**: Handled by Pi-hole with wildcard support
- **Service proxying**: All external-facing services proxied through NPM
- **Monitoring**: Centralized in Checkmk
- **Firewall**: Firewalla Gold (10.10.10.1)
- **Hypervisor**: Proxmox (10.10.10.17)

## Repository Structure

### Main Directory Contents
- **Production Scripts** (`*.sh`):
  - `checkmk_upgrade_to_2.4.sh` (373 lines) - Upgrades Checkmk with backups and version verification
  - `update_checkmk_agents.sh` (330 lines) - Distributes Checkmk agents to managed hosts
- **Documentation** (`*.md`): Operational guides, implementation procedures, and troubleshooting
- **Specialized Agents** (`.claude/agents/`): Auto-activating domain experts with official documentation

### Key File Locations
- **Production Scripts**: `/home/brian/claude/*.sh`
- **Version Configuration**: Top 20 lines of each script (all dynamic values here)
- **Backup/Logs**: `/tmp/checkmk_upgrade_backups/` and `/tmp/checkmk_upgrade_*.log` files
- **Documentation**: Mix of guides (checkmk_dns_monitoring_setup.md, dns_infrastructure_documentation.md, etc.)
- **Agents**: `.claude/agents/` for domain-specific guidance

### Required CLI Tools

All scripts rely on these tools (verify with `which <tool>`):
- `bash` - Script runtime (version 4.0+)
- `ssh`, `scp` - Remote host access (passwordless key auth required)
- `dpkg`, `rpm` - Package detection and installation
- `curl`, `wget` - HTTP operations for Checkmk downloads
- `dig` - DNS diagnostics
- `omd` - Checkmk OMD (OpenMonitoring Distribution) CLI for version checks and diagnostics
- Standard utilities: `grep`, `awk`, `sed`, `tar`, `gzip`, `date`, `du`
