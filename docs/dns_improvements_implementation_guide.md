# DNS Improvements Implementation Guide

**Date:** 2025-11-02
**Improvements:** BIND9 Query Logging + BIND9 Failover + Gravity-Sync
**Estimated Time:** 40 minutes total

---

## Part 1: Add BIND9 Query Logging (10 minutes)

### Benefits
- Separate log file for DNS queries (easier troubleshooting)
- Automatic log rotation (prevents disk fill)
- Detailed query information with timestamps

---

### Step 1A: Configure BIND9 #1 (dns1 - 10.10.10.4)

**SSH into BIND9 #1:**
```bash
ssh brian@10.10.10.4
# Or via Proxmox: pct enter 119
```

**Create log directory:**
```bash
sudo mkdir -p /var/log/named
sudo chown bind:bind /var/log/named
```

**Create logging configuration file:**
```bash
sudo nano /etc/bind/named.conf.logging
```

**Add this content:**
```bind
# BIND9 Query Logging Configuration
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

**Save and exit** (Ctrl+O, Enter, Ctrl+X)

**Include logging config in main configuration:**
```bash
echo 'include "/etc/bind/named.conf.logging";' | sudo tee -a /etc/bind/named.conf
```

**Verify configuration is valid:**
```bash
sudo named-checkconf
# Should return nothing if valid
```

**Reload BIND9:**
```bash
sudo systemctl reload bind9
```

**Verify logging is working:**
```bash
# Wait a few seconds, then check the log file
sudo tail -f /var/log/named/queries.log

# In another terminal, make a test query:
dig @10.10.10.4 proxmox.lan

# You should see the query appear in the log
```

**Press Ctrl+C to exit tail**

---

### Step 1B: Configure BIND9 #2 (dns2 - 10.10.10.2 on Zeus)

**SSH into Zeus:**
```bash
ssh brian@10.10.10.2
```

**Create logging configuration file on host:**
```bash
sudo nano /volume1/docker/bind9-secondary/config/named.conf.logging
```

**Add this content:**
```bind
# BIND9 Query Logging Configuration
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

**Save and exit** (Ctrl+O, Enter, Ctrl+X)

**Update main named.conf to include logging:**
```bash
sudo nano /volume1/docker/bind9-secondary/config/named.conf
```

**Add this line at the top (after the first options block):**
```bind
include "/etc/bind/named.conf.logging";
```

**Save and exit**

**Update docker-compose to mount log directory:**
```bash
sudo nano /volume1/docker/bind9-secondary/docker-compose.yml
```

**Add this volume mount in the volumes section:**
```yaml
volumes:
  - /volume1/docker/bind9-secondary/config/named.conf:/etc/bind/named.conf:ro
  - /volume1/docker/bind9-secondary/config/named.conf.local:/etc/bind/named.conf.local:ro
  - /volume1/docker/bind9-secondary/config/named.conf.logging:/etc/bind/named.conf.logging:ro  # ADD THIS LINE
  - /volume1/docker/bind9-secondary/cache:/var/cache/bind
  - /volume1/docker/bind9-secondary/log:/var/log/named  # ADD THIS LINE
```

**Save and exit**

**Create log directory on host:**
```bash
sudo mkdir -p /volume1/docker/bind9-secondary/log
```

**Restart BIND9 #2:**
```bash
cd /volume1/docker/bind9-secondary
sudo /usr/local/bin/docker-compose restart
```

**Verify logging is working:**
```bash
# Check the log
sudo tail -f /volume1/docker/bind9-secondary/log/queries.log

# In another terminal, test query:
dig @10.10.10.2 proxmox.lan

# Should see query in log
```

---

## Part 2: Add BIND9 Failover to Pi-hole (5 minutes)

### Benefits
- If primary BIND9 (10.10.10.4) goes down, queries automatically go to secondary (10.10.10.2)
- Huge resilience improvement for .lan resolution
- Zero downtime for local hostname lookups

---

### Step 2A: Configure Pi-hole #1 (10.10.10.22)

**SSH into Pi-hole #1:**
```bash
ssh brian@10.10.10.22
```

**Edit the BIND9 forwarding config:**
```bash
sudo nano /etc/dnsmasq.d/03-lan-bind9.conf
```

**Change from:**
```bash
# Forward .lan domain queries to BIND9
server=/lan/10.10.10.4
```

