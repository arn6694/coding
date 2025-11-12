# BIND9 DNS Editing Guide

Complete workflow for editing DNS records in the homelab BIND9 server.

**Created:** 2025-11-03
**BIND9 Server:** 10.10.10.4 (Proxmox LXC 119)
**Zone File:** `/etc/bind/zones/db.lan`

---

## Complete DNS Edit Workflow

### Step 1: SSH into BIND9 Server
```bash
ssh brian@10.10.10.4
```

**Alternative (via Proxmox):**
```bash
ssh brian@10.10.10.17
sudo pct enter 119
```

### Step 2: Edit the Zone File
```bash
sudo nano /etc/bind/zones/db.lan
```

### Step 3: Make Your Changes

**To add a new host:**
```dns
newhost         IN      A       10.10.10.XX
```

**To change an existing host's IP:**
```dns
# Change this:
oldhost         IN      A       10.10.10.50

# To this:
oldhost         IN      A       10.10.10.60
```

**To remove a host:**
```dns
# Just delete or comment out the line:
# oldhost       IN      A       10.10.10.50
```

### Step 4: Increment the Serial Number (CRITICAL!)

Find the serial number near the top of the file:
```dns
@       IN      SOA     dns1.lan. admin.lan. (
                              2025110301         ; Serial ← Change this!
                              604800             ; Refresh
                              86400              ; Retry
                              2419200            ; Expire
                              604800 )           ; Negative Cache TTL
```

**Serial Number Format: YYYYMMDDNN**
- YYYY = 4-digit year (e.g., 2025)
- MM = 2-digit month (e.g., 11 for November)
- DD = 2-digit day (e.g., 03)
- NN = 2-digit revision number for that day (01, 02, 03...)

**How to increment:**
- If it's **2025110301**, change to **2025110302**
- If it's **2025110302**, change to **2025110303**
- Or use today's date: **2025110401** (for Nov 4th, revision 01)

**Why it's critical:**
- BIND9 only reloads zones when serial number increases
- Secondary DNS servers only sync when they see a higher serial
- Without incrementing, your changes won't take effect!

### Step 5: Save and Exit
1. Press **Ctrl+X**
2. Press **Y** (to confirm save)
3. Press **Enter** (to confirm filename)

### Step 6: Validate the Zone File
```bash
sudo named-checkzone lan /etc/bind/zones/db.lan
```

**Expected output:**
```
zone lan/IN: loaded serial 2025110302
OK
```

**If you see errors:**
- Read the error message carefully
- Common issues: missing period, typo in hostname, wrong IP format
- Go back to Step 2 and fix the errors

### Step 7: Restart BIND9
```bash
sudo systemctl restart named
```

**Note:** Sometimes `sudo rndc reload` works, but `systemctl restart named` is more reliable and ensures all changes are loaded.

### Step 8: Verify DNS is Working on BIND9
```bash
dig @localhost hostname.lan +short
```

This should return the IP address you just set.

**Additional verification:**
```bash
dig @localhost hostname.lan

# Check the SOA serial updated:
dig @localhost lan SOA +short
```

### Step 9: Flush Pi-hole Cache
```bash
# Exit from BIND9 server first (Ctrl+D or type 'exit')

# Then from your workstation:
ssh brian@10.10.10.22 "sudo pihole reloaddns && sudo unbound-control flush_zone lan"
```

**Why this is needed:**
- Pi-hole and Unbound cache DNS responses
- Old cached responses can persist for hours
- Flushing ensures immediate propagation of changes

### Step 10: Test from Your Workstation
```bash
# Test DNS resolution
dig hostname.lan +short

# Test ping (if host is online)
ping hostname.lan

# Test from Pi-hole directly
dig @10.10.10.22 hostname.lan +short
```

---

## Quick Reference Card

```bash
1. ssh brian@10.10.10.4
2. sudo nano /etc/bind/zones/db.lan
3. Make changes + INCREMENT SERIAL NUMBER
4. Ctrl+X, Y, Enter
5. sudo named-checkzone lan /etc/bind/zones/db.lan
6. sudo systemctl restart named
7. dig @localhost hostname.lan +short
8. exit (from BIND9)
9. ssh brian@10.10.10.22 "sudo pihole reloaddns && sudo unbound-control flush_zone lan"
10. dig hostname.lan +short
```

---

## Common Mistakes to Avoid

❌ **Forgot to increment serial number**
- Symptom: Changes don't appear in DNS queries
- Fix: Edit file again, increment serial, restart BIND9

❌ **Used `rndc reload` instead of `systemctl restart named`**
- Symptom: Changes don't take effect even with serial increment
- Fix: Use `systemctl restart named` instead

❌ **Forgot to flush Pi-hole/Unbound cache**
- Symptom: DNS works on BIND9 server but not from workstations
- Fix: Run the cache flush command from Step 9

