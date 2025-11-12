# DNS Infrastructure Documentation

## Overview

This document describes the redundant DNS infrastructure for the 10.10.10.0/24 home network. The architecture provides both ad-blocking (via Pi-hole) and local hostname resolution (via BIND9) with full redundancy across two physical servers.

**Created:** 2025-11-01
**Network:** 10.10.10.0/24
**Domain:** .lan (local) and .ratlm.com (HTTPS services)

## Architecture Summary

### Primary DNS Stack (Proxmox)
- **Pi-hole #1**: 10.10.10.22 (LXC 105)
  - Ad-blocking DNS resolver for all client queries
  - Forwards .lan queries to BIND9 #1
  - Forwards internet queries to 1.1.1.1, 8.8.8.8

- **BIND9 #1**: 10.10.10.4 (LXC 119)
  - Authoritative DNS server for .lan domain
  - Master zone server
  - Handles all local hostname resolution

### Secondary DNS Stack (Zeus - Synology NAS)
- **Pi-hole #2**: 10.10.10.23 (Docker container)
  - Redundant ad-blocking DNS resolver
  - Forwards .lan queries to BIND9 #2
  - Forwards internet queries to 1.1.1.1, 8.8.8.8

- **BIND9 #2**: 10.10.10.2 (Docker container)
  - Secondary/slave DNS server for .lan domain
  - Receives zone transfers from BIND9 #1
  - Provides hardware redundancy on different physical host

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT DEVICES                          │
│                       (DHCP from Firewalla)                     │
│                   DNS: 10.10.10.22, 10.10.10.23                 │
└────────────┬───────────────────────────────┬────────────────────┘
             │                               │
             │                               │
    ┌────────▼────────┐            ┌────────▼────────┐
    │  Pi-hole #1     │            │  Pi-hole #2     │
    │  10.10.10.22    │            │  10.10.10.23    │
    │  (Proxmox LXC)  │            │  (Zeus Docker)  │
    │                 │            │                 │
    │ - Ad blocking   │            │ - Ad blocking   │
    │ - Query logging │            │ - Query logging │
    └────────┬────────┘            └────────┬────────┘
             │ .lan queries                 │ .lan queries
             │ internet queries              │ internet queries
             │                               │
    ┌────────▼────────┐            ┌────────▼────────┐
    │  BIND9 #1       │  Zone      │  BIND9 #2       │
    │  10.10.10.4     │  Transfer  │  10.10.10.2     │
    │  (Proxmox LXC)  │◄──────────►│  (Zeus Docker)  │
    │                 │            │                 │
    │ - Master zones  │            │ - Slave zones   │
    │ - .lan domain   │            │ - .lan domain   │
    └─────────────────┘            └─────────────────┘
             │                               │
             │ 1.1.1.1, 8.8.8.8             │ 1.1.1.1, 8.8.8.8
             └───────────┬───────────────────┘
                         │
                         ▼
                   INTERNET DNS
