# Pi-hole Migration Guide: AdGuard → Pi-hole

## Overview

This guide covers migrating from AdGuard Home (10.10.10.7:9999) to Pi-hole (10.10.10.22:53) while maintaining the same level of DNS filtering and privacy.

## Current Setup Analysis

### AdGuard Home Configuration (10.10.10.7)
- **Access**: http://10.10.10.7:9999
- **DNS Port**: 53
- **Running**: Docker container (host network mode)
- **Upstream DNS**:
  - https://dns.quad9.net/dns-query
  - https://dns.google/dns-query
  - https://dns.cloudflare.com/dns-query
  - Mode: Load balancing
- **DNSSEC**: Enabled
- **Active Blocklists**:
  - AdGuard DNS filter
  - AdAway Default Blocklist
  - Dan Pollock's List
  - Phishing URL Blocklist (PhishTank and OpenPhish)
  - Perflyst and Dandelion Sprout's Smart-TV Blocklist

### Pi-hole Configuration (10.10.10.22)
- **Access**: http://10.10.10.22/admin
- **DNS Port**: 53
- **Running**: Native Debian 12 installation
- **Upstream DNS**:
  - 127.0.0.1#5335 (Unbound - recursive DNS resolver) ✅
  - 8.8.4.4 (Google DNS fallback)
- **Unbound Status**: ✅ Already installed and running
- **Current Status**: ✅ Operational and ready

---

## Key Differences: AdGuard vs Pi-hole

| Feature | AdGuard | Pi-hole (with Unbound) |
|---------|---------|------------------------|
| **DNS Resolution** | Uses upstream DoH providers (Quad9, Google, Cloudflare) | Uses local recursive DNS (Unbound) - **More private!** |
| **Privacy** | Queries sent to third parties | Queries resolved directly from root servers - **No third parties!** |
| **Performance** | Depends on external providers | Local caching with recursive lookups |
| **Blocklists** | AdGuard-specific lists | Large Pi-hole community lists |
| **Web UI** | Modern React-based | Traditional PHP-based, but very functional |
| **DNSSEC** | Built-in | Handled by Unbound |
| **Docker** | Running in container | Native installation |

---

## Migration Plan

### Phase 1: Configure Pi-hole Blocklists

Your Pi-hole needs the same blocklists as AdGuard. Let me add them now:

1. **Current Pi-hole Blocklists**:
```bash
ssh brian@10.10.10.22 "sudo cat /etc/pihole/adlists.list"
```

2. **Add AdGuard-equivalent blocklists**:

```bash
ssh brian@10.10.10.22 "sudo tee -a /etc/pihole/adlists.list << 'EOF'
# AdGuard DNS filter equivalent
https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt

# AdAway Default Blocklist
https://adaway.org/hosts.txt

# Dan Pollock's List
https://someonewhocares.org/hosts/zero/hosts

# Phishing and Malware
https://phishing.army/download/phishing_army_blocklist_extended.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# Smart-TV Blocklist
https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt

# Additional recommended Pi-hole lists
https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
https://v.firebog.net/hosts/Easyprivacy.txt
https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt
EOF"
```

3. **Update gravity (blocklists)**:
```bash
ssh brian@10.10.10.22 "pihole -g"
```

### Phase 2: Verify Unbound Configuration

Your Pi-hole is already configured to use Unbound (127.0.0.1#5335), which is **better than AdGuard's approach** because:

- ✅ **No third-party DNS providers** - AdGuard sends queries to Quad9/Google/Cloudflare
- ✅ **Complete privacy** - Unbound queries root servers directly
- ✅ **No logging by external parties**
- ✅ **DNSSEC validation** built-in
- ✅ **Local caching** for faster responses

**Current Pi-hole DNS Settings**:
```toml
upstreams = [
    "127.0.0.1#5335",  # Unbound (primary)
    "8.8.4.4"          # Google fallback
]
```

**Optional: Remove Google DNS fallback** (for maximum privacy):

```bash
ssh brian@10.10.10.22 "sudo sed -i '/8.8.4.4/d' /etc/pihole/pihole.toml && sudo systemctl restart pihole-FTL"
```

This makes Unbound the only upstream, eliminating all third-party DNS providers.

### Phase 3: Network Cutover

You have three cutover options:

#### **Option A: Router/DHCP Change (Recommended)**

Change your router's DHCP DNS server settings:

1. Log into your router (likely Firewalla at 10.10.10.1 or Orbi)
2. Navigate to DHCP settings
3. Change DNS server from: `10.10.10.7` → `10.10.10.22`
4. Save and wait for DHCP leases to renew (or reboot devices)

**Advantages**: Clean cutover, all devices automatically switch

#### **Option B: Network Device Changes**

For devices with static DNS configured, manually update:

**Example for Linux/macOS**:
```bash
# Check current DNS
cat /etc/resolv.conf

# Update to Pi-hole (if using static DNS)
# Add to /etc/resolv.conf:
nameserver 10.10.10.22
```

**Example for Windows**:
- Network Settings → Change adapter options
- Right-click network → Properties
- IPv4 → Properties → Preferred DNS: `10.10.10.22`

#### **Option C: Test Mode (Safe Testing)**

Test Pi-hole on specific devices before full cutover:

```bash
# On test device (Linux/Mac)
sudo sed -i '1i nameserver 10.10.10.22' /etc/resolv.conf

# Test DNS resolution
nslookup google.com 10.10.10.22
dig @10.10.10.22 example.com

# Check for blocked domains
nslookup ads.doubleclick.net 10.10.10.22  # Should be blocked
```

### Phase 4: Verification & Testing

After cutover, verify everything is working:

#### **1. Check Pi-hole is receiving queries**:
```bash
ssh brian@10.10.10.22 "pihole -c"  # Live query log
```

Or visit: http://10.10.10.22/admin

#### **2. Test DNS resolution**:
```bash
# From any client on your network
nslookup google.com
nslookup facebook.com
nslookup amazon.com
```

#### **3. Test ad blocking**:
```bash
# These should be blocked
nslookup ads.doubleclick.net
nslookup ad.doubleclick.net
nslookup pagead2.googlesyndication.com

# Should return 0.0.0.0 or your Pi-hole IP
```

#### **4. Check Unbound is working**:
```bash
ssh brian@10.10.10.22 "dig @127.0.0.1 -p 5335 google.com +short"
```

Should return results, confirming Unbound is resolving.

#### **5. Verify DNSSEC**:
```bash
dig @10.10.10.22 sigfail.verteiltesysteme.net  # Should fail
dig @10.10.10.22 sigok.verteiltesysteme.net    # Should succeed
```

### Phase 5: AdGuard Shutdown (After Testing Period)

Once you've confirmed Pi-hole is working well (recommend 1-2 weeks):

#### **Stop AdGuard Container**:
```bash
ssh brian@10.10.10.7 "sudo docker stop AdGuard"
```

#### **Keep for rollback (optional)**:
```bash
# Don't remove yet, just stop it
# If issues arise, you can quickly restart:
ssh brian@10.10.10.7 "sudo docker start AdGuard"
```

#### **Permanent removal (after confidence)**:
```bash
# After 2-4 weeks of stable Pi-hole operation
ssh brian@10.10.10.7 "sudo docker rm AdGuard"
ssh brian@10.10.10.7 "sudo rm -rf /docker/adguard"
```

---

## Post-Migration Configuration

### Pi-hole Web Interface Access

- **URL**: http://10.10.10.22/admin
- **Password**: Set during Pi-hole installation
- **Reset password if needed**:
  ```bash
  ssh brian@10.10.10.22 "pihole -a -p"
  ```

### Recommended Pi-hole Settings

1. **Enable Query Logging** (for troubleshooting):
   - Settings → Privacy → Show everything

2. **Configure Local DNS Records**:
   - Local DNS → DNS Records
   - Add entries for your local services (e.g., proxmox.lan, homeassistant.lan)

3. **Whitelist Management**:
   - If legitimate sites are blocked, add to whitelist
   - Tools → Whitelist → Add domain

4. **Blacklist Custom Domains**:
   - Tools → Blacklist → Add domains you want to block

5. **Enable DHCP** (optional):
   - If you want Pi-hole to handle DHCP
   - Settings → DHCP → Enable DHCP server

### Unbound Optimization (Optional)

Current Unbound config is fine, but you can optimize:

```bash
ssh brian@10.10.10.22 "sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf"
```

Add these optimizations:
```conf
server:
    # Performance tuning
    num-threads: 4
    msg-cache-slabs: 8
    rrset-cache-slabs: 8
    infra-cache-slabs: 8
    key-cache-slabs: 8

    # Increase cache sizes
    rrset-cache-size: 256m
    msg-cache-size: 128m

    # Prefetching
    prefetch: yes
    prefetch-key: yes

    # Privacy
    hide-identity: yes
    hide-version: yes

    # DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
```

Restart Unbound:
```bash
ssh brian@10.10.10.22 "sudo systemctl restart unbound"
```

---

## Monitoring & Maintenance

### Daily Checks

**Pi-hole Dashboard**: http://10.10.10.22/admin
- Total queries
- Queries blocked (%)
- Blocklist domains

**Checkmk Monitoring**: http://10.10.10.5/monitoring/
- "zero" host should show:
  - DNS service UP
  - CPU/Memory usage
  - Disk space

### Weekly Tasks

1. **Update gravity** (blocklists):
   ```bash
   ssh brian@10.10.10.22 "pihole -up && pihole -g"
   ```

2. **Check for Pi-hole updates**:
   ```bash
   ssh brian@10.10.10.22 "pihole -up"
   ```

3. **Review top blocked domains**:
   - Dashboard → Top Blocked Domains

### Monthly Tasks

1. **Review whitelisted domains** - ensure still needed
2. **Check Unbound logs** for issues:
   ```bash
   ssh brian@10.10.10.22 "sudo journalctl -u unbound --since '1 month ago' | grep -i error"
   ```
3. **Verify DNSSEC** is still working
4. **Check Pi-hole database size**:
   ```bash
   ssh brian@10.10.10.22 "ls -lh /etc/pihole/*.db"
   ```

---

## Troubleshooting

### Issue: DNS Not Resolving

**Check Pi-hole status**:
```bash
ssh brian@10.10.10.22 "pihole status"
ssh brian@10.10.10.22 "sudo systemctl status pihole-FTL"
```

**Check Unbound status**:
```bash
ssh brian@10.10.10.22 "sudo systemctl status unbound"
```

**Restart services**:
```bash
ssh brian@10.10.10.22 "sudo systemctl restart unbound && sudo systemctl restart pihole-FTL"
```

### Issue: Websites Not Loading

**Check if domain is blocked**:
```bash
ssh brian@10.10.10.22 "pihole -q domain.example.com"
```

**Temporarily disable blocking**:
```bash
ssh brian@10.10.10.22 "pihole disable 5m"  # Disable for 5 minutes
```

**Whitelist domain**:
```bash
ssh brian@10.10.10.22 "pihole -w domain.example.com"
```

### Issue: Slow DNS Responses

**Check Unbound cache**:
```bash
ssh brian@10.10.10.22 "sudo unbound-control stats_noreset | grep 'cache'"
```

**Flush DNS cache**:
```bash
ssh brian@10.10.10.22 "sudo systemctl restart pihole-FTL"
```

**Check Unbound logs**:
```bash
ssh brian@10.10.10.22 "sudo journalctl -u unbound -f"
```

### Issue: High CPU/Memory Usage

**Check Pi-hole stats**:
```bash
ssh brian@10.10.10.22 "pihole -c"
```

**Reduce logging**:
- Web UI → Settings → Privacy → Anonymous mode

**Optimize database**:
```bash
ssh brian@10.10.10.22 "sudo sqlite3 /etc/pihole/pihole-FTL.db 'VACUUM;'"
```

---

## Rollback Plan

If issues arise and you need to quickly switch back to AdGuard:

### Emergency Rollback (5 minutes)

1. **Start AdGuard**:
   ```bash
   ssh brian@10.10.10.7 "sudo docker start AdGuard"
   ```

2. **Update router DHCP** to use: `10.10.10.7`

3. **Or update device DNS** manually back to: `10.10.10.7`

4. **Flush DNS cache on clients**:
   - **Windows**: `ipconfig /flushdns`
   - **macOS**: `sudo dscacheutil -flushcache`
   - **Linux**: `sudo systemd-resolve --flush-caches`

---

## Advantages of Pi-hole + Unbound Over AdGuard

### Privacy Improvements
- ✅ **No third-party DNS providers** - Unbound queries root servers directly
- ✅ **No external logging** - All queries stay on your network
- ✅ **No DNS-over-HTTPS to commercial providers**
- ✅ **Complete control** over DNS resolution path

### Performance
- ✅ **Local caching** - Faster subsequent queries
- ✅ **No internet dependency** for cached results
- ✅ **Reduced latency** - No round-trip to Quad9/Google/Cloudflare

### Community & Support
- ✅ **Massive Pi-hole community** - More blocklists, support, plugins
- ✅ **Battle-tested** - Pi-hole has been around longer
- ✅ **Integration** - Native Checkmk monitoring

### Technical Benefits
- ✅ **Native Debian package** - No Docker overhead
- ✅ **Systemd integration** - Better logging and management
- ✅ **DNSSEC validation** through Unbound
- ✅ **Recursive DNS** - More resilient to upstream provider issues

---

## Summary Checklist

### Pre-Migration
- [x] Pi-hole installed and operational (10.10.10.22)
- [x] Unbound installed and running (port 5335)
- [x] Checkmk monitoring configured for "zero"
- [ ] Blocklists added to Pi-hole
- [ ] Gravity updated

### Migration
- [ ] Test Pi-hole DNS from one device
- [ ] Verify blocking is working
- [ ] Update router/DHCP to use Pi-hole (10.10.10.22)
- [ ] Monitor Pi-hole dashboard for queries
- [ ] Test from multiple devices
- [ ] Verify no DNS issues for 24-48 hours

### Post-Migration
- [ ] Stop AdGuard container (keep for 1-2 weeks)
- [ ] Configure Pi-hole settings (whitelists, blacklists)
- [ ] Set up regular maintenance schedule
- [ ] After 2 weeks: Remove AdGuard permanently

---

## Quick Reference

### URLs
- **Pi-hole Admin**: http://10.10.10.22/admin
- **AdGuard (old)**: http://10.10.10.7:9999
- **Checkmk**: http://10.10.10.5/monitoring/

### IPs
- **Pi-hole (zero)**: 10.10.10.22
- **AdGuard (bookworm)**: 10.10.10.7
- **Checkmk**: 10.10.10.5

### Ports
- **DNS**: 53 (UDP/TCP)
- **Unbound**: 5335 (local only)
- **Pi-hole Web**: 80
- **AdGuard Web**: 9999

### Key Commands
```bash
# Pi-hole status
ssh brian@10.10.10.22 "pihole status"

# Update blocklists
ssh brian@10.10.10.22 "pihole -g"

# Live query log
ssh brian@10.10.10.22 "pihole -c"

# Disable blocking (5 min)
ssh brian@10.10.10.22 "pihole disable 5m"

# Whitelist domain
ssh brian@10.10.10.22 "pihole -w example.com"

# Check Unbound
ssh brian@10.10.10.22 "sudo systemctl status unbound"
```

---

**Document Created**: 2025-10-29
**Pi-hole Server**: zero (10.10.10.22) - Debian 12
**AdGuard Server**: bookworm (10.10.10.7) - Docker
**Status**: Pi-hole operational with Unbound, ready for migration
