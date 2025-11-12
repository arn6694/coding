# Homelab Operations Repository

Enterprise-grade automation scripts and comprehensive operational documentation for managing a homelab infrastructure with:
- **Monitoring:** Checkmk 2.4 with custom checks and dashboards
- **DNS:** Redundant BIND9 + Pi-hole with ad-blocking and local zone management
- **Reverse Proxy:** Nginx Proxy Manager for SSL/TLS termination
- **Integration:** Home Assistant monitoring and automation

## Repository Structure

```
.
├── CLAUDE.md              # Navigation hub and architecture guide
├── README.md              # This file
├── .gitignore             # Excludes temporary files and lock files
│
├── docs/                  # Comprehensive documentation (23 files, 292 KB)
│   ├── SCRIPTS.md         # Production script reference and quick start
│   ├── ARCHITECTURE.md    # Design patterns, infrastructure details
│   ├── DEVELOPMENT.md     # Development tasks and modification guides
│   ├── OPERATIONS.md      # Infrastructure procedures and checklists
│   ├── TROUBLESHOOTING.md # Debugging, diagnostics, and common issues
│   ├── STYLE.md          # Code standards and security practices
│   │
│   ├── dns_*.md           # DNS infrastructure documentation (4 files)
│   ├── pihole_*.md        # Pi-hole configuration and setup (3 files)
│   ├── bind*.md           # BIND9 configuration and editing guides (2 files)
│   ├── checkmk_*.md       # Checkmk agent setup and monitoring (3 files)
│   └── ...                # Additional guides (bookworm, Home Assistant, etc.)
│
├── scripts/               # Production automation scripts (2 files, 20 KB)
│   ├── checkmk_upgrade_to_2.4.sh    # Server upgrade with backups
│   └── update_checkmk_agents.sh     # Agent distribution across hosts
│
├── reference/             # Legacy files and reference materials (7 files)
│   ├── claude.md.backup   # Original unstructured documentation
│   └── ...                # Office documents, misc files
│
└── .claude/agents/        # Specialized AI agents (4 files)
    ├── Checkmk.md        # Checkmk monitoring expert (auto-activates)
    ├── network_engineer.md # DNS/BIND9/Pi-hole expert (auto-activates)
    ├── ansible.md        # Infrastructure automation expert (auto-activates)
    └── session_closer.md  # Session management agent
```

## Quick Start

### Prerequisites

- **Bash 4.0+** on control host
- **SSH access** to managed hosts with passwordless key authentication
- **Standard utilities:** `ssh`, `scp`, `dpkg`, `rpm`, `curl`, `dig`, `tar`, `gzip`
- **Root access** for local system changes (upgrade scripts use `sudo`)

### Running Scripts

```bash
# ALWAYS validate syntax first
bash -n scripts/checkmk_upgrade_to_2.4.sh
bash -n scripts/update_checkmk_agents.sh

# Upgrade Checkmk server (requires sudo)
sudo ./scripts/checkmk_upgrade_to_2.4.sh

# Distribute Checkmk agents to hosts
./scripts/update_checkmk_agents.sh
```

## Documentation Guide

### For Different Tasks

| I need to... | Read this |
|---|---|
| **Run production scripts** | [`docs/SCRIPTS.md`](docs/SCRIPTS.md) |
| **Understand architecture** | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| **Add or modify code** | [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) |
| **Manage infrastructure** | [`docs/OPERATIONS.md`](docs/OPERATIONS.md) |
| **Fix or troubleshoot** | [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) |
| **Follow standards** | [`docs/STYLE.md`](docs/STYLE.md) |
| **Understand DNS setup** | [`docs/dns_infrastructure_documentation.md`](docs/dns_infrastructure_documentation.md) |
| **Configure Pi-hole** | [`docs/pihole_migration_from_adguard.md`](docs/pihole_migration_from_adguard.md) |
| **Configure Checkmk** | [`docs/checkmk_dns_monitoring_setup.md`](docs/checkmk_dns_monitoring_setup.md) |
| **Full project context** | [`CLAUDE.md`](CLAUDE.md) |

## Script Overview

### Checkmk Upgrade (`scripts/checkmk_upgrade_to_2.4.sh`)

Safely upgrade Checkmk server with atomic backups and rollback capability.

**Features:**
- Supports 2.4.0p1 → 2.4.0p2+ upgrades
- Full backup before upgrade
- Pre-flight validation (version check, connectivity, disk space)
- Automatic rollback on failure
- Detailed timestamped logging
- Explicit user confirmations for safety

**Usage:**
```bash
sudo ./scripts/checkmk_upgrade_to_2.4.sh
```

### Agent Distribution (`scripts/update_checkmk_agents.sh`)

Distribute Checkmk agents across infrastructure with auto OS detection.

**Features:**
- Menu-driven host selection (single or bulk update)
- Auto-detects Debian (deb) vs RHEL/CentOS (rpm) per host
- Verifies agent connectivity after install
- Handles mixed-OS infrastructure seamlessly