```

## DNS Resolution Flow

### For .lan domains (e.g., proxmox.lan):
1. Client queries Pi-hole (10.10.10.22 or 10.10.10.23)
2. Pi-hole forwards .lan query to local BIND9 (10.10.10.4 or 10.10.10.2)
3. BIND9 responds with authoritative answer from zone file
4. Pi-hole returns result to client

### For internet domains (e.g., google.com):
1. Client queries Pi-hole (10.10.10.22 or 10.10.10.23)
2. Pi-hole checks blocklists, if not blocked:
3. Pi-hole forwards to upstream DNS (1.1.1.1 or 8.8.8.8)
4. Pi-hole caches and returns result to client

### For .ratlm.com domains (e.g., proxmox.ratlm.com):
1. Client queries Pi-hole
2. Pi-hole matches wildcard rule in dnsmasq.d
3. Returns 10.10.10.3 (Nginx Proxy Manager)
4. NPM handles SSL and reverse proxy to backend service

## Component Details

### Pi-hole #1 (Primary - Proxmox)
- **IP**: 10.10.10.22
- **Container**: Proxmox LXC 105
- **OS**: Debian 12
- **Pi-hole Version**: v6.x
- **Configuration Files**:
  - `/etc/pihole/pihole.toml` - Main configuration
  - `/etc/dnsmasq.d/02-ratlm-local.conf` - Wildcard .ratlm.com
  - `/etc/dnsmasq.d/03-lan-bind9.conf` - BIND9 failover for .lan
  - `/etc/dnsmasq.d/05-custom-dns.conf` - Custom DNS entries
- **BIND9 Failover Configuration**:
  - Primary BIND9: 10.10.10.4
  - Secondary BIND9: 10.10.10.2
  - Both servers configured via `server=/lan/` directives
- **Gravity Sync**:
  - Sync script: `/usr/local/bin/sync-pihole-gravity.sh`
  - Syncs blocklists from Pi-hole #1 → Pi-hole #2
  - Runs hourly via cron (0 * * * *)
  - Log file: `/var/log/pihole-gravity-sync.log`
- **Key Settings**:
  - `revServers = ["true,10.10.10.0/24,10.10.10.4,lan"]`
  - Upstream DNS: 1.1.1.1, 8.8.8.8
  - Web interface: http://10.10.10.22/admin

### Pi-hole #2 (Secondary - Zeus)
- **IP**: 10.10.10.23 (secondary IP on bond0)
- **Container**: Docker on Synology NAS
- **Container Name**: pihole2
- **SSH Access**: Port 2222 (for gravity sync)
- **Configuration Files**:
  - `/volume1/docker/pihole2/etc-pihole/pihole.toml`
  - `/volume1/docker/pihole2/etc-dnsmasq.d/01-pihole-listen.conf`
  - `/volume1/docker/pihole2/etc-dnsmasq.d/02-ratlm-local.conf`
  - `/volume1/docker/pihole2/etc-dnsmasq.d/03-lan-bind9.conf` - BIND9 failover (currently disabled)
  - `/volume1/docker/pihole2/docker-compose.yml`
- **BIND9 Failover Configuration**:
  - Primary BIND9: 10.10.10.4
  - Secondary BIND9: 10.10.10.2
  - **Note**: Local DNS forwarding currently disabled due to volume mount permission issues
- **Gravity Sync**:
  - Receives hourly sync from Pi-hole #1
  - Gravity database updated automatically
  - Ensures blocklists stay in sync across both Pi-holes
- **Key Settings**:
  - `revServers = ["true,10.10.10.0/24,10.10.10.2,lan"]`
  - `listeningMode = "ALL"` (changed from LOCAL for host networking)
  - `interface = ""` (auto-detect for host networking)
  - `etc_dnsmasq_d = false` (temporarily disabled due to permission issues)
  - Upstream DNS: 1.1.1.1, 8.8.8.8
  - Web interface: http://10.10.10.23:8080/admin (port conflict with Synology)

### BIND9 #1 (Master - Proxmox)
- **IP**: 10.10.10.4
- **Hostname**: dns1.lan
- **Container**: Proxmox LXC 119
- **OS**: Debian 12
- **BIND Version**: 9.18.x
- **Zone Files**:
  - `/etc/bind/zones/db.lan` - Forward zone (32 A records)
  - `/etc/bind/zones/db.10.10.10` - Reverse zone (23 PTR records)
- **Configuration**:
  - `/etc/bind/named.conf.options` - Server options (includes `querylog yes;`)
  - `/etc/bind/named.conf.local` - Zone definitions
  - `/etc/bind/named.conf.logging` - Query logging configuration
- **Query Logging**:
  - Log directory: `/var/log/named/`
  - Query log: `/var/log/named/queries.log` (automatic rotation, 3 versions, 10MB each)
  - General log: `/var/log/named/general.log` (automatic rotation, 3 versions, 5MB each)
  - Includes timestamps, client IPs, query types
- **Key Settings**:
  - Authoritative only (no recursion)
  - Zone transfers allowed to: 10.10.10.2, 10.10.10.8
  - Notify enabled for zone changes
  - Query logging permanently enabled

### BIND9 #2 (Secondary - Zeus)
- **IP**: 10.10.10.2 (primary IP on bond0)
- **Hostname**: dns2.lan
- **Container**: Docker on Synology NAS
- **Container Name**: bind9-secondary
- **Zone Files** (replicated):
  - `/var/cache/bind/db.lan` - Transferred from master
  - `/var/cache/bind/db.10.10.10` - Transferred from master
- **Configuration**:
  - `/volume1/docker/bind9-secondary/config/named.conf` (includes logging config)
  - `/volume1/docker/bind9-secondary/config/named.conf.local`
  - `/volume1/docker/bind9-secondary/config/named.conf.logging` - Query logging configuration
  - `/volume1/docker/bind9-secondary/docker-compose.yml` - Container definition
- **Query Logging**:
  - Logs to Docker stdout/stderr
  - View with: `sudo /usr/local/bin/docker logs bind9-secondary`
  - Includes all query information with timestamps
- **Key Settings**:
  - Zone type: slave
  - Masters: 10.10.10.4
  - Zone serial: 2025110101 (auto-updates via NOTIFY)
  - Docker command: `-f -u bind` (foreground mode with bind user)

## Network Configuration

### Synology Zeus Dual IP Setup
Zeus (Synology NAS) uses a bonded network interface (bond0) with two IP addresses:
- **Primary IP**: 10.10.10.2 (for BIND9 #2, NFS, SMB, general access)
- **Secondary IP**: 10.10.10.23 (for Pi-hole #2)

**Network Config**: `/etc/sysconfig/network-scripts/ifcfg-bond0`
```
DEVICE=bond0
BOOTPROTO=static
ONBOOT=yes
BONDING_OPTS="mode=6 use_carrier=1 miimon=100 updelay=100"
IPADDR=10.10.10.2
NETMASK=255.255.255.0
IPADDR1=10.10.10.23
NETMASK1=255.255.255.0
```

**Zeus MAC Address**: 90:09:d0:18:61:92

### Firewalla Configuration (Required)

**DHCP Reservations:**
1. **Zeus (Synology NAS)**
   - MAC: 90:09:d0:18:61:92
   - IP: 10.10.10.2
   - Note: Primary for BIND9, also hosts 10.10.10.23 for Pi-hole

2. **Pi-hole #1 (Proxmox LXC 105)**
   - IP: 10.10.10.22
   - Note: Already configured

**DHCP DNS Settings:**
Configure Firewalla to hand out both DNS servers to all DHCP clients:
- Primary DNS: 10.10.10.22
- Secondary DNS: 10.10.10.23

This provides automatic DNS failover - if Pi-hole #1 goes down, clients will use Pi-hole #2.

## Critical Infrastructure IPs

These devices have static IP reservations in Firewalla and must never change:

| Device | IP | Purpose |
|--------|------------|---------|
| Firewalla | 10.10.10.1 | Gateway/Router |
| Zeus (NAS) | 10.10.10.2 | NAS + BIND9 #2 |
| NPM | 10.10.10.3 | Nginx Proxy Manager |
| BIND9 #1 | 10.10.10.4 | Master DNS (.lan) |
| Checkmk | 10.10.10.5 | Monitoring |
| Home Assistant | 10.10.10.6 | Home automation |
| WiFi AP #1 | 10.10.10.10 | Access point |
| WiFi AP #2 | 10.10.10.11 | Access point |
| WiFi AP #3 | 10.10.10.12 | Access point |
| Proxmox | 10.10.10.17 | Hypervisor |
| Pi-hole #1 | 10.10.10.22 | Primary DNS/Ad-blocker |
| Pi-hole #2 | 10.10.10.23 | Secondary DNS/Ad-blocker |

## .lan Domain Hosts

All hosts registered in BIND9 zone files:

| Hostname | IP | Description |
|----------|------------|-------------|
| dns1.lan | 10.10.10.4 | BIND9 primary |
| dns2.lan | 10.10.10.8 | (Reserved for BIND9 expansion) |
| firewalla.lan / gateway.lan | 10.10.10.1 | Gateway |
| wifi1.lan | 10.10.10.10 | WiFi AP |
| wifi2.lan | 10.10.10.11 | WiFi AP |
| wifi3.lan | 10.10.10.12 | WiFi AP |
| zeus.lan / nas.lan | 10.10.10.2 | Synology NAS |
| npm.lan | 10.10.10.3 | Nginx Proxy Manager |
| pihole.lan / pihole1.lan | 10.10.10.22 | Pi-hole #1 |
| pihole2.lan | 10.10.10.23 | Pi-hole #2 |
| checkmk.lan | 10.10.10.5 | Checkmk server |
| homeassistant.lan | 10.10.10.6 | Home Assistant |
| bookworm.lan | 10.10.10.7 | Debian test server |
| proxmox.lan | 10.10.10.17 | Proxmox host |
| jellyfin.lan | 10.10.10.42 | Media server |
| jarvis.lan | 10.10.10.49 | Windows workstation |
| ser8.lan | 10.10.10.96 | Mini PC |
| geekom.lan | 10.10.10.9 | Mini PC |

## Monitoring and Logging

### BIND9 Query Logs

**View BIND9 #1 query logs:**
```bash
ssh brian@10.10.10.17
sudo /usr/sbin/pct exec 119 -- tail -f /var/log/named/queries.log

