# Checkmk DNS Monitoring Setup Guide

**Created:** 2025-11-02
**Checkmk Server:** http://10.10.10.5/monitoring/
**Site:** monitoring

## Overview

This guide will help you configure DNS health monitoring for your redundant DNS infrastructure in Checkmk.

## DNS Services to Monitor

### 1. BIND9 #1 (Primary) - 10.10.10.4
- **Host**: dns1.lan
- **IP**: 10.10.10.4
- **Purpose**: Primary authoritative DNS for .lan domain
- **Container**: Proxmox LXC 119

### 2. BIND9 #2 (Secondary) - 10.10.10.2
- **Host**: dns2.lan / zeus.lan
- **IP**: 10.10.10.2
- **Purpose**: Secondary authoritative DNS for .lan domain
- **Container**: Docker on Zeus (Synology NAS)

### 3. Pi-hole #1 (Primary) - 10.10.10.22
- **Host**: pihole.lan / pihole1.lan
- **IP**: 10.10.10.22
- **Purpose**: Primary DNS resolver with ad-blocking
- **Container**: Proxmox LXC 105

### 4. Pi-hole #2 (Secondary) - 10.10.10.23
- **Host**: pihole2.lan
- **IP**: 10.10.10.23
- **Purpose**: Secondary DNS resolver with ad-blocking
- **Container**: Docker on Zeus (Synology NAS)

## Step-by-Step Configuration

### Part 1: Add Hosts to Checkmk

1. **Log into Checkmk**: http://10.10.10.5/monitoring/
2. Go to **Setup → Hosts → Add host**

For each DNS server, add with these settings:

#### BIND9 #1 (dns1.lan)
- **Hostname**: dns1
- **IPv4 Address**: 10.10.10.4
- **Host tags**:
  - Agent type: `No API integrations, no Checkmk agent`
  - Criticality: `Productive system`
- **Data sources**:
  - Check_MK Agent: `No agent`
- **Save**

#### BIND9 #2 (dns2.lan)
- **Hostname**: dns2
- **IPv4 Address**: 10.10.10.2
- **Host tags**:
  - Agent type: `No API integrations, no Checkmk agent`
  - Criticality: `Productive system`
- **Data sources**:
  - Check_MK Agent: `No agent`
- **Save**

#### Pi-hole #1 (pihole1.lan)
- **Hostname**: pihole1
- **IPv4 Address**: 10.10.10.22
- **Host tags**:
  - Agent type: `Checkmk agent (Server)`
  - Criticality: `Productive system`
- **Data sources**:
  - Check_MK Agent: `API integrations if configured, else Checkmk agent`
- **Save**

#### Pi-hole #2 (pihole2.lan)
- **Hostname**: pihole2
- **IPv4 Address**: 10.10.10.23
- **Host tags**:
  - Agent type: `No API integrations, no Checkmk agent`
  - Criticality: `Productive system`
- **Data sources**:
  - Check_MK Agent: `No agent`
- **Save**

### Part 2: Add DNS Check Services

For each host, add active DNS check services:

1. Go to **Setup → Hosts → [hostname] → Service monitoring rules**
2. Click **Add rule** under "Active checks"
3. Select **Check DNS service**

#### Configuration for Each Service:

##### BIND9 #1 - Check .lan queries
- **Description**: DNS query for proxmox.lan
- **DNS Hostname or IP Address**: 10.10.10.4
- **Hostnames or IP addresses to lookup**: `proxmox.lan`
- **Expected DNS answer (IP)**: `10.10.10.17`
- **Expected response time (seconds)**: Warning: 1, Critical: 3
- **Conditions**: Explicit hosts: `dns1`

##### BIND9 #2 - Check .lan queries
- **Description**: DNS query for proxmox.lan
- **DNS Hostname or IP Address**: 10.10.10.2
- **Hostnames or IP addresses to lookup**: `proxmox.lan`
- **Expected DNS answer (IP)**: `10.10.10.17`
- **Expected response time (seconds)**: Warning: 1, Critical: 3
- **Conditions**: Explicit hosts: `dns2`

##### Pi-hole #1 - Check .lan forwarding
- **Description**: DNS query for ser8.lan via Pi-hole
- **DNS Hostname or IP Address**: 10.10.10.22
- **Hostnames or IP addresses to lookup**: `ser8.lan`
- **Expected DNS answer (IP)**: `10.10.10.96`
- **Expected response time (seconds)**: Warning: 1, Critical: 3
- **Conditions**: Explicit hosts: `pihole1`

##### Pi-hole #1 - Check internet DNS
- **Description**: DNS query for google.com
- **DNS Hostname or IP Address**: 10.10.10.22
- **Hostnames or IP addresses to lookup**: `google.com`
- **Expected response time (seconds)**: Warning: 2, Critical: 5
- **Note**: Don't specify expected IP (Google uses many IPs)
- **Conditions**: Explicit hosts: `pihole1`

##### Pi-hole #2 - Check .lan forwarding
- **Description**: DNS query for ser8.lan via Pi-hole
- **DNS Hostname or IP Address**: 10.10.10.23
- **Hostnames or IP addresses to lookup**: `ser8.lan`
- **Expected DNS answer (IP)**: `10.10.10.96`
- **Expected response time (seconds)**: Warning: 1, Critical: 3
- **Conditions**: Explicit hosts: `pihole2`

##### Pi-hole #2 - Check internet DNS
- **Description**: DNS query for google.com
- **DNS Hostname or IP Address**: 10.10.10.23
- **Hostnames or IP addresses to lookup**: `google.com`
- **Expected response time (seconds)**: Warning: 2, Critical: 5
- **Note**: Don't specify expected IP
- **Conditions**: Explicit hosts: `pihole2`

### Part 3: Add Ping/Availability Checks

For all DNS servers, ensure basic availability monitoring:

1. Go to **Setup → Hosts → [hostname]**
2. Check that "Ping" is enabled in the host settings
3. If not, go to **Setup → Service monitoring rules → Host Check Command**
4. Add rule with:
   - **Host Check Command**: `Smart PING`
   - **Conditions**: Folder: All hosts
   - **Save**

### Part 4: Activate Changes

1. Click the yellow **"1 change"** button in the top right
2. Review changes
3. Click **"Activate on selected sites"**
4. Wait for activation to complete

### Part 5: Create Dashboard

Create a custom dashboard for DNS monitoring:

1. Go to **Monitor → Overview → Add dashboard**
2. Name it "DNS Infrastructure"
3. Add widgets:
   - **Host status** for dns1, dns2, pihole1, pihole2
   - **Service status** filtered by "DNS"
   - **Performance graph** for DNS query response times

## Alert Configuration

### Critical Alerts (Email/SMS)

Set up alerts for:
- Any DNS server DOWN
- DNS query failures
- Response time > 5 seconds

### Warning Alerts (Email only)

Set up alerts for:
- Response time > 2 seconds
- One DNS server in redundant pair DOWN (degraded but functional)

### Configuration Steps:

1. **Setup → Notifications**
2. **Add rule**
3. Configure:
   - **Description**: DNS Critical Failure Alert
   - **Notification Method**: Email (or your preferred method)
   - **Conditions**:
     - Match hosts: dns1, dns2, pihole1, pihole2
     - Match services: Contains "DNS"
     - State: CRIT or DOWN
   - **Contact groups**: Admins
4. **Save**

## Verification

After setup, verify monitoring is working:

### Check Service Status
1. Go to **Monitor → All hosts**
2. Filter by: dns1, dns2, pihole1, pihole2
3. Verify all hosts show GREEN (UP)
4. Click each host to see services
5. Verify all DNS check services show OK

### Test Alerts
1. Stop one DNS service:
   ```bash
   ssh brian@10.10.10.4 "sudo systemctl stop bind9"
   ```
2. Wait 1-2 minutes
3. Verify Checkmk shows host as DOWN or CRIT
4. Verify alert notification received
5. Restart service:
   ```bash
   ssh brian@10.10.10.4 "sudo systemctl start bind9"
   ```
6. Verify recovery notification

## Maintenance Tasks

### Weekly
- Review DNS query response time graphs
- Check for any service flapping (up/down repeatedly)

### Monthly
- Verify all DNS checks are running successfully
- Review alert history for false positives
- Update expected response times if infrastructure changes

### When Adding New Hosts to BIND9
- Update "Expected DNS answer" in Checkmk checks to include new hosts
- Or add additional DNS check service for the new hostname

## Troubleshooting

### Services not appearing
- Run service discovery: Setup → Hosts → [hostname] → Service discovery → Full scan
- Activate changes
- Refresh page

### DNS checks failing despite DNS working
- Verify expected IP address is correct
- Check response time thresholds aren't too strict
- Test DNS query manually: `dig @10.10.10.22 ser8.lan`

### No alerts received
- Check notification rules are activated
- Verify email/contact configuration
- Check contact groups include your user
- Test notifications: Setup → Notifications → Test notification

## Quick Commands for Manual Testing

```bash
# Test all DNS servers
for dns in 10.10.10.4 10.10.10.2 10.10.10.22 10.10.10.23; do
    echo "=== Testing $dns ==="
    dig @$dns proxmox.lan +short
done

# Check DNS service status
ssh brian@10.10.10.4 "systemctl status bind9"
ssh brian@10.10.10.22 "systemctl status pihole-FTL"
ssh brian@10.10.10.2 "sudo docker ps | grep -E 'bind9|pihole'"

# Check DNS query logs
ssh brian@10.10.10.22 "pihole -t"
ssh brian@10.10.10.4 "sudo journalctl -u bind9 -f"
```

## Reference Links

- Checkmk Active Checks Documentation: https://docs.checkmk.com/latest/en/active_checks.html
- DNS Check Plugin: https://docs.checkmk.com/latest/en/check_dns.html
- Notification Setup: https://docs.checkmk.com/latest/en/notifications.html

---

**Status:** ⏳ Pending configuration in Checkmk web UI
**Next Steps:** Log into Checkmk and follow Part 1-5 above
**Estimated Time:** 30-45 minutes
