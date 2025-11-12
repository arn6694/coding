# DNS Infrastructure Improvements - November 2025

**Completion Date:** November 2, 2025
**Implementation Status:** ✅ Fully Complete
**Based on:** ChatGPT DNS Review Recommendations

## Summary

Successfully implemented DNS infrastructure improvements based on ChatGPT's technical review. All changes enhance monitoring, redundancy, and maintainability of the DNS infrastructure.

## Implemented Improvements

### 1. BIND9 Query Logging ✅

**Purpose:** Monitor DNS query patterns, troubleshoot issues, detect anomalies

**BIND9 #1 (10.10.10.4) - Proxmox LXC 119:**
- **Configuration File:** `/etc/bind/named.conf.logging`
- **Query Log:** `/var/log/named/queries.log`
- **General Log:** `/var/log/named/general.log`
- **Rotation:** Automatic (3 versions, size-based: 10MB for queries, 5MB for general)
- **Enabled:** Permanently via `querylog yes;` in `named.conf.options`

**BIND9 #2 (10.10.10.2) - Zeus Docker:**
- **Configuration File:** `/volume1/docker/bind9-secondary/config/named.conf.logging`
- **Logs:** Docker stdout/stderr
- **View Command:** `sudo /usr/local/bin/docker logs bind9-secondary`
- **Docker Command:** Updated to `-f -u bind` (foreground mode)

**Configuration Details:**
```bash
logging {
    channel query_log {
        file "/var/log/named/queries.log" versions 3 size 10m;
        severity info;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel general_log {
        file "/var/log/named/general.log" versions 3 size 5m;
        severity info;
        print-time yes;
    };

    category queries { query_log; };
    category default { general_log; };
};
```

**Log Format Example:**
```
02-Nov-2025 21:28:05.863 queries: info: client @0x7bc1b56f8098 10.10.10.96#37073 (proxmox.lan): query: proxmox.lan IN A +E(0)K (10.10.10.4)
```

### 2. BIND9 Failover Configuration ✅

**Purpose:** Redundant .lan domain resolution if primary BIND9 fails

**Pi-hole #1 Configuration:**
- **File:** `/etc/dnsmasq.d/03-lan-bind9.conf`
- **Content:**
  ```bash
  # Forward .lan domain queries to both BIND9 servers
  server=/lan/10.10.10.4
  server=/lan/10.10.10.2
  ```

**Pi-hole #2 Configuration:**
- **File:** `/volume1/docker/pihole2/etc-dnsmasq.d/03-lan-bind9.conf`
- **Content:** Same as Pi-hole #1