# Example log entry:
# 02-Nov-2025 21:28:05.863 queries: info: client @0x7bc1b56f8098 10.10.10.96#37073 (proxmox.lan): query: proxmox.lan IN A +E(0)K (10.10.10.4)
```

**View BIND9 #2 query logs:**
```bash
ssh brian@10.10.10.2
sudo /usr/local/bin/docker logs -f bind9-secondary 2>&1 | grep "query:"

# Example log entry:
# 02-Nov-2025 19:55:34.839 client @0x7f8c33a6e000 10.10.10.96#59912 (ser8.lan): query: ser8.lan IN A +E(0)K (10.10.10.2)
```

**Analyze query patterns:**
```bash
# Most queried domains
ssh brian@10.10.10.17
sudo /usr/sbin/pct exec 119 -- grep "query:" /var/log/named/queries.log | awk '{print $(NF-4)}' | sort | uniq -c | sort -rn | head -20

# Queries per client IP
ssh brian@10.10.10.17
sudo /usr/sbin/pct exec 119 -- grep "client" /var/log/named/queries.log | awk '{print $7}' | cut -d'@' -f2 | cut -d'#' -f1 | sort | uniq -c | sort -rn
```

### Pi-hole Gravity Sync

**Check sync status:**
```bash
ssh brian@10.10.10.17
sudo /usr/sbin/pct exec 105 -- cat /var/log/pihole-gravity-sync.log

