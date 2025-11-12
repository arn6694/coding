# Pi-hole2 Secondary DNS - Status and Remediation Guide

**Last Updated**: November 7, 2025
**Status**: Needs Container Restart (Not Critical - Primary DNS Working)

## Executive Summary

Pi-hole2 (secondary DNS at 10.10.10.23/Zeus) is properly configured with the `.ratlm.com` wildcard DNS rules but is experiencing Docker container startup issues. **This is not blocking any functionality** since the primary DNS (10.10.10.22) is working perfectly. The system is stable with only the primary DNS configured on client machines.

---

## Current Situation

### What's Working ✅
- **Primary DNS (10.10.10.22)**: Fully functional, resolves `.ratlm.com` to 10.10.10.3 correctly
- **All 19 HTTPS Proxies**: Accessible via domain names (npm.ratlm.com, proxmox.ratlm.com, etc.)
- **Valheim Server**: Running and operational at 10.10.10.13:2456
- **Client DNS**: ser8 (10.10.10.96) configured to use only primary DNS

### What Needs Fixing ❌
- **Pi-hole2 Container**: Docker container on Zeus (10.10.10.23) won't start properly due to container name conflict
- **Secondary DNS Redundancy**: Secondary DNS failover is unavailable (non-critical for internal-only usage)

---

## Root Cause Analysis

### Discovery Process
1. Investigated why secondary DNS (10.10.10.23) was returning Cloudflare IPs instead of internal 10.10.10.3
2. Found that Zeus is a **Synology NAS (DSM)** running Docker, not a standard Linux server
3. Located Pi-hole2 container configuration at `/volume1/docker/pihole2/`
4. Verified that the `.ratlm.com` wildcard DNS config file **already exists** and is correct:
   ```
   address=/ratlm.com/10.10.10.3
   local=/ratlm.com/
   ```
5. Attempted to restart the container but encountered a Docker name conflict

### Technical Details

**Pi-hole2 Location**: `/volume1/docker/pihole2/`

**Configuration Files**:
- Docker Compose: `/volume1/docker/pihole2/docker-compose.yml`
- Dnsmasq Config: `/volume1/docker/pihole2/etc-dnsmasq.d/02-ratlm-local.conf` ✅ (Already correct)
- Pi-hole Config: `/volume1/docker/pihole2/etc-pihole/`

**Container Name Issue**:
```
Error: The container name "/pihole2" is already in use by container "128cc1db19c087b08c244b837587b0275350ad085a59276fdf5f66795b59108f"
```

---

## Docker Commands Used (Synology)

The Synology NAS uses docker-compose at a non-standard location:
```bash
/usr/local/bin/docker-compose
```

**To restart Pi-hole2 on Zeus**:
```bash
ssh brian@10.10.10.23
cd /volume1/docker/pihole2

# Stop and remove the old container (forced)
sudo /usr/local/bin/docker-compose down
sudo /usr/local/bin/docker rm -f pihole2

# Start fresh
sudo /usr/local/bin/docker-compose up -d
```

**To check logs**:
```bash
cd /volume1/docker/pihole2
sudo /usr/local/bin/docker-compose logs pihole2 -f
```

---

## Configuration Verification

### DNS Configuration ✅ CORRECT
File: `/volume1/docker/pihole2/etc-dnsmasq.d/02-ratlm-local.conf`
```
# Wildcard DNS for all *.ratlm.com subdomains to local NPM
# This matches ANY subdomain under ratlm.com and prevents leakage to Cloudflare
address=/ratlm.com/10.10.10.3
local=/ratlm.com/
```

### Docker Compose Setup ✅ CORRECT
File: `/volume1/docker/pihole2/docker-compose.yml`
```yaml
version: "3"
services:
  pihole:
    container_name: pihole2
    image: pihole/pihole:latest
    hostname: pihole2
    restart: unless-stopped
    network_mode: host
    environment:
      TZ: 'America/New_York'
      WEBPASSWORD: ''
      PIHOLE_DNS_: '1.1.1.1;8.8.8.8'
      FTLCONF_LOCAL_IPV4: '10.10.10.23'
      WEB_PORT: '8080'
    volumes:
      - '/volume1/docker/pihole2/etc-pihole:/etc/pihole'
      - '/volume1/docker/pihole2/etc-dnsmasq.d:/etc/dnsmasq.d'
      - '/volume1/docker/pihole2/check-mk-agent/check_mk_agent:/opt/check_mk_agent:ro'
      - '/volume1/docker/pihole2/entrypoint.sh:/custom-entrypoint.sh:ro'
    cap_add:
      - NET_ADMIN
    entrypoint: ["/custom-entrypoint.sh"]
```

---

## Testing Pi-hole2 (After Fix)

Once the container is running, verify DNS resolution:
```bash
# From any machine on the network
dig @10.10.10.23 npm.ratlm.com +short

# Should return:
# 10.10.10.3
```