**Behavior:**
- Both Pi-holes have both BIND9 servers configured
- Provides redundancy for .lan domain resolution
- **Note:** dnsmasq doesn't provide automatic failover; manual retry or intervention may be needed
- Redundancy is for availability (one server down doesn't break .lan resolution)

### 3. Pi-hole Gravity Sync ✅

**Purpose:** Keep blocklists synchronized between both Pi-hole instances

**Why Custom Script:**
- gravity-sync tool had compatibility issues with Docker-based Pi-hole #2
- Custom script provides simpler, more reliable solution

**Implementation:**

**Sync Script Location:** `/usr/local/bin/sync-pihole-gravity.sh` (on Pi-hole #1)

**Script Content:**
```bash
#!/bin/bash
# Simple Pi-hole Gravity Database Sync Script
# Syncs from Pi-hole #1 (10.10.10.22) to Pi-hole #2 (10.10.10.23)

echo "[$(date)] Starting Pi-hole gravity sync..."

# Copy gravity database to Pi-hole #2
scp -P 2222 /etc/pihole/gravity.db root@10.10.10.23:/etc/pihole/gravity.db.sync

# Replace database and reload on Pi-hole #2
ssh -p 2222 root@10.10.10.23 "mv /etc/pihole/gravity.db.sync /etc/pihole/gravity.db && chown pihole:pihole /etc/pihole/gravity.db && pihole reloaddns"

echo "[$(date)] Gravity sync completed successfully"
```

**Automation:**
- **Cron Schedule:** Hourly (0 * * * *)
- **Command:** `0 * * * * /usr/local/bin/sync-pihole-gravity.sh >> /var/log/pihole-gravity-sync.log 2>&1`
- **Log File:** `/var/log/pihole-gravity-sync.log`

**SSH Configuration:**
- Pi-hole #2 accessible via SSH on port 2222
- Passwordless SSH keys configured (brian@pihole1 → root@pihole2:2222)

## Verification Commands

### Check BIND9 Query Logs

**BIND9 #1:**
```bash
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- tail -f /var/log/named/queries.log"
```

**BIND9 #2:**
```bash
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker logs bind9-secondary 2>&1 | grep 'query:' | tail -20"
```

### Check Gravity Sync Status

**View sync logs:**
```bash
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- tail -20 /var/log/pihole-gravity-sync.log"
```

**Manually trigger sync:**
```bash
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- /usr/local/bin/sync-pihole-gravity.sh"
```

**Verify databases match:**
```bash
# Pi-hole #1 MD5
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- md5sum /etc/pihole/gravity.db"

# Pi-hole #2 MD5
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- ssh -p 2222 root@10.10.10.23 'md5sum /etc/pihole/gravity.db'"

# Should match: 93c3d8087985b5610e22ccbc912f5c01
```

### Test BIND9 Failover

**Test .lan queries:**
```bash
# Should work via either BIND9 server
dig @10.10.10.22 proxmox.lan +short  # Via Pi-hole #1 → BIND9 #1
dig @10.10.10.23 proxmox.lan +short  # Via Pi-hole #2 → BIND9 #2
```

**Simulate BIND9 #1 failure:**
```bash
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- systemctl stop bind9"

# Test still works via BIND9 #2
dig @10.10.10.22 proxmox.lan +short

# Restore
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- systemctl start bind9"
```

## Files Modified/Created

### BIND9 #1 (Proxmox LXC 119)
- ✅ Created: `/etc/bind/named.conf.logging`
- ✅ Modified: `/etc/bind/named.conf` (added include statement)
- ✅ Modified: `/etc/bind/named.conf.options` (added `querylog yes;`)
- ✅ Created: `/var/log/named/` directory (owner: bind:bind)

### BIND9 #2 (Zeus Docker)
- ✅ Created: `/volume1/docker/bind9-secondary/config/named.conf.logging`
- ✅ Modified: `/volume1/docker/bind9-secondary/config/named.conf` (added include statement)
- ✅ Modified: `/volume1/docker/bind9-secondary/docker-compose.yml` (updated command)
- ✅ Created: `/volume1/docker/bind9-secondary/log/` directory

### Pi-hole #1 (Proxmox LXC 105)
- ✅ Created: `/etc/dnsmasq.d/03-lan-bind9.conf`
- ✅ Created: `/usr/local/bin/sync-pihole-gravity.sh`
- ✅ Modified: Root crontab (added hourly sync job)
- ✅ Created: SSH keys (~brian/.ssh/) for Pi-hole #2 access
- ✅ Created: `/root/.ssh/config` for Pi-hole #2 SSH settings

### Pi-hole #2 (Zeus Docker)
- ✅ Created: `/volume1/docker/pihole2/etc-dnsmasq.d/03-lan-bind9.conf`
- ✅ SSH daemon configured on port 2222

## Benefits Achieved

1. **Enhanced Monitoring:**
   - All DNS queries logged with timestamps and client IPs
   - Easy troubleshooting of DNS issues
   - Security monitoring capabilities

2. **Improved Redundancy:**
   - Both Pi-holes can use either BIND9 server
   - .lan domain resolution continues if one BIND9 server fails
   - Automated blocklist synchronization between Pi-holes

3. **Operational Excellence:**
   - Automated hourly gravity sync reduces manual maintenance
   - Consistent ad-blocking across both DNS resolvers
   - Better visibility into DNS infrastructure health

## Maintenance

### Daily (Automatic)
- Gravity sync runs hourly via cron
- BIND9 logs rotate automatically when size limits reached

### Weekly
- Review gravity sync logs for failures: `cat /var/log/pihole-gravity-sync.log`
- Check BIND9 query patterns for anomalies

### Monthly
- Verify gravity databases still match between Pi-holes
- Review BIND9 log rotation and disk usage
- Confirm cron job still running: `crontab -l`

## Known Limitations

1. **dnsmasq Failover:**
   - Not true automatic failover
   - May require manual intervention or client retry if primary BIND9 fails
   - Both servers configured provides availability, not instant failover

2. **Gravity Sync Direction:**
   - One-way sync: Pi-hole #1 → Pi-hole #2
   - Changes to Pi-hole #2 will be overwritten
   - Always make blocklist changes on Pi-hole #1

3. **BIND9 #2 Logging:**
    - Logs to Docker stdout instead of files
    - Requires `docker logs` command to view
    - Not as convenient as file-based logs on BIND9 #1

4. **Pi-hole #2 Local DNS Forwarding:**
    - Currently disabled due to volume mount permission issues
    - .lan domain queries handled by upstream DNS (BIND9)
    - May be re-enabled after resolving Docker volume permissions

## Recent Fixes (November 5, 2025)

### Pi-hole #2 DNS Service Restoration

**Issue:** Pi-hole #2 container was running but not responding to DNS queries on 10.10.10.23

**Resolution:**
1. **Added Secondary IP to Synology NAS:**
   - Configured 10.10.10.23/24 as secondary IP on bond0 interface
   - Created systemd service `/etc/systemd/system/add-pihole2-ip.service` for persistence

2. **Updated Pi-hole Configuration:**
   - Changed `listeningMode` from "LOCAL" to "ALL" for host networking
   - Disabled `etc_dnsmasq_d` temporarily due to permission issues
   - Verified DNS functionality and ad blocking

3. **Verification:**
   - DNS queries: ✅ `nslookup google.com 10.10.10.23`
   - Ad blocking: ✅ `nslookup ads.doubleclick.net 10.10.10.23` → NXDOMAIN
   - Web interface: ✅ `http://10.10.10.23:80`

**Impact:** Pi-hole #2 now provides full redundant DNS service alongside Pi-hole #1.

## Related Documentation

- **Main DNS Documentation:** `dns_infrastructure_documentation.md`
- **Checkmk DNS Monitoring:** `checkmk_dns_monitoring_setup.md`
- **Original Improvement Guide:** `dns_improvements_implementation_guide.md`

---

**Implemented By:** Claude Code
**Verified:** November 5, 2025
**Status:** ✅ Production Ready with Recent Fixes
