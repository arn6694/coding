# Bookworm Server (10.10.10.7) Decommissioning Plan

## Overview
The Bookworm server hosts a comprehensive media and gaming infrastructure with 30+ Docker containers running services like Plex, Immich, Sonarr, Radarr, Kasm remote desktop, game servers (AMP), monitoring (Uptime Kuma, Prometheus), and more. The server also runs Tailscale and Checkmk agents.

All services must be migrated to the new Proxmox server (10.10.10.17) before decommissioning.

## Current Services Inventory

### Running Docker Containers (30+ containers)
- **Media Management**: Plex, Sonarr, Radarr, Prowlarr, Jackett, Tautulli, Deluge, Transmission
- **Photo Management**: Immich (server, postgres, redis, machine learning)
- **Remote Desktop**: Kasm (nginx proxy, api, manager, agent, guac, db, redis, share)
- **Game Servers**: Valheim, AMP (VaL01, Enshrouded01)
- **Monitoring**: Uptime Kuma, Prometheus (exited), Node Exporter, Grafana
- **Utilities**: Portainer, Filebrowser, Homarr (dashboard), Redis
- **Network**: Gluetun (VPN), SOCKS5 proxy, AdGuard (exited)
- **System**: Multiple Redis instances, Postgres

### System Services
- SSH (OpenSSH)
- Docker daemon
- Tailscale (logged out, service running)
- Checkmk agents (async and controller daemon)
- Nginx processes (Kasm proxy container)

### Storage
- /docker: 98GB LV, 27GB used (container data)
- /home: 32GB LV, 27GB used (user configs?)
- /var: 247GB LV, 136GB used (logs, system data)
- NFS mounts: /DATA/Media/Movies (27TB), /DATA/Media/TV Shows (27TB) from 10.10.10.2

## Migration Strategy

### Phase 1: Preparation
1. **Backup Data**: Create full backup of /docker, /home, /var
2. **Document Configurations**: Export Portainer stacks, docker-compose files, container configs
3. **Prepare Proxmox**: Install Docker, Docker Compose, required dependencies

### Phase 2: Minimal Service Migration
**Note**: Based on usage review, migrating only essential services. Media automation (Sonarr/Radarr/Prowlarr), downloaders (Transmission/Deluge), and Portainer are not needed. Kasm and Immich deferred for later evaluation. Gaming services may be redundant with Proxmox's AMP setup.

1. **Install Checkmk Agent on Proxmox**:
   - Configure monitoring for the new server

2. **Migrate Monitoring Stack** (if not covered by Checkmk):
   - Uptime Kuma, Grafana, Prometheus, Node Exporter

3. **Migrate Utilities** (if needed):
   - Filebrowser (for file access)
   - Homarr (dashboard, if useful)

4. **Migrate Valheim Server**:
   - Valheim data (VaL01) successfully transferred to Proxmox Amp VM (10.10.10.13) at /srv/.ampdata/instances/VaL01
   - Symlink in place: /home/amp/.ampdata -> /srv/.ampdata
   - Firewall opened for UDP ports 2456-2458
   - Next: Create Valheim instance in AMP web UI, start server, test connection server

5. **Deferred Services** (evaluate later):
   - Kasm remote desktop stack
   - Immich photo management
   - Other gaming servers (Valheim, AMP VaL01)
   - Network services (Gluetun, SOCKS5, AdGuard)

### Phase 3: System Services
1. **Install Checkmk Agent** on Proxmox
2. **Configure Tailscale** if required
3. **Migrate NFS Mounts** from NAS (10.10.10.2)

### Phase 4: Testing and Validation
1. Test all migrated services functionality
2. Verify data integrity
3. Update client configurations (DNS, bookmarks)
4. Test monitoring and alerting

### Phase 5: Decommissioning
1. Stop all services on Bookworm
2. Remove from Checkmk monitoring
3. Update DNS records if Bookworm IPs referenced
4. Power off server safely

## Risk Mitigation
- **Data Loss**: Multiple backups, test restores
- **Downtime**: Migrate non-critical services first
- **Dependency Issues**: Document all container links and networks
- **Network Changes**: Update firewall rules, port mappings

## Timeline
- Phase 1: 1-2 days
- Phase 2-3: 3-5 days (depending on complexity)
- Phase 4-5: 1-2 days

## Prerequisites
- Proxmox server (10.10.10.17) ready with sufficient storage
- Network access between servers
- Backup storage available
- Maintenance window scheduled

## Post-Migration
- Monitor services for 1-2 weeks
- Clean up old backups after confirmation
- Document any configuration changes
- Update network diagrams