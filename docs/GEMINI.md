# Gemini Code Assistant Context

## Directory Overview

This directory contains a collection of scripts and documentation for managing a personal homelab environment. The documents serve as guides and operational runbooks for tasks related to network services and monitoring, specifically involving Checkmk, Pi-hole, Nginx Proxy Manager (NPM), and Home Assistant.

The primary purpose is to centralize knowledge and automate common administrative tasks.

## Key Files

*   `checkmk_agent_update_guide.md`: A detailed guide on updating Checkmk agents on various hosts (Linux and Windows) from version 2.3.0p24 to 2.4.0p2. It includes manual steps, troubleshooting, and a bulk update script.

*   `update_checkmk_agents.sh`: An interactive shell script to automate the update of Checkmk agents on multiple Linux hosts. It detects the OS (Debian/RPM-based) and applies the correct package.

*   `checkmk_upgrade_to_2.4.sh`: A comprehensive shell script to upgrade the Checkmk Raw Edition server from version 2.3 to 2.4 on Debian 12. It includes pre-flight checks, backups, the upgrade process, and post-upgrade verification.

*   `homeassistant_checkmk_fix.md`: A runbook detailing the process of enabling Checkmk monitoring for a Home Assistant OS instance. It covers installing the agent via SSH, setting up key-based authentication, and configuring the necessary datasource rules in Checkmk.

*   `pihole_migration_from_adguard.md`: A step-by-step guide for migrating DNS ad-blocking services from AdGuard Home to a Pi-hole and Unbound setup. It covers blocklist migration, network cutover, and post-migration verification.

*   `pihole_npm_wildcard_dns.md`: Technical documentation on how to configure Pi-hole to resolve wildcard DNS for a local domain (`*.ratlm.com`), pointing all subdomains to an Nginx Proxy Manager instance for simplified service hosting.

*   `.claude/`: This directory appears to contain settings and context for a different AI assistant, likely used previously.

## Usage

The files in this directory are intended for system administration of a personal homelab.

*   **Markdown Files (`.md`):** These should be read as instructional guides or documentation. They provide context, step-by-step commands, and troubleshooting advice for specific administrative tasks. They are valuable for understanding the "why" behind the configurations.

*   **Shell Scripts (`.sh`):** These are executable scripts designed to automate the procedures described in the markdown files. They should be run to perform tasks like updating Checkmk agents or upgrading the Checkmk server. Review the script's contents and configuration variables before execution.
