# Infrastructure Operations Guide

Common tasks for managing the homelab infrastructure. All operations should be performed methodically with validation checks before and after changes.

## Key Operational Patterns

### Checkmk Agent Updates

When updating agents across the infrastructure:
1. Download appropriate package (DEB/RPM) from server's agent directory
2. Use `update_checkmk_agents.sh` for bulk updates
3. Script auto-detects OS type and applies correct package
4. Verification via `cmk -d <hostname>` from monitoring server

### Adding New Services

When adding a new service to the infrastructure:
1. Deploy service on appropriate host
2. Configure in NPM with `<service>.ratlm.com` hostname
3. No Pi-hole changes needed (wildcard DNS handles it)
4. Add monitoring in Checkmk via WATO/REST API

### Managing DNS and DHCP (Preventing IP Drift)

**Problem**: Hosts using DHCP can get new IPs after reboots, breaking DNS resolution and monitoring.

**Solution**: Use DHCP reservations in Firewalla Gold + static DNS entries in BIND9.

#### Setting DHCP Reservations in Firewalla

1. Open Firewalla app → **Devices** tab
2. Find the device (e.g., jarvis)
3. Tap on device → scroll to IP allocation
4. Change from **Dynamic** to **Reserved**
5. Set desired IP address
6. Save

After setting reservation, reboot the device to get the new reserved IP.

#### Updating BIND9 DNS Records

**Access BIND9 Primary (10.10.10.4):**
```bash
# Option 1: Direct SSH (preferred)
ssh brian@10.10.10.4

# Option 2: Via Proxmox container
ssh brian@10.10.10.17
sudo pct enter 119
```

**Edit DNS zone file:**
```bash
# Edit the zone file
sudo nano /etc/bind/zones/db.lan

# Make changes:
# 1. Update host IP: hostname    IN    A    10.10.10.XX
# 2. INCREMENT SERIAL NUMBER (critical!)
#    Format: YYYYMMDDNN (e.g., 2025110301 → 2025110302)

# Validate syntax
sudo named-checkzone lan /etc/bind/zones/db.lan

# Reload BIND9
sudo rndc reload

# Verify
dig @localhost hostname.lan +short
```

**Workflow for changing a host's IP:**
1. Update DNS record in BIND9 (increment serial!)
2. Set DHCP reservation in Firewalla to match
3. Reboot host to get new IP
4. Verify: `dig hostname.lan +short` should match new IP
5. Secondary BIND9 (Zeus) auto-syncs via zone transfer

**Important**: Always increment the serial number when editing zone files. BIND9 uses it to track versions and trigger zone transfers to secondary servers.

---

## Task: Adding a Host to Infrastructure

**Scenario**: New host needs IP allocation, DNS resolution, and monitoring.

**Checklist:**
- [ ] Host has network connectivity and can reach Firewalla
- [ ] Determine target IP address (must be in `10.10.10.0/24` range and not already assigned)
- [ ] SSH access to BIND9 primary (10.10.10.4 or via Proxmox 10.10.10.17)
- [ ] Checkmk server accessible for agent deployment

**Procedure:**

**1. Set Static IP via Firewalla DHCP Reservation**
```bash
# Via mobile app or web UI:
# - Devices tab → Select device → IP allocation → Reserved
# - Set desired IP (e.g., 10.10.10.50)
# - Save and reboot device
```

**2. Add DNS Record to BIND9**
```bash
ssh brian@10.10.10.4
sudo nano /etc/bind/zones/db.lan

# Add entry (replace hostname and IP as needed):
# hostname    IN    A    10.10.10.XX

# Increment serial number: YYYYMMDDNN format
# Edit the SOA serial: e.g., 2025110301 → 2025110302

# Validate and reload:
sudo named-checkzone lan /etc/bind/zones/db.lan
sudo rndc reload

# Verify DNS is working:
dig @localhost hostname.lan +short  # Should show 10.10.10.XX
```

**3. Deploy Checkmk Agent (if monitoring needed)**
```bash
# Add IP to update_checkmk_agents.sh lines 23-30:
# Add to HOSTS array: "10.10.10.XX"

# Validate and deploy:
bash -n update_checkmk_agents.sh
./update_checkmk_agents.sh
# Select the single host to test first

# After successful deployment, verify from Checkmk server:
sudo su - monitoring -c 'cmk -d hostname'
```