❌ **Typos in hostname or IP**
- Symptom: DNS doesn't resolve or resolves to wrong IP
- Fix: named-checkzone will catch most typos, but verify manually

❌ **Missing tabs/spaces in zone file**
- Symptom: Zone file syntax errors
- Fix: Use tabs between hostname and IN, and between IN and A

❌ **Forgot to set DHCP reservation in Firewalla**
- Symptom: Host gets different IP after reboot, DNS mismatch
- Fix: Set DHCP reservation in Firewalla to match DNS record

---

## Complete Workflow for Adding a New Host

**Scenario:** Adding a new device "newdevice" at 10.10.10.100

1. **Update BIND9 DNS:**
   ```bash
   ssh brian@10.10.10.4
   sudo nano /etc/bind/zones/db.lan

   # Add line:
   newdevice       IN      A       10.10.10.100

   # Increment serial: 2025110301 → 2025110302

   # Save: Ctrl+X, Y, Enter
   sudo named-checkzone lan /etc/bind/zones/db.lan
   sudo systemctl restart named
   dig @localhost newdevice.lan +short  # Should show 10.10.10.100
   exit
   ```

2. **Set DHCP Reservation in Firewalla:**
   - Open Firewalla app
   - Go to Devices → Find "newdevice"
   - Tap device → IP allocation → Reserved
   - Set to: 10.10.10.100
   - Save

3. **Reboot the device** to get reserved IP

4. **Flush Pi-hole cache:**
   ```bash
   ssh brian@10.10.10.22 "sudo pihole reloaddns && sudo unbound-control flush_zone lan"
   ```

5. **Verify:**
   ```bash
   dig newdevice.lan +short
   ping newdevice.lan
   ```

---

## Troubleshooting

### DNS doesn't resolve after changes

**Check 1: Serial number incremented?**
```bash
ssh brian@10.10.10.4
grep Serial /etc/bind/zones/db.lan
```

**Check 2: BIND9 running?**
```bash
ssh brian@10.10.10.4
sudo systemctl status named
```

**Check 3: Zone loaded correctly?**
```bash
ssh brian@10.10.10.4
dig @localhost lan SOA +short
```

**Check 4: Pi-hole cache cleared?**
```bash
ssh brian@10.10.10.22 "sudo unbound-control flush_zone lan"
dig @10.10.10.22 hostname.lan +short
```

### Zone file syntax errors

**Check syntax:**
```bash
sudo named-checkzone lan /etc/bind/zones/db.lan
```

**Common syntax issues:**
- Missing period after domain in SOA line
- Wrong spacing (use tabs, not spaces)
- Typo in record type (should be IN A, not IN a)
- Invalid IP address format

### Secondary DNS not syncing

**Check serial on secondary (Zeus - when online):**
```bash
ssh user@10.10.10.2
dig @localhost lan SOA +short
```

Serial should match primary. If not:
- Ensure serial on primary is higher
- Check zone transfer allowed in BIND9 config
- Check network connectivity between primary and secondary

---

## Zone File Example

```dns
;
; BIND data file for lan domain
;
$TTL    604800
@       IN      SOA     dns1.lan. admin.lan. (
                              2025110301         ; Serial (YYYYMMDDNN)
                              604800             ; Refresh
                              86400              ; Retry
                              2419200            ; Expire
                              604800 )           ; Negative Cache TTL
;
; Name servers
@       IN      NS      dns1.lan.
@       IN      NS      dns2.lan.

; A Records - Infrastructure
dns1            IN      A       10.10.10.4
dns2            IN      A       10.10.10.2

; Network Infrastructure
firewalla       IN      A       10.10.10.1
gateway         IN      A       10.10.10.1

; Monitoring
checkmk         IN      A       10.10.10.5

; DNS & Pi-hole
pihole1         IN      A       10.10.10.22
pihole2         IN      A       10.10.10.23

; Servers
proxmox         IN      A       10.10.10.17
jarvis          IN      A       10.10.10.49
jellyfin        IN      A       10.10.10.42
bookworm        IN      A       10.10.10.7

; Workstations
ser8            IN      A       10.10.10.96
geekom          IN      A       10.10.10.9

; Home Assistant
homeassistant   IN      A       10.10.10.6
ha              IN      A       10.10.10.6

; Add more hosts below
```

---

## Related Documentation

- **Firewalla DHCP Reservations:** See CLAUDE.md "Managing DNS and DHCP" section
- **Pi-hole Configuration:** `/etc/dnsmasq.d/03-lan-bind9.conf`
- **BIND9 Container Access:** `sudo pct enter 119` from Proxmox host

---

**Last Updated:** 2025-11-03
**Tested On:** Debian 12 (BIND 9.18.41)