**To:**
```bash
# Forward .lan domain queries to BIND9 (with failover)
server=/lan/10.10.10.4
server=/lan/10.10.10.2
```

**Save and exit** (Ctrl+O, Enter, Ctrl+X)

**Restart Pi-hole:**
```bash
sudo systemctl restart pihole-FTL
```

---

### Step 2B: Configure Pi-hole #2 (10.10.10.23 on Zeus)

**SSH into Zeus:**
```bash
ssh brian@10.10.10.2
```

**Edit the BIND9 forwarding config:**
```bash
sudo nano /volume1/docker/pihole2/etc-dnsmasq.d/03-lan-bind9.conf
```

**Change from:**
```bash
# Forward .lan domain queries to BIND9 authoritative DNS server (on Zeus)
server=/lan/10.10.10.4
```

**To:**
```bash
# Forward .lan domain queries to BIND9 (with failover)
server=/lan/10.10.10.4
server=/lan/10.10.10.2
```

**Save and exit** (Ctrl+O, Enter, Ctrl+X)

**Restart Pi-hole #2:**
```bash
cd /volume1/docker/pihole2
sudo /usr/local/bin/docker-compose restart
```

---

### Step 2C: Test BIND9 Failover

**Test normal operation (both BIND9 servers running):**
```bash
# From your workstation
dig @10.10.10.22 proxmox.lan +short
# Expected: 10.10.10.17

dig @10.10.10.23 ser8.lan +short
# Expected: 10.10.10.96
```

**Test failover (stop primary BIND9):**
```bash
# SSH to BIND9 #1
ssh brian@10.10.10.4  # Or: pct enter 119

# Stop BIND9
sudo systemctl stop bind9
```

