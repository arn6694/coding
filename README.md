# Homelab Operations

Automation scripts and operational documentation for managing a homelab infrastructure with enterprise monitoring (Checkmk), DNS/ad-blocking (Pi-hole), reverse proxy (Nginx Proxy Manager), and Home Assistant integrations.

## Overview

This repository contains:

- **Production automation scripts** for Checkmk server upgrades and agent distribution
- **Operational guides** for infrastructure management
- **AI agent configurations** for domain-specific guidance (Checkmk, DNS, Ansible)

## Quick Start

### Prerequisites

- Bash 4.0+
- SSH access to managed hosts with key authentication
- Standard CLI tools: `ssh`, `scp`, `dpkg`, `rpm`, `curl`, `dig`, `tar`, `gzip`

### Scripts

```bash
# Validate any script before running
bash -n script.sh

# Run Checkmk upgrade
sudo ./checkmk_upgrade_to_2.4.sh

# Distribute Checkmk agents
./update_checkmk_agents.sh
```

## Documentation

- **CLAUDE.md** - Developer context, architecture details, and style guidelines
- **Operational Guides** - Detailed procedures for DNS, Checkmk, and infrastructure tasks

## Script Overview

| Script | Purpose |
|--------|---------|
| `checkmk_upgrade_to_2.4.sh` | Upgrade Checkmk server with backup and verification |
| `update_checkmk_agents.sh` | Distribute agents to monitored hosts (auto-detects OS) |

## Architecture

- **Monitoring:** Enterprise-grade monitoring with Checkmk
- **DNS:** Redundant DNS with ad-blocking and local zone management
- **Reverse Proxy:** SSL/TLS termination for internal services
- **Home Automation:** Integration with Home Assistant

For detailed infrastructure information, see **CLAUDE.md**.

## Development

Scripts follow a standardized architecture for safety:
- Error handling: `set -e` and `set -o pipefail`
- Logging: Color-coded functions with timestamps
- Backups: Critical operations create timestamped backups
- Validation: Pre-flight checks before destructive operations

See **CLAUDE.md** for detailed guidelines.

## Git Workflow

```bash
# Validate syntax
bash -n script.sh

# Stage changes
git add <file>

# Commit
git commit -m "[CATEGORY] Brief description"

# Push
git push origin master
```

**Commit categories:** `DOCS`, `FEATURE`, `BUGFIX`, `REFACTOR`, `CHORE`

---

**Repository:** https://github.com/arn6694/coding