**4. Add to Checkmk Monitoring (via WATO)**
```bash
# Access Checkmk at https://checkmk.ratlm.com
# Setup → Hosts → Create new host
# - Hostname: hostname.lan
# - IPv4 address: 10.10.10.XX
# - Save and perform service discovery (cmk -I)
```

**Validation:**
```bash
# Test DNS resolution from multiple locations:
dig @10.10.10.4 hostname.lan          # BIND9 primary
dig @10.10.10.22 hostname.lan         # Pi-hole primary

# Test SSH access:
ssh brian@10.10.10.XX 'hostname'

# Test agent connectivity:
nc -zv 10.10.10.XX 6556

# Verify in Checkmk:
sudo su - monitoring -c 'cmk -d hostname'
```

---

## Task: Changing a Host's IP Address

**Scenario**: Need to change existing host's IP due to subnet reorg or renumbering.

**Important**: Always update DNS BEFORE changing the actual IP. This ensures services remain reachable during the transition.

**Procedure:**

**1. Update DNS Record in BIND9 (FIRST)**
```bash
ssh brian@10.10.10.4
sudo nano /etc/bind/zones/db.lan

# Update the A record:
# OLD: hostname    IN    A    10.10.10.30
# NEW: hostname    IN    A    10.10.10.50

# CRITICAL: Increment serial number
# e.g., 2025110301 → 2025110302

# Validate and apply:
sudo named-checkzone lan /etc/bind/zones/db.lan
sudo rndc reload

# Verify secondary BIND9 syncs:
dig @10.10.10.2 hostname.lan +short  # Should show new IP
```

**2. Update Firewalla DHCP Reservation**
```bash
# Via Firewalla app:
# Devices tab → Select host → IP allocation
# Change reserved IP from old to new
# Save
```

**3. Reboot Host**
```bash
ssh brian@10.10.10.OLD 'sudo reboot'
# Wait for reboot to complete (30-60 seconds typically)
```

**4. Verify New IP and Connectivity**
```bash
# Test DNS (should resolve to new IP):
dig @10.10.10.4 hostname.lan +short

# Test SSH to new IP:
ssh brian@10.10.10.NEW 'hostname -I'

# Verify Checkmk sees the new IP:
# - Update static IP in WATO if needed
# - Force service rediscovery: sudo su - monitoring -c 'cmk -I hostname'
```

**Rollback if needed:**
```bash
# Revert DNS record to old IP:
ssh brian@10.10.10.4
sudo nano /etc/bind/zones/db.lan
# Change IP back, increment serial, reload:
sudo rndc reload

# Revert DHCP reservation in Firewalla and reboot host
```

---

## Task: Removing/Decommissioning a Host

**Scenario**: Host is being retired and needs removal from infrastructure.

**Procedure:**

**1. Remove from Checkmk Monitoring**
```bash
# Via WATO or REST API:
# Setup → Hosts → Delete host (or mark as archived)

# Or via REST API:
curl -X DELETE \
  -u "cmkadmin:password" \
  "https://checkmk.ratlm.com/monitoring/api/1.0/domain-types/host_config/collections/all?host_name=hostname"
```

**2. Remove Agent Update Script References**
```bash
# Edit update_checkmk_agents.sh, remove host from HOSTS array:
nano update_checkmk_agents.sh  # Lines 23-30

# Validate:
bash -n update_checkmk_agents.sh
```

**3. Remove DNS Record from BIND9**
```bash
ssh brian@10.10.10.4
sudo nano /etc/bind/zones/db.lan

# Remove or comment out the A record:
# # hostname    IN    A    10.10.10.XX  (DECOMMISSIONED)

# Increment serial and reload:
sudo named-checkzone lan /etc/bind/zones/db.lan
sudo rndc reload

# Verify removal:
dig @10.10.10.4 hostname.lan +short  # Should return NXDOMAIN
```

**4. Release DHCP Reservation in Firewalla**
```bash
# Via Firewalla app:
# Devices tab → Select host → IP allocation
# Change back to Dynamic
# Save
```