**Now test .lan queries (should still work via BIND9 #2):**
```bash
# From your workstation
dig @10.10.10.22 proxmox.lan +short
# Expected: 10.10.10.17 (but may take 1-2 seconds on first query)

dig @10.10.10.23 zeus.lan +short
# Expected: 10.10.10.2
```

**Check Pi-hole logs to see failover:**
```bash
# On Pi-hole #1
pihole -t
# You should see queries being forwarded to 10.10.10.2 instead of 10.10.10.4
```

**Restore BIND9 #1:**
```bash
# On BIND9 #1
sudo systemctl start bind9
```

**Verify everything back to normal:**
```bash
dig @10.10.10.22 proxmox.lan +short
# Expected: 10.10.10.17 (fast again)
```

---

## Part 3: Install Gravity-Sync (30 minutes)

### Benefits
- Automatically syncs Pi-hole configuration between both instances
- Keeps blocklists, whitelists, and settings identical
- Prevents configuration drift over time

### Overview
- **Primary**: Pi-hole #1 (10.10.10.22) - Proxmox LXC
- **Secondary**: Pi-hole #2 (10.10.10.23) - Zeus Docker
- **Sync Direction**: Primary → Secondary (one-way)

---

### Step 3A: Set Up SSH Keys (Proxmox → Zeus)

**On Pi-hole #1 (10.10.10.22):**
```bash
ssh brian@10.10.10.22

# Generate SSH key (if not exists)
sudo ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""

# Copy public key to Zeus
sudo ssh-copy-id -i /root/.ssh/id_ed25519.pub brian@10.10.10.2
# Enter your password when prompted
```

**Test SSH connection:**
```bash
sudo ssh brian@10.10.10.2 "echo 'SSH key works!'"
# Expected: "SSH key works!"
```

---

### Step 3B: Install Gravity-Sync on Pi-hole #1

**Still on Pi-hole #1 (10.10.10.22):**
```bash
# Download and run installer
curl -sSL https://raw.githubusercontent.com/vmstan/gravity-sync/master/GS_INSTALL.sh | sudo bash
```

**Follow the installation prompts:**
1. Accept the license
2. Choose installation directory (default: `/usr/local/bin`)
3. Choose configuration directory (default: `/etc/gravity-sync`)

---

### Step 3C: Configure Gravity-Sync

**Create configuration file:**
```bash
sudo gravity-sync config
```

**When prompted, enter:**
- **Remote Pi-hole IP**: `10.10.10.2`
- **Remote Pi-hole user**: `brian`
- **Remote Pi-hole directory** (Docker): `/volume1/docker/pihole2/etc-pihole`
- **Sync direction**: `push` (primary → secondary)

**Or manually create the config:**
```bash
sudo nano /etc/gravity-sync/gravity-sync.conf
```

**Add this content:**
```bash
REMOTE_HOST='10.10.10.2'
REMOTE_USER='brian'
REMOTE_FILE_LOCATION='/volume1/docker/pihole2/etc-pihole'
PIHOLE_DIR='/etc/pihole'
PIHOLE_BIN='/usr/local/bin/pihole'
DOCKER_CON='pihole2'
PUSH_MODE=1
SSH_PKIF='/root/.ssh/id_ed25519'
LOG_PATH='/var/log'
VERIFY_PASS=0
```

**Save and exit**

---

### Step 3D: Initial Sync Test

**Perform a dry-run (doesn't actually sync):**
```bash
sudo gravity-sync compare
```

**Expected output:**
- Shows differences between primary and secondary
- Lists what would be synced

**Perform actual sync:**
```bash
sudo gravity-sync push
```

**Expected output:**
- Copies gravity database
- Copies custom lists
- Copies DNS records
- Restarts Pi-hole #2 to apply changes

**Verify sync worked:**
```bash
# On Pi-hole #2 (Zeus)
ssh brian@10.10.10.2
cd /volume1/docker/pihole2
sudo /usr/local/bin/docker-compose logs pihole2 | tail -20
# Should see "Reloading DNS lists" or similar
```

**Check Pi-hole #2 web interface:**
- Go to `http://10.10.10.23:8080/admin`
- Check Dashboard → Total Queries Blocked
- Should match Pi-hole #1

---

### Step 3E: Set Up Automatic Sync (Cron Job)

**Edit root's crontab on Pi-hole #1:**
```bash
sudo crontab -e
```

**Add this line to sync every hour:**
```cron
# Gravity-Sync: Sync Pi-hole config to secondary every hour
0 * * * * /usr/local/bin/gravity-sync push >/dev/null 2>&1
```

**Or sync every 6 hours (less frequent):**
```cron
# Gravity-Sync: Sync Pi-hole config to secondary every 6 hours
0 */6 * * * /usr/local/bin/gravity-sync push >/dev/null 2>&1
```

**Save and exit**

**Verify cron job is active:**
```bash
sudo crontab -l
# Should show your gravity-sync line
```

---

### Step 3F: Test Automatic Sync

**Make a change on Pi-hole #1:**
```bash
# Add a custom DNS entry
pihole -a addcustomdns example.test 192.168.1.100

# Or use web interface:
# Login → Local DNS → DNS Records → Add
# Domain: example.test
# IP: 192.168.1.100
```

**Manually trigger sync:**
```bash
sudo gravity-sync push
```

**Check Pi-hole #2:**
```bash
# Query for the new record
dig @10.10.10.23 example.test +short
# Expected: 192.168.1.100
```

**If it works, the sync is functioning correctly!**

---

## Verification Checklist

### ✅ BIND9 Logging
- [ ] `/var/log/named/queries.log` exists on BIND9 #1
- [ ] `/volume1/docker/bind9-secondary/log/queries.log` exists on Zeus
- [ ] Queries appear in logs when testing with `dig`
- [ ] Log rotation is working (check file sizes)

### ✅ BIND9 Failover
- [ ] Both Pi-holes have two `server=/lan/` lines in dnsmasq config
- [ ] `.lan` queries work when BIND9 #1 is running
- [ ] `.lan` queries work when BIND9 #1 is stopped (failover to #2)
- [ ] `.lan` queries work when BIND9 #1 is restarted

### ✅ Gravity-Sync
- [ ] SSH key authentication works from Pi-hole #1 to Zeus
- [ ] `gravity-sync compare` shows differences
- [ ] `gravity-sync push` completes without errors
- [ ] Changes on Pi-hole #1 appear on Pi-hole #2 after sync
- [ ] Cron job is scheduled for automatic sync
- [ ] Both Pi-holes show same blocklist counts

---

## Troubleshooting

### BIND9 Logging Issues

**Problem: Log files not created**
```bash
# Check directory permissions
ls -ld /var/log/named
# Should be: drwxr-xr-x bind bind

# Fix if needed:
sudo chown bind:bind /var/log/named
sudo systemctl restart bind9
```

**Problem: "permission denied" in logs**
```bash
# Check SELinux/AppArmor
sudo journalctl -u bind9 | grep -i denied

# On Debian, check AppArmor:
sudo aa-status | grep named
```

### BIND9 Failover Issues

**Problem: Queries don't fail over**
```bash
# Check dnsmasq is reading the config
sudo systemctl restart pihole-FTL

# Check Pi-hole query log
pihole -t
# Should show which server queries go to
```

**Problem: Slow failover (5+ seconds)**
- This is normal for first query after primary fails
- Subsequent queries will be fast
- Consider reducing dnsmasq timeout if needed

### Gravity-Sync Issues

**Problem: SSH authentication fails**
```bash
# Test SSH manually
sudo ssh -i /root/.ssh/id_ed25519 brian@10.10.10.2 "echo test"

# Re-copy key if needed:
sudo ssh-copy-id -i /root/.ssh/id_ed25519.pub brian@10.10.10.2
```

**Problem: "Docker container not found"**
```bash
# Verify container name in config
sudo nano /etc/gravity-sync/gravity-sync.conf
# Should have: DOCKER_CON='pihole2'

# Verify container exists on Zeus:
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker ps | grep pihole2"
```

**Problem: Sync shows "No changes"**
```bash
# This is actually good - means Pi-holes are already in sync!
# Make a test change to verify:
pihole -a addcustomdns synctest.test 1.2.3.4
sudo gravity-sync push
```

---

## Rollback Instructions

### If BIND9 Logging Causes Issues

**On BIND9 #1:**
```bash
# Remove include line from named.conf
sudo nano /etc/bind/named.conf
# Delete the line: include "/etc/bind/named.conf.logging";

# Reload
sudo systemctl reload bind9
```

**On BIND9 #2:**
```bash
# Remove include from named.conf
sudo nano /volume1/docker/bind9-secondary/config/named.conf
# Delete the include line

# Restart
cd /volume1/docker/bind9-secondary
sudo /usr/local/bin/docker-compose restart
```

### If BIND9 Failover Causes Issues

**Revert to single server:**
```bash
# On Pi-hole #1
sudo nano /etc/dnsmasq.d/03-lan-bind9.conf
# Remove the second server=/lan/10.10.10.2 line
sudo systemctl restart pihole-FTL

# On Pi-hole #2
sudo nano /volume1/docker/pihole2/etc-dnsmasq.d/03-lan-bind9.conf
# Remove the second server=/lan/10.10.10.2 line
cd /volume1/docker/pihole2
sudo /usr/local/bin/docker-compose restart
```

### If Gravity-Sync Causes Issues

**Disable automatic sync:**
```bash
sudo crontab -e
# Comment out or delete the gravity-sync line
```

**Uninstall gravity-sync:**
```bash
sudo /usr/local/bin/gravity-sync uninstall
```

---

## Post-Implementation

### Update Documentation

After successful implementation, update your DNS documentation:

```bash
nano /home/brian/claude/dns_infrastructure_documentation.md
```

Add these sections:
1. BIND9 query logging locations
2. BIND9 failover configuration
3. Gravity-sync automatic synchronization schedule

### Monitor for First 48 Hours

**Check BIND9 logs:**
```bash
# Every few hours
sudo tail -50 /var/log/named/queries.log
```

**Check gravity-sync:**
```bash
# After first automatic run
sudo grep gravity-sync /var/log/syslog
```

**Verify both Pi-holes stay in sync:**
```bash
# Compare query counts on web interfaces
# http://10.10.10.22/admin vs http://10.10.10.23:8080/admin
```

---

## Summary

**What You'll Have After Implementation:**

1. ✅ **BIND9 Query Logging**
   - Dedicated log files for DNS queries
   - Easier troubleshooting
   - Automatic log rotation

2. ✅ **BIND9 Failover**
   - Automatic failover if primary BIND9 fails
   - Zero downtime for .lan resolution
   - Improved resilience

3. ✅ **Gravity-Sync**
   - Both Pi-holes automatically stay in sync
   - No configuration drift
   - Consistent blocklists and settings

**Total improvement time:** ~40 minutes
**Long-term benefit:** Significantly more reliable DNS infrastructure

---

**Implementation Status:** ⏳ Ready to implement
**Difficulty:** Easy (well-documented, low-risk)
**Reversible:** Yes (rollback instructions provided)