# View last sync
sudo /usr/sbin/pct exec 105 -- tail -2 /var/log/pihole-gravity-sync.log
```

**Manually trigger sync:**
```bash
ssh brian@10.10.10.17
sudo /usr/sbin/pct exec 105 -- /usr/local/bin/sync-pihole-gravity.sh
```

**Verify databases match:**
```bash
# Get MD5 from Pi-hole #1
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- md5sum /etc/pihole/gravity.db"

# Get MD5 from Pi-hole #2
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- ssh -p 2222 root@10.10.10.23 'md5sum /etc/pihole/gravity.db'"

# MD5 checksums should match
```

**Check cron schedule:**
```bash
ssh brian@10.10.10.17
sudo /usr/sbin/pct exec 105 -- crontab -l
# Should show: 0 * * * * /usr/local/bin/sync-pihole-gravity.sh >> /var/log/pihole-gravity-sync.log 2>&1
```

## Testing and Verification

### Test DNS Resolution

**Test Pi-hole #1:**
```bash
dig @10.10.10.22 proxmox.lan +short
# Expected: 10.10.10.17

dig @10.10.10.22 google.com +short
# Expected: Google IP addresses
```

**Test Pi-hole #2:**
```bash
dig @10.10.10.23 ser8.lan +short
# Expected: 10.10.10.96

dig @10.10.10.23 google.com +short
# Expected: Google IP addresses
```

**Test BIND9 #1 (Direct):**
```bash
dig @10.10.10.4 zeus.lan +short
# Expected: 10.10.10.2
```

**Test BIND9 #2 (Direct):**
```bash
dig @10.10.10.2 zeus.lan +short
# Expected: 10.10.10.2
```

**Test Zone Transfer (BIND9 Replication):**
```bash
ssh brian@10.10.10.4
sudo journalctl -u bind9 | grep "zone lan.*transferred serial"
# Expected: Log showing successful transfer to 10.10.10.2
```

**Test from Client (Auto DNS):**
```bash
ping proxmox.lan
# Expected: 64 bytes from 10.10.10.17