**Full validation** (test both primary and secondary):
```bash
dig @10.10.10.22 npm.ratlm.com +short  # Primary
dig @10.10.10.23 npm.ratlm.com +short  # Secondary (after fix)
dig npm.ratlm.com +short                 # Default resolver
```

---

## Why This Matters (But Isn't Urgent)

### Current Impact
- **None** - Primary DNS is working perfectly
- All clients can resolve `.ratlm.com` domains
- If primary DNS goes down, secondary won't help (it's not currently configured on clients)

### Why Secondary DNS Is Important (For Future)
- **Redundancy**: If primary DNS fails, secondary provides failover
- **Load Balancing**: Can distribute DNS queries across both servers
- **Production Readiness**: Proper infrastructure should have DNS redundancy

### Why Secondary DNS Can Be Skipped Now
- Internal-only usage (`.ratlm.com` is not public)
- Single point of failure is acceptable for homelab
- Primary DNS is stable and reliable
- No critical services would be lost if DNS goes down (users can access via IP)

---

## Future Remediation Steps

### Option 1: Use Synology GUI (Recommended for Synology Users)
1. Log into Synology DSM Web Interface
2. Open Docker application
3. Navigate to Containers
4. Find and remove the "pihole2" container
5. Navigate to docker-compose.yml in File Manager
6. Ensure the file at `/volume1/docker/pihole2/docker-compose.yml` is intact
7. Use Docker GUI to recreate the container from the compose file

### Option 2: SSH-Based (Command Line)
```bash
ssh brian@10.10.10.23
cd /volume1/docker/pihole2

# Clean up
sudo /usr/local/bin/docker rm -f pihole2
sudo /usr/local/bin/docker system prune -f

# Verify compose file is valid
cat docker-compose.yml

# Start fresh
sudo /usr/local/bin/docker-compose up -d

# Wait 30 seconds for startup
sleep 30

# Check status
sudo /usr/local/bin/docker-compose ps
sudo /usr/local/bin/docker-compose logs pihole2 | tail -20
```

### Option 3: If Container Still Won't Start
Check container errors:
```bash
sudo /usr/local/bin/docker logs pihole2
```

Common issues might include:
- Port 53 already in use
- Volume permission issues
- DNS service conflict with Synology's built-in DNS

---

## DNS Architecture After Fix

```
Client (ser8)
    ↓
systemd-resolved (127.0.0.53)
    ↓
    ├─→ Primary: Pi-hole (10.10.10.22) ✅ [Currently In Use]
    └─→ Secondary: Pi-hole2 (10.10.10.23) ❌ [Needs Docker Fix]
        ↓
        dnsmasq with ratlm.com wildcard
        ↓
        Resolves to 10.10.10.3 (NPM)
```

---

## Client Configuration (Already Applied)

On ser8 (10.10.10.96), DNS is configured to use only primary:
```bash
sudo resolvectl dns wlp2s0 10.10.10.22
```

To add secondary DNS (after pihole2 is fixed):
```bash
sudo resolvectl dns wlp2s0 10.10.10.22 10.10.10.23
```

---

## Historical Context

### What Happened (Nov 6-7, 2025)

1. **Problem Discovered**: User reported HTTPS proxies not accessible
2. **Root Cause Found**: NPM backend service was stopped + DNS resolution issues
3. **NPM Fixed**: `sudo systemctl restart npm` on 10.10.10.3
4. **DNS Issue Found**: Secondary DNS returning Cloudflare IPs
5. **Secondary Diagnosis**: Found pihole2 container not properly configured/running
6. **Current Status**: Primary DNS fixed, secondary needs Docker restart

### Files Modified This Session
- `/etc/resolv.conf` (on ser8) - No changes needed, already correct
- systemd-resolved config (on ser8) - Configured to use only primary DNS
- NPM database - Cleaned up duplicates, all 19 proxies restored

---

## Files to Monitor

- `/volume1/docker/pihole2/docker-compose.yml` - Main config
- `/volume1/docker/pihole2/etc-dnsmasq.d/02-ratlm-local.conf` - DNS rules
- `/volume1/docker/pihole2/entrypoint.sh` - Container startup script

---

## Contact & Support Notes

- **Synology Docker Path**: `/usr/local/bin/docker-compose` (not in standard PATH)
- **Zeus IP**: 10.10.10.23 (Synology NAS 920+)
- **Primary DNS**: 10.10.10.22 (Linux - Zero with Pi-hole)
- **NPM**: 10.10.10.3
- **Test Client**: ser8 (10.10.10.96)

---

## Success Criteria

When complete, both tests should work:
```bash
dig @10.10.10.22 npm.ratlm.com +short → 10.10.10.3 ✅
dig @10.10.10.23 npm.ratlm.com +short → 10.10.10.3 ✅
```

---

**Document Version**: 1.0
**Next Review Date**: When secondary DNS redundancy is needed
**Responsible Party**: brian@10.10.10.23