**Usage:**
```bash
./scripts/update_checkmk_agents.sh
```

## Infrastructure Components

| Component | IP | Purpose |
|-----------|----|----|
| **Checkmk** | 10.10.10.5 | Enterprise monitoring |
| **BIND9 Primary** | 10.10.10.4 | Authoritative DNS for .lan |
| **BIND9 Secondary** | 10.10.10.2 | DNS redundancy (Zeus) |
| **Pi-hole Primary** | 10.10.10.22 | DNS resolution + ad-blocking |
| **Pi-hole Secondary** | 10.10.10.23 | DNS redundancy (Zeus) |
| **Nginx Proxy Manager** | 10.10.10.3 | Reverse proxy, SSL/TLS |
| **Home Assistant** | 10.10.10.6 | Home automation |
| **Proxmox** | 10.10.10.17 | Hypervisor |
| **Firewalla** | 10.10.10.1 | Gateway/firewall |

## Script Safety Features

All production scripts follow these patterns:

- **Error Handling:** `set -e` (exit on error) + `set -o pipefail` (fail on pipe errors)
- **Logging:** Color-coded functions with timestamps to `/tmp/`
- **Backups:** Critical operations create timestamped backups before changes
- **Validation:** Pre-flight checks validate prerequisites before execution
- **Confirmations:** Explicit user approval for destructive operations
- **Rollback:** Failed operations document rollback procedures

## Development & Contributing

### Before Modifying Scripts

```bash
# Validate syntax (REQUIRED)
bash -n scripts/checkmk_upgrade_to_2.4.sh

# Review script structure
head -30 scripts/checkmk_upgrade_to_2.4.sh

# Check code quality (optional)
shellcheck scripts/checkmk_upgrade_to_2.4.sh
```

### Git Workflow

```bash
# Validate syntax
bash -n script.sh

# Stage changes
git add <files>

# Commit with descriptive message
git commit -m "[CATEGORY] Brief description

Detailed explanation of what changed and why.

Type-of-change: feature/bugfix/docs/refactor
Related-files: file1.sh file2.md"

# Push to GitHub
git push origin master
```

**Commit categories:**
- `DOCS` - Documentation updates
- `FEAT` - New features
- `BUGFIX` - Bug fixes
- `REFACTOR` - Code restructuring
- `CHORE` - Maintenance, cleanup

## Architecture Highlights

### Monitoring
- Checkmk 2.4.0p2 with automated agent distribution
- Custom checks for DNS and infrastructure health
- Automated alerting and notifications

### DNS Infrastructure
- **BIND9 Primary** (10.10.10.4): Authoritative DNS for `.lan` domain
- **BIND9 Secondary** (10.10.10.2): Zone replication for redundancy
- **Pi-hole Primary** (10.10.10.22): DNS resolution + ad-blocking
- **Pi-hole Secondary** (10.10.10.23): Redundancy + load balancing
- Wildcard DNS routing to Nginx Proxy Manager for services

### Service Architecture
- All services behind Nginx Proxy Manager on `*.ratlm.com` domain
- Pi-hole handles external DNS recursion
- BIND9 handles internal `.lan` resolution
- Home Assistant monitored via Checkmk SSH agent

## Specialized AI Agents

This repository includes auto-activating AI agents for expert guidance:

### Checkmk Agent
Activates on Checkmk monitoring questions. Provides expert guidance on:
- Server installation and configuration
- Agent deployment and troubleshooting
- Custom checks and alerting
- REST API integration

### Network Engineer Agent
Activates on DNS/BIND9/Pi-hole questions. Provides expert guidance on:
- DNS architecture and zone management
- Pi-hole configuration and ad-blocking
- BIND9 configuration and troubleshooting
- Network infrastructure best practices

### Ansible Agent
Activates on infrastructure automation questions. Provides expert guidance on:
- Infrastructure-as-code patterns
- Idempotent playbooks
- Error handling and recovery
- Production-ready automation

## Key Files

- **[CLAUDE.md](CLAUDE.md)** - Main navigation hub with full documentation reference
- **[docs/SCRIPTS.md](docs/SCRIPTS.md)** - Quick start guide for scripts
- **[docs/OPERATIONS.md](docs/OPERATIONS.md)** - Infrastructure task procedures
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Design patterns and infrastructure details

## Status & Pending Work

### Current Infrastructure State
- ✅ Checkmk 2.4.0p2 operational
- ✅ BIND9 DNS (primary + secondary) operational
- ✅ Pi-hole (primary + secondary) operational
- ✅ Nginx Proxy Manager operational
- ✅ Home Assistant integrated with monitoring

### Known Issues & Pending Tasks
- 🔧 Pi-hole #2 DNS forwarding configuration (etc_dnsmasq_d setting)
- 🔧 Add DNS health monitoring to Checkmk
- 📝 Enable secondary BIND9 zone transfers

For detailed information, see [CLAUDE.md](CLAUDE.md) and `docs/` documentation.

---

**Last Updated:** November 11, 2025
**Repository:** https://github.com/arn6694/coding
**License:** Internal Use