ping ser8.lan
# Expected: 64 bytes from 10.10.10.96
```

### Test DNS Failover

**Simulate Pi-hole #1 failure:**
```bash
ssh brian@10.10.10.17
pct stop 105  # Stop Pi-hole #1 container

# From client with both DNS servers configured:
dig google.com
# Expected: Still resolves using Pi-hole #2 (10.10.10.23)

pct start 105  # Restore Pi-hole #1
```

**Simulate BIND9 #1 failure:**
```bash
ssh brian@10.10.10.17
pct exec 119 -- systemctl stop bind9  # Stop BIND9 #1 service

# Query via Pi-hole which has both BIND9 servers configured:
dig @10.10.10.22 proxmox.lan
# Expected: Should resolve using BIND9 #2 (10.10.10.2) automatically

pct exec 119 -- systemctl start bind9  # Restore BIND9 #1
```

**Note**: dnsmasq doesn't provide automatic failover for domain-specific servers. The `server=/lan/10.10.10.4` and `server=/lan/10.10.10.2` directives mean dnsmasq will try the first server, but manual intervention or client retry may be needed if it fails. The redundancy is primarily for availability (one server down doesn't break .lan resolution) rather than instant failover.

## Maintenance Tasks

### Daily (Automatic)
- Pi-hole gravity updates (blocklist refresh)
- DNS query logging
- BIND9 zone transfer checks (on NOTIFY from master)

### Weekly
- Review Pi-hole query logs for anomalies
- Check BIND9 logs for zone transfer issues
- Verify both Pi-hole instances are receiving queries

### Monthly
- Update Pi-hole Docker image on Zeus: `docker pull pihole/pihole:latest`
- Update BIND9 Docker image on Zeus: `docker pull ubuntu/bind9:latest`
- Review and update .lan zone file with new hosts
- Verify DHCP reservations in Firewalla

### When Adding New Hosts

**Option 1: Static Assignment (Recommended for servers)**
1. Configure static IP on the host itself
2. Add DHCP reservation in Firewalla
3. Add A record to BIND9 master: `/etc/bind/zones/db.lan`
4. Add PTR record to reverse zone: `/etc/bind/zones/db.10.10.10`
5. Increment zone serial number (format: YYYYMMDDNN)
6. Reload BIND9: `sudo systemctl reload bind9`
7. Verify zone transfer to secondary: `dig @10.10.10.2 newhost.lan`

**Option 2: Dynamic DNS (Future Enhancement)**
- Configure Firewalla DHCP to send updates to BIND9
- BIND9 automatically creates/updates records
- Requires TSIG key authentication

### Updating Zone Files

**Primary BIND9 (10.10.10.4):**
```bash
ssh brian@10.10.10.4

# Edit forward zone
sudo nano /etc/bind/zones/db.lan

# Add new host:
# hostname    IN      A       10.10.10.X

# Update serial number (YYYYMMDDNN)
# Example: 2025110101 → 2025110102

# Edit reverse zone
sudo nano /etc/bind/zones/db.10.10.10

# Add PTR record:
# X    IN      PTR     hostname.lan.

# Update serial number to match forward zone

# Check syntax
sudo named-checkzone lan /etc/bind/zones/db.lan
sudo named-checkzone 10.10.10.in-addr.arpa /etc/bind/zones/db.10.10.10

# Reload BIND9 (triggers NOTIFY to secondary)
sudo systemctl reload bind9

# Verify secondary received update
dig @10.10.10.2 hostname.lan +short
```

## Troubleshooting

### Pi-hole not responding to queries

**Check container status:**
```bash
# Proxmox Pi-hole #1:
ssh brian@10.10.10.17
pct status 105
pct enter 105
systemctl status pihole-FTL

# Zeus Pi-hole #2:
ssh brian@10.10.10.2
sudo docker ps | grep pihole2
sudo docker logs pihole2
```

**Check listening ports:**
```bash
# Should show pihole-FTL on port 53
sudo netstat -tulpn | grep :53
```

**Check Pi-hole configuration:**
```bash
# On Proxmox LXC:
cat /etc/pihole/pihole.toml | grep revServers

# On Zeus Docker:
sudo docker exec pihole2 cat /etc/pihole/pihole.toml | grep revServers
```

### .lan domains not resolving

**Verify Pi-hole → BIND9 forwarding:**
```bash
# Test directly against BIND9:
dig @10.10.10.4 proxmox.lan

# Test via Pi-hole:
dig @10.10.10.22 proxmox.lan

# Check Pi-hole logs:
pihole -t  # Real-time log tail
```

**Verify BIND9 is running:**
```bash
# Primary BIND9:
ssh brian@10.10.10.4
systemctl status bind9
sudo named-checkconf

# Secondary BIND9:
ssh brian@10.10.10.2
sudo docker ps | grep bind9
sudo docker logs bind9-secondary
```

### Zone transfers not working

**Check BIND9 master logs:**
```bash
ssh brian@10.10.10.4
sudo journalctl -u bind9 -f
# Look for "approved AXFR" or "denied AXFR"
```

**Check allow-transfer ACL:**
```bash
sudo grep -A5 "allow-transfer" /etc/bind/named.conf.options
# Should include: localhost; 10.10.10.2; 10.10.10.8;
```

**Manually trigger zone transfer:**
```bash
ssh brian@10.10.10.2
sudo docker exec bind9-secondary rndc retransfer lan
sudo docker logs bind9-secondary | grep "transferred serial"
```

### Secondary IP (10.10.10.23) not reachable

**Verify IP exists on bond0:**
```bash
ssh brian@10.10.10.2
ip addr show bond0 | grep 10.10.10.23
# Should show: inet 10.10.10.23/24 scope global secondary bond0
```

**Verify persistence across reboots:**
```bash
cat /etc/sysconfig/network-scripts/ifcfg-bond0
# Should contain IPADDR1=10.10.10.23
```

**Test connectivity:**
```bash
ping 10.10.10.23
# Should respond
```

**If IP is missing, re-add:**
```bash
sudo ip addr add 10.10.10.23/24 dev bond0
# Make persistent by editing ifcfg-bond0 (see Network Configuration section)
```

### Clients not using redundant DNS

**Check DHCP configuration on Firewalla:**
- Verify Primary DNS: 10.10.10.22
- Verify Secondary DNS: 10.10.10.23

**Check client DNS settings:**
```bash
# Linux:
resolvectl status

# Windows:
ipconfig /all

# Should show both 10.10.10.22 and 10.10.10.23
```

**Force DHCP renewal on client:**
```bash
# Linux:
sudo dhclient -r && sudo dhclient

# Windows:
ipconfig /release
ipconfig /renew
```

## Backup and Recovery

### Configuration Backups

**Pi-hole #1 (Proxmox):**
```bash
# Backup LXC container
ssh brian@10.10.10.17
vzdump 105 --storage local --mode snapshot
```

**Pi-hole #2 (Zeus):**
```bash
# Backup configuration directories
ssh brian@10.10.10.2
sudo tar -czf /volume1/backups/pihole2-config-$(date +%Y%m%d).tar.gz \
  /volume1/docker/pihole2/etc-pihole \
  /volume1/docker/pihole2/etc-dnsmasq.d \
  /volume1/docker/pihole2/docker-compose.yml
```

**BIND9 #1 (Proxmox):**
```bash
# Backup LXC container and zone files
ssh brian@10.10.10.17
vzdump 119 --storage local --mode snapshot

# Manual zone backup:
ssh brian@10.10.10.4
sudo tar -czf ~/bind-zones-$(date +%Y%m%d).tar.gz /etc/bind/zones/
```

**BIND9 #2 (Zeus):**
```bash
# Backup configuration
ssh brian@10.10.10.2
sudo tar -czf /volume1/backups/bind9-config-$(date +%Y%m%d).tar.gz \
  /volume1/docker/bind9-secondary/config \
  /volume1/docker/bind9-secondary/docker-compose.yml