**5. Document Decommissioning**
```bash
# Update project documentation:
# - Add to decommissioning notes
# - Include date removed
# - Include reason for decommissioning
# Example commit:
git add -A
git commit -m "INFRA: Decommission hostname - moved to different location"
```

---

## Task: Upgrading DNS Infrastructure (Pi-hole or BIND9)

**Scenario**: Need to upgrade DNS servers while maintaining service.

**For Pi-hole Primary (10.10.10.22):**
```bash
# 1. Verify secondary Pi-hole is operational:
dig @10.10.10.23 example.lan +short

# 2. Put primary in maintenance (temporarily divert traffic to secondary):
# Option A: Update Firewalla DNS settings to point to secondary only
# Option B: Stop pihole on primary: ssh brian@10.10.10.22 'pihole -off'

# 3. Upgrade:
ssh brian@10.10.10.22
pihole -up

# 4. Verify services:
pihole status
pihole -t  # Check recent queries

# 5. Resume normal operation (restore Firewalla DNS settings)
```

**For BIND9 Primary (10.10.10.4):**
```bash
# 1. Verify secondary BIND9 (10.10.10.2) is responding:
dig @10.10.10.2 example.lan AXFR

# 2. Stop primary: ssh brian@10.10.10.4 'sudo rndc stop'

# 3. Upgrade via package manager:
ssh brian@10.10.10.4
sudo apt update && sudo apt upgrade -y  # or equivalent

# 4. Restart and verify:
sudo rndc start
sudo rndc status
dig @localhost example.lan +short

# 5. Check secondary synced:
dig @10.10.10.2 example.lan +short
```

---

## Task: Monitoring Configuration Changes

**Scenario**: Adding/modifying checks or alerts in Checkmk after infrastructure change.

**Common Changes:**

**Add new host to monitoring:**
```bash
# 1. Host must be deployed with agent already
# 2. Via WATO or API, add host:
curl -X POST \
  -H "Content-Type: application/json" \
  -u "cmkadmin:password" \
  -d '{"host_name": "hostname", "folder": "/", "attributes": {}}' \
  "https://checkmk.ratlm.com/monitoring/api/1.0/domain-types/host_config/collections/all"

# 3. Perform service discovery:
sudo su - monitoring -c 'cmk -I hostname'

# 4. Verify in UI and activate changes
```

**Update monitoring for IP change:**
```bash
# If host IP changed:
# 1. Update static IPv4 in WATO for that host
# 2. Force rediscovery: sudo su - monitoring -c 'cmk -I hostname'
# 3. Activate configuration
```

**Enable custom checks:**
```bash
# For infrastructure components (Pi-hole, BIND9, etc.):
# 1. SSH to Checkmk: ssh brian@10.10.10.5
# 2. Check existing custom checks: ls /omd/sites/monitoring/local/share/check_mk/plugins/
# 3. Deploy custom checks to agents via Checkmk's plugin management
```

---

## Task: Service Migration (Moving service between hosts)

**Scenario**: Need to move a monitored service from one host to another.

**Procedure:**

**1. Pre-migration validation**
```bash
# Document current state:
sudo su - monitoring -c 'cmk -d old-host'     # Current metrics
curl -s https://old-service.ratlm.com/health  # Health check

# Verify destination host is ready:
ssh brian@new-host 'uptime && free -h'
```

**2. Set up new host (if new)**
```bash
# Follow "Task: Adding a Host to Infrastructure" section above
```

**3. Deploy service on new host**
```bash
# (Service-specific deployment steps)
# Ensure services are started and tested locally first
```

**4. Update NPM if external-facing**
```bash
# Via Nginx Proxy Manager web UI (10.10.10.3):
# Proxy Hosts → Edit service → Update backend to new host IP
# Test: curl -I https://service.ratlm.com
```

**5. Update Checkmk monitoring**
```bash
# Remove from old host:
sudo su - monitoring -c 'cmk -D old-host service-name'

# Add to new host:
sudo su - monitoring -c 'cmk -I new-host'

# Verify metrics flowing:
sudo su - monitoring -c 'cmk -d new-host | grep service-name'
```

**6. Decommission old host (if applicable)**
```bash
# Follow "Task: Removing/Decommissioning a Host" section above
```
