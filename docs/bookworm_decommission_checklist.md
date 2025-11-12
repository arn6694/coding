# Bookworm Server Decommissioning Checklist

## Pre-Decommissioning Verification
- [ ] All critical services successfully migrated to Proxmox (10.10.10.17)
- [ ] Data backups verified and accessible
- [ ] Client applications updated with new service IPs/URLs
- [ ] DNS records updated if referencing 10.10.10.7
- [ ] Monitoring alerts configured for new locations
- [ ] Team notified of migration completion

## Service Shutdown Sequence
- [ ] Stop game servers (AMP instances) gracefully
- [ ] Stop media services (Plex, Sonarr, Radarr, etc.)
- [ ] Stop monitoring services (Uptime Kuma, Prometheus)
- [ ] Stop remote desktop (Kasm stack)
- [ ] Stop photo management (Immich)
- [ ] Stop utility services (Portainer, Filebrowser)
- [ ] Stop network services (Gluetun, proxy)
- [ ] Stop Docker daemon
- [ ] Stop system services (Tailscale, Checkmk agents)

## Data and Configuration Cleanup
- [ ] Remove Docker volumes (or archive for backup)
- [ ] Clean up /home directory (move configs if needed)
- [ ] Archive /var logs to backup storage
- [ ] Unmount NFS shares
- [ ] Remove cron jobs and scheduled tasks
- [ ] Clean up user accounts and SSH keys

## Monitoring and Management
- [ ] Remove server from Checkmk monitoring
- [ ] Update inventory systems (IPAM, asset management)
- [ ] Remove from backup schedules
- [ ] Update network documentation
- [ ] Remove from alerting groups

## Network and Security
- [ ] Remove firewall rules referencing 10.10.10.7
- [ ] Update VPN configurations if applicable
- [ ] Remove DNS entries for bookworm.ratlm.com or other hostnames
- [ ] Revoke certificates if server-specific
- [ ] Update access control lists

## Final Shutdown
- [ ] Verify no active connections: `netstat -tlnp | grep LISTEN`
- [ ] Check for running processes: `ps aux | grep -v systemd`
- [ ] Unmount all filesystems
- [ ] Power off server: `shutdown -h now`
- [ ] Physically disconnect network cables
- [ ] Label server for disposal/recycling

## Post-Decommissioning
- [ ] Monitor for any missed dependencies (24-48 hours)
- [ ] Update documentation with new server details
- [ ] Archive decommissioning records
- [ ] Schedule hardware disposal if applicable
- [ ] Update capacity planning without bookworm resources

## Emergency Rollback
- [ ] Keep server powered but disconnected for 30 days
- [ ] Maintain backups for 90 days
- [ ] Document rollback procedures

## Sign-off
- [ ] Migration lead: _______________ Date: ________
- [ ] Infrastructure team: _______________ Date: ________
- [ ] Business owner: _______________ Date: ________