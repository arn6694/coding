# Pi-hole Wildcard DNS for Nginx Proxy Manager

## Overview

This configuration enables automatic DNS resolution for ALL *.ratlm.com subdomains to your Nginx Proxy Manager without needing to manually add each subdomain to Pi-hole.

## Configuration

### Pi-hole Server: zero (10.10.10.22)
### NPM Server: 10.10.10.3
### Domain: ratlm.com

## Setup

### 1. Enable dnsmasq.d Directory

Pi-hole v6 disables `/etc/dnsmasq.d/` by default. Enable it in `/etc/pihole/pihole.toml`:

```toml
[misc]
  etc_dnsmasq_d = true
```

### 2. Create Wildcard DNS Configuration

File: `/etc/dnsmasq.d/02-ratlm-local.conf`

```bash
# Wildcard DNS for all *.ratlm.com subdomains to local NPM
# This will match ANY subdomain under ratlm.com
address=/ratlm.com/10.10.10.3
local=/ratlm.com/
```

**What each directive does:**
- `address=/ratlm.com/10.10.10.3` - Resolves ALL *.ratlm.com subdomains to 10.10.10.3
- `local=/ratlm.com/` - Prevents Pi-hole from forwarding ratlm.com queries to upstream DNS (stops IPv6 leakage to Cloudflare)

### 3. Restart Pi-hole FTL

```bash
sudo systemctl restart pihole-FTL
```

## How It Works

When you add a new proxy host in NPM (e.g., `newapp.ratlm.com`):

1. **No Pi-hole configuration needed!** - The wildcard automatically resolves it to 10.10.10.3
2. NPM receives the request with the `Host: newapp.ratlm.com` header
3. NPM routes it to the correct backend based on its proxy host configuration
4. SSL certificate (*.ratlm.com wildcard) works automatically

## Testing

Test any subdomain (even ones that don't exist in NPM yet):

```bash
# Test DNS resolution
nslookup mynewapp.ratlm.com 10.10.10.22

# Should return:
# Name: mynewapp.ratlm.com
# Address: 10.10.10.3
```

## Adding New Services

### Step 1: Configure in NPM Only
1. Log into NPM: http://npm.ratlm.com (or http://10.10.10.3:81)
2. Add new Proxy Host:
   - Domain Names: `yourapp.ratlm.com`
   - Scheme: http or https
   - Forward Hostname/IP: Your backend server IP
   - Forward Port: Your backend port
3. SSL Certificate: Select "*.ratlm.com" (Certificate #6)
4. Enable "Force SSL"

### Step 2: Access Your Service
- Pi-hole automatically resolves `yourapp.ratlm.com` → `10.10.10.3`
- NPM proxies to your backend
- SSL works automatically via wildcard cert

**That's it!** No Pi-hole configuration needed.

## Benefits

✅ **Automatic DNS** - Add services in NPM only, Pi-hole handles DNS automatically
✅ **No manual entries** - Wildcard matches ALL subdomains
✅ **SSL included** - *.ratlm.com wildcard certificate covers all subdomains
✅ **No IPv6 leakage** - `local=/ratlm.com/` prevents queries to Cloudflare
✅ **Easy management** - One configuration file handles everything

## Current Services (Examples)

All these work automatically via the wildcard:
- proxmox.ratlm.com → 10.10.10.17:8006
- checkmk.ratlm.com → 10.10.10.5:80
- npm.ratlm.com → 10.10.10.3:81
- ha.ratlm.com → 10.10.10.6:8123
- jellyfin.ratlm.com → 10.10.10.42:8096
- *Any new subdomain you add in NPM*

## Troubleshooting

### Subdomain not resolving

**Check if dnsmasq.d is enabled:**
```bash
sudo pihole-FTL --config | grep etc_dnsmasq_d
# Should show: misc.etc_dnsmasq_d = true
```

**Check if config file exists:**
```bash
cat /etc/dnsmasq.d/02-ratlm-local.conf
```

**Test DNS directly:**
```bash
nslookup test.ratlm.com 10.10.10.22
```

**Restart Pi-hole FTL:**
```bash
sudo systemctl restart pihole-FTL
```

### Getting Cloudflare IPs instead of local IP

This means the `local=/ratlm.com/` directive isn't working. Verify:

```bash
dig @10.10.10.22 proxmox.ratlm.com AAAA +short
```

Should return empty (no IPv6 addresses). If you see Cloudflare IPv6 addresses, restart Pi-hole FTL.

### SSL Certificate Errors

The wildcard certificate should auto-renew, but if you see SSL errors:

**Check certificate on NPM server:**
```bash
ssh brian@10.10.10.3 "sudo certbot certificates"
```

**Force renewal if needed:**
```bash
ssh brian@10.10.10.3 "sudo certbot renew --force-renewal --cert-name npm-6"
sudo systemctl restart npm.service
```

## Files Modified

### Pi-hole Server (10.10.10.22)
- `/etc/pihole/pihole.toml` - Enabled `misc.etc_dnsmasq_d = true`
- `/etc/dnsmasq.d/02-ratlm-local.conf` - Wildcard DNS configuration

### NPM Server (10.10.10.3)
- `/etc/letsencrypt/live/npm-6/` - Wildcard SSL certificate (*.ratlm.com)
- Cloudflare API token configured in NPM for automatic cert renewal

## Maintenance

### Weekly
- No action needed - wildcard handles all new subdomains automatically

### Monthly
- Verify SSL certificate auto-renewal is working
- Check Pi-hole query logs for any issues

### When Adding New Service
1. Add proxy host in NPM web UI
2. Select existing *.ratlm.com certificate
3. Access immediately - DNS works automatically

---

**Created:** 2025-10-29
**Pi-hole:** zero (10.10.10.22) - Debian 12, Pi-hole v6
**NPM:** 10.10.10.3 - Nginx Proxy Manager
**Domain:** ratlm.com (Cloudflare DNS, wildcard cert via Let's Encrypt)
**Status:** ✅ Wildcard DNS fully operational
