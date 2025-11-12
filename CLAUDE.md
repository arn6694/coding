# CLAUDE.md - Repository Guidance

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. The documentation is split into focused, topic-specific files for easier navigation.

## Repository Overview

This is a homelab operations repository containing scripts and documentation for managing:
- **Monitoring**: Enterprise monitoring via Checkmk 2.4
- **DNS**: Pi-hole DNS/ad-blocking with BIND9 authoritative DNS
- **Services**: Nginx Proxy Manager for reverse proxy and SSL/TLS
- **Integration**: Home Assistant monitoring via Checkmk

## Quick Navigation

### I want to...
| Task | Document | Section |
|------|----------|---------|
| Run production scripts | [`docs/SCRIPTS.md`](docs/SCRIPTS.md) | Quick Start |
| Understand code architecture | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Code Architecture |
| Add or modify scripts | [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Common Development Tasks |
| Perform infrastructure operations | [`docs/OPERATIONS.md`](docs/OPERATIONS.md) | Task-specific procedures |
| Debug or troubleshoot issues | [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Diagnostics & Fixes |
| Follow code/doc standards | [`docs/STYLE.md`](docs/STYLE.md) | Guidelines |
| Ask about Checkmk | (auto-activates) | `.claude/agents/Checkmk.md` |
| Ask about DNS/networking | (auto-activates) | `.claude/agents/network_engineer.md` |
| Ask about Ansible | (auto-activates) | `.claude/agents/ansible.md` |

## Specialized Agents (Auto-Activate)

These agents activate automatically when relevant questions are asked:
- **`Checkmk.md`** - Checkmk monitoring, alerts, APIs, checks
- **`network_engineer.md`** - DNS, BIND9, Pi-hole, networking infrastructure
- **`ansible.md`** - Ansible automation, infrastructure-as-code, playbooks

No manual activation needed - just ask questions about these topics.

## Key Infrastructure Reference

### Most-Used Commands
| Task | Command |
|------|---------|
| Validate script syntax | `bash -n script.sh` |
| Check Checkmk version | `sudo su - monitoring -c 'omd version'` |
| Test host connectivity | `ssh brian@<host> 'echo ok'` |
| Test DNS resolution | `dig @10.10.10.4 hostname.lan +short` |
| Force service discovery | `sudo su - monitoring -c 'cmk -I <hostname>'` |
| Check agent version (Debian) | `ssh brian@<host> 'dpkg -l \| grep check-mk-agent'` |
| View Checkmk logs | `tail /tmp/checkmk_upgrade_*.log` |
| Reload BIND9 | `ssh brian@10.10.10.4 'sudo rndc reload'` |
| Check backup exists | `ls -la /tmp/checkmk_upgrade_backups/` |
| Test NPM service | `curl -I https://checkmk.ratlm.com` |

### Infrastructure Components Summary
- **Checkmk**: 10.10.10.5 (monitoring site)
- **BIND9 Primary**: 10.10.10.4 (Proxmox LXC 119)
- **BIND9 Secondary**: 10.10.10.2 (Zeus Docker)
- **Pi-hole Primary**: 10.10.10.22 (Proxmox LXC 105)
- **Pi-hole Secondary**: 10.10.10.23 (Zeus Docker)
- **Nginx Proxy Manager**: 10.10.10.3
- **Home Assistant**: 10.10.10.6
- **Firewalla**: 10.10.10.1
- **Proxmox**: 10.10.10.17

## Documentation Files

All detailed information is organized into topic-specific files in the `docs/` directory:

- **[docs/SCRIPTS.md](docs/SCRIPTS.md)** - Production script reference and quick start
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Code design patterns and infrastructure details
- **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** - Adding/modifying scripts and development tasks
- **[docs/OPERATIONS.md](docs/OPERATIONS.md)** - Infrastructure tasks and operational procedures
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Debugging scripts and diagnostics
- **[docs/STYLE.md](docs/STYLE.md)** - Code standards, documentation guidelines, and security practices

## Quick Reference Guide

Use this when you need to find information fast:

1. **Quick reference?** → Start with **[CLAUDE.md](CLAUDE.md)**
2. **Running scripts?** → See **[docs/SCRIPTS.md](docs/SCRIPTS.md)**
3. **Adding/modifying code?** → See **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**
4. **Doing infrastructure work?** → See **[docs/OPERATIONS.md](docs/OPERATIONS.md)**
5. **Something broke?** → See **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**
6. **Need to know standards?** → See **[docs/STYLE.md](docs/STYLE.md)**
7. **Understanding the design?** → See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

## Available Agents

The following specialized agents are available and will auto-activate when relevant:

### Project-Specific Agents (`.claude/agents/` in this repository)
- **`Checkmk.md`** - Checkmk monitoring, alerts, APIs, checks (auto-activates on Checkmk questions)
- **`network_engineer.md`** - DNS, BIND9, Pi-hole, networking (auto-activates on network questions)
- **`ansible.md`** - Ansible automation, infrastructure-as-code (auto-activates on Ansible questions)
- **`session_closer.md`** - Session management for wrapping up work sessions

### Global Agents (`~/.claude/agents/`)
- **`Python-Instructor.md`** - Python advice, tips, and best practices (auto-activates on Python questions)
- **`youtube_transcript_extractor.md`** - Extract detailed technical transcripts from YouTube videos and save to Obsidian (auto-activates when extracting YouTube content)

## Custom Prompts and Skills Registry

This section documents all custom prompts, agents, and skills created for this repository. Use this as a reference when you need specialized functionality.

### YouTube Transcript Extraction

**File:** `~/.claude/agents/youtube_transcript_extractor.md`

**Purpose:** Extract detailed technical transcripts from YouTube videos with full command documentation and save them to Obsidian notebook.

**When to Use:**
- You want to preserve video content about technical topics
- You need to extract commands, examples, or procedures from a video
- You want reproducible steps from a tutorial formatted for your Obsidian vault

**How to Activate:**
Just ask something like:
- "Extract the transcript from this YouTube video: [URL]"
- "Grab the detailed transcript and save it to Obsidian: [URL]"
- "Create a technical transcript guide from: [URL]"

**What It Does:**
- Extracts complete transcript with timestamps
- Identifies and documents all commands with exact syntax
- Captures examples with input/output
- Documents prerequisites and tool versions
- Creates reproducible step-by-step procedures
- Saves formatted markdown to `/home/brian/Documents/Notes/`

**Output Format:**
- Video metadata (title, channel, date, duration)
- Overview of main topics
- Prerequisites section
- Commands and examples with explanations
- Step-by-step procedures
- Best practices and troubleshooting
- Related commands and references
- Proper markdown with code blocks (language-specific)

---

### Brutal Critic

**File:** `.claude/agents/brutal-critic.md`

**Purpose:** Ruthlessly critique scripts, code, outlines, ideas, and technical work with intentionally harsh, framework-focused feedback that exposes weaknesses and forces better decisions.

**When to Use:**
- You want to **tear apart a script** before it goes to production
- You need **honest feedback on an outline** before writing documentation
- You want to **validate architectural decisions** (or expose them as wrong)
- You need someone to **call out lazy thinking** or dangerous shortcuts
- You're **designing a new process** and want it bulletproofed before rollout
- You want **framework-based feedback** grounded in industry standards and best practices

**How to Activate:**
Just ask something like:
- "Brutal critic: review this script"
- "Give me brutal criticism on this approach"
- "Tear apart this outline - what's wrong with it?"
- "Brutal critic mode: is this a good way to handle X?"
- "Critique this design - don't hold back"

**What It Does:**
- Analyzes work through 7 critical frameworks (Pattern Matching, Risk Assessment, Maintainability, Scalability, Security, Efficiency, Clarity)
- Identifies specific issues and their consequences
- Compares against industry standards and best practices
- Forces examination of assumptions and failure modes
- Provides concrete recommendations for improvement
- Grades the work with honest assessment

**Analysis Framework:**
1. **Pattern Matching** - Does this follow best practices?
2. **Risk Assessment** - What breaks and what's the blast radius?
3. **Maintainability** - Can someone else understand this?
4. **Scalability** - Does this design scale?
5. **Security & Safety** - What's exposed or unsafe?
6. **Efficiency** - Is this the simplest solution?
7. **Documentation & Clarity** - Is the intention clear?

**Output Format:**
- **The Verdict** - One-line core problem summary
- **What's Actually Wrong** - Specific issues identified
- **Why This Matters** - Impact and consequences
- **What You Should Do Instead** - Concrete recommendations
- **Questions You Didn't Ask** - Holes in your thinking
- **Grade** - F/D/C/B/A rating with reasoning

**Key Characteristics:**
- Harsh about the work, never about the person
- Always provides path forward (criticism + solutions)
- Compares against proven standards and frameworks
- Questions assumptions without accepting excuses
- Acknowledges genuinely good work
- Refuses to sugarcoat obvious problems

---

## How to Add New Prompts/Skills

When creating new custom prompts, agents, or skills:

1. **Create the file** in appropriate location:
   - Project-specific agents: `.claude/agents/agent-name.md`
   - Global agents: `~/.claude/agents/agent-name.md`
   - Skills: Follow MCP server conventions

2. **Add to CLAUDE.md** immediately under "Custom Prompts and Skills Registry":
   - Include filename/location
   - Describe purpose and use cases
   - Explain how to activate it
   - Detail what it does
   - Show example usage
   - Note any output locations or special behaviors

3. **Follow this template:**
   ```markdown
   ### Feature Name

   **File:** location/filename.md

   **Purpose:** One-line description

   **When to Use:**
   - Use case 1
   - Use case 2

   **How to Activate:**
   Example command or trigger

   **What It Does:**
   - Bullet point 1
   - Bullet point 2

   **Output Format:**
   - Details about output
   - File locations
   - Format specifications
   ```

4. **Commit with message:**
   ```
   FEAT: Add [feature name] prompt/skill

   Description of what it does and when to use it.
   ```

This ensures nothing is forgotten and you always have a reference guide!