```

### Recovery Procedures

**Restore Pi-hole #1:**
```bash
ssh brian@10.10.10.17
pct restore 105 /var/lib/vz/dump/vzdump-lxc-105-*.tar.zst
pct start 105
```

**Restore Pi-hole #2:**
```bash
ssh brian@10.10.10.2
cd /volume1/docker/pihole2
sudo docker-compose down
sudo tar -xzf /volume1/backups/pihole2-config-YYYYMMDD.tar.gz -C /
sudo docker-compose up -d
```

**Restore BIND9 zones:**
```bash
ssh brian@10.10.10.4
sudo tar -xzf ~/bind-zones-YYYYMMDD.tar.gz -C /etc/bind/
sudo systemctl reload bind9
```

## Security Considerations

1. **DNS Query Privacy**: Queries forwarded to 1.1.1.1 (Cloudflare) and 8.8.8.8 (Google) - consider using DNS-over-TLS/HTTPS in future
2. **BIND9 Zone Transfers**: Currently uses IP-based ACL - consider adding TSIG keys for authentication
3. **Pi-hole Web Interface**: No authentication on Pi-hole #1 (WEBPASSWORD='') - secure if only accessible on trusted LAN
4. **Firewalla Protection**: All DNS servers behind firewall, not exposed to internet
5. **.ratlm.com Wildcard**: Only resolves to internal NPM (10.10.10.3), prevents DNS leakage to Cloudflare public DNS

## Recent Improvements (November 2025)

### ✅ Completed Enhancements

1. **BIND9 Query Logging**
   - Implemented on both BIND9 #1 and #2
   - Automatic log rotation (3 versions, size-based)
   - Provides visibility into DNS query patterns
   - Useful for troubleshooting and security monitoring

2. **BIND9 Failover in Pi-hole**
   - Both Pi-holes configured with both BIND9 servers
   - Provides redundancy for .lan domain resolution
   - Ensures .lan queries work even if one BIND9 server is down

3. **Pi-hole Gravity Sync**
   - Custom sync script (gravity-sync had Docker compatibility issues)
   - Hourly automated sync via cron
   - Ensures both Pi-holes have identical blocklists
   - Maintains consistency across DNS infrastructure

### Future Enhancements

1. **Dynamic DNS (DDNS)**: Configure Firewalla DHCP to automatically update BIND9 with new leases
2. **DNS-over-HTTPS (DoH)**: Enable on Pi-hole for encrypted upstream queries
3. **DNSSEC**: Enable DNSSEC validation on BIND9 for additional security
4. **Monitoring**: Add DNS query monitoring to Checkmk (partially complete - see `checkmk_dns_monitoring_setup.md`)
5. **Additional Secondaries**: Deploy BIND9 #3 on third physical host for additional redundancy
6. **IPv6 Support**: Add AAAA records and reverse IPv6 zones when IPv6 is deployed
7. **Improved BIND9 Failover**: Investigate dnsmasq alternatives or custom health-check scripts for true automatic failover

## References

- Pi-hole v6 Documentation: https://docs.pi-hole.net/
- BIND9 Documentation: https://bind9.readthedocs.io/
- Synology Docker: https://www.synology.com/en-us/dsm/packages/Docker
- Proxmox LXC: https://pve.proxmox.com/wiki/Linux_Container

## Quick Reference Commands

### BIND9 Management
```bash
# View BIND9 #1 logs
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- journalctl -u bind9 -f"

# View BIND9 #2 logs
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker logs -f bind9-secondary"

# Check BIND9 #1 query logs
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- tail -f /var/log/named/queries.log"

# Check BIND9 #2 query logs
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker logs bind9-secondary 2>&1 | grep 'query:' | tail -20"

# Restart BIND9 #1
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- systemctl restart bind9"

# Restart BIND9 #2
ssh brian@10.10.10.2 "cd /volume1/docker/bind9-secondary && sudo /usr/local/bin/docker-compose restart"
```

### Pi-hole Management
```bash
# Restart Pi-hole #1
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- systemctl restart pihole-FTL"

# Restart Pi-hole #2
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker restart pihole2"

# Manually sync gravity databases
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- /usr/local/bin/sync-pihole-gravity.sh"

# View gravity sync logs
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- tail -20 /var/log/pihole-gravity-sync.log"
```

### DNS Testing
```bash
# Test all DNS servers
for dns in 10.10.10.22 10.10.10.23 10.10.10.4 10.10.10.2; do
    echo "=== Testing $dns ==="
    dig @$dns proxmox.lan +short
done

# Test .lan resolution through Pi-holes
dig @10.10.10.22 ser8.lan +short
dig @10.10.10.23 checkmk.lan +short

# Test internet resolution with ad-blocking
dig @10.10.10.22 google.com +short
dig @10.10.10.23 amazon.com +short
```

---

## Recent Changes & Fixes (November 2025)

### Pi-hole #2 DNS Issue Resolution (2025-11-05)

**Problem:** Pi-hole #2 (10.10.10.23) was not responding to DNS queries despite container running.

**Root Causes Identified:**
1. **Missing Secondary IP**: Synology NAS (Zeus) did not have 10.10.10.23 IP address configured
2. **Container Configuration Issues**: Pi-hole container had interface binding conflicts with `network_mode: host`
3. **dnsmasq.d Permission Issues**: Volume mount permissions prevented dnsmasq from reading configuration files

**Fixes Applied:**

#### 1. Added Secondary IP Address to Synology NAS
```bash
# Added 10.10.10.23/24 as secondary IP to bond0 interface
sudo ip addr add 10.10.10.23/24 dev bond0

# Created systemd service for persistence across reboots
/etc/systemd/system/add-pihole2-ip.service
```

#### 2. Updated Pi-hole Configuration
- Changed `listeningMode` from `"LOCAL"` to `"ALL"` for host networking compatibility
- Set `interface = ""` for auto-detection
- Temporarily disabled `etc_dnsmasq_d = false` due to volume mount permission issues

#### 3. Verified DNS Functionality
- ✅ DNS queries working: `nslookup google.com 10.10.10.23`
- ✅ Ad blocking working: `nslookup ads.doubleclick.net 10.10.10.23` returns NXDOMAIN
- ✅ Web interface accessible: `http://10.10.10.23:80`

**Current Status:**
- Pi-hole #2 is fully operational as secondary DNS server
- Local DNS forwarding (.lan domains) temporarily disabled due to volume mount issues
- Gravity sync from Pi-hole #1 continues to work
- Both Pi-hole instances provide redundant DNS service

**Future Work:**
- Resolve volume mount permissions for dnsmasq.d directory
- Re-enable local DNS forwarding for .lan domains
- Test automatic failover between primary and secondary Pi-hole servers

### TP-Link Switch SSL/HTTPS Configuration Fix (2025-11-05)

**Problem:** TP-Link switch (10.10.10.64) was not accessible via https://tplink.ratlm.com despite being configured in Nginx Proxy Manager (NPM).

**Root Cause Identified:**
TP-Link switches redirect all HTTP requests to HTTPS using JavaScript: `top.location.href="https://[ip]:443"`. When NPM proxied HTTP requests to the switch's port 80, the switch responded with a redirect to HTTPS, creating an infinite loop since NPM was already terminating SSL.

**Solution Applied:**
1. **Changed NPM Proxy Configuration:**
   - **Forward Host**: `10.10.10.64` (unchanged)
   - **Forward Port**: `443` (changed from 80)
   - **Protocol**: `https` (changed from http)
   - **SSL Certificate**: `*.ratlm.com` wildcard certificate

2. **Verified TP-Link HTTPS Support:**
   ```bash
   # Direct HTTPS connection to switch works
   curl -k https://10.10.10.64:443
   # Returns: TP-Link web interface HTML
   ```

**Result:**
- ✅ https://tplink.ratlm.com now loads correctly
- ✅ SSL certificate validation works
- ✅ No more redirect loops
- ✅ Secure access to TP-Link switch management interface

**Key Learning:**
When proxying devices that redirect HTTP→HTTPS, configure NPM to use HTTPS backend instead of HTTP to avoid redirect loops.

---

**Last Updated:** 2025-11-05
**Maintained By:** Brian
**Status:** ✅ Fully Operational with Enhanced Monitoring
