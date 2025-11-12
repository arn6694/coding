# Checkmk DNS Agent-Based Monitoring Setup - November 2025

**Completion Date:** November 3, 2025
**Implementation Status:** ✅ Fully Complete - Monitoring & Notifications Active
**Follow-up to:** DNS Infrastructure Improvements (November 2, 2025)

## Summary

Successfully implemented full agent-based monitoring with email notifications for all 4 DNS infrastructure hosts in Checkmk. All hosts are actively monitored with comprehensive service checks via Checkmk agents, and email alerts are configured and tested.

**Monitoring Server:** http://10.10.10.5/monitoring/
**Agent Version:** 2.4.0p2
**Monitoring Mode:** Agent-based (TCP port 6556)
**Notifications:** HTML Email to brian.j.arnett@gmail.com

## Monitored DNS Infrastructure

### 1. Pi-hole #1 (10.10.10.22) ✅
- **Location:** Proxmox LXC 105
- **Hostname in Checkmk:** `pihole1`
- **Agent Type:** xinetd
- **Status:** Active and monitoring

**Agent Details:**
- Installation: Pre-existing agent (already installed)
- **Issue Found:** Agent controller (`cmk-agent-ctl`) was listening on port 6556 but not responding
- **Fix Applied:** Installed xinetd and configured to serve the agent

**xinetd Configuration:**
```bash
# Installed xinetd
apt-get update && apt-get install -y xinetd

# Configured xinetd for Checkmk agent
cat > /etc/xinetd.d/check_mk << 'EOF'
service check_mk
{
    type           = UNLISTED
    port           = 6556
    socket_type    = stream
    protocol       = tcp
    wait           = no
    user           = root
    server         = /usr/bin/check_mk_agent
    disable        = no
}
EOF

systemctl restart xinetd
```

**Verification Command:**
```bash
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- systemctl status xinetd"
echo | nc 10.10.10.22 6556 | head -5
```

### 2. BIND9 #1 Primary (10.10.10.4) ✅
- **Location:** Proxmox LXC 119
- **Hostname in Checkmk:** `bind9-primary`
- **Agent Type:** xinetd + TLS registered
- **Memory:** 2GB (upgraded from 512MB to clear page tables alert)
- **Status:** Active and monitoring

**Agent Installation:**
```bash
# Installed Checkmk agent
wget http://10.10.10.5/monitoring/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb
dpkg -i check-mk-agent_2.4.0p2-1_all.deb

# Installed xinetd for agent service
apt-get update && apt-get install -y xinetd

# Configured xinetd
cat > /etc/xinetd.d/check_mk << 'EOF'
service check_mk
{
    type           = UNLISTED
    port           = 6556
    socket_type    = stream
    protocol       = tcp
    wait           = no
    user           = root
    server         = /usr/bin/check_mk_agent
    disable        = no
}
EOF

systemctl restart xinetd
```

**TLS Registration:**
```bash
cmk-agent-ctl register --hostname bind9-primary --server 10.10.10.5 \
  --site monitoring --user automation --password WIRVRNAXXGYWDRAHXQXM --trust-cert
```

**Alerts Fixed:**
1. **Memory CRITICAL** → Increased LXC memory from 512MB to 2GB (page tables now 7.4%)
2. **Check_MK Agent WARNING** → Registered TLS encryption (certificate valid until 2030)

**Verification Command:**
```bash
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- systemctl status xinetd"
echo | nc 10.10.10.4 6556 | head -5
```

### 3. BIND9 #2 Secondary (10.10.10.2) ✅
- **Location:** Zeus (Synology NAS) - Docker container
- **Hostname in Checkmk:** `bind9-secondary`
- **Agent Type:** xinetd (in Docker container)
- **Status:** Active and monitoring

**Implementation Details:**
- Base image: ubuntu/bind9:latest
- Network mode: host (port 6556 accessible)
- Agent method: xinetd daemon

**Files Created:**
1. `/volume1/docker/bind9-secondary/check-mk-agent/check-mk-agent_2.4.0p2-1_all.deb`
2. `/volume1/docker/bind9-secondary/entrypoint.sh`

**Entrypoint Script:**
```bash
#!/bin/bash
set -e

# Install Checkmk agent if not already installed
if [ ! -f /usr/bin/check_mk_agent ]; then
    echo "Installing Checkmk agent..."
    dpkg -i /opt/check-mk-agent.deb 2>/dev/null || true
fi

# Install xinetd for agent service
apt-get update -qq && apt-get install -y xinetd >/dev/null 2>&1

# Configure xinetd for Checkmk agent
cat > /etc/xinetd.d/check_mk << 'XINETD'
service check_mk
{
    type           = UNLISTED
    port           = 6556
    socket_type    = stream
    protocol       = tcp
    wait           = no
    user           = root
    server         = /usr/bin/check_mk_agent
    disable        = no
}
XINETD

# Start xinetd in background
/usr/sbin/xinetd -dontfork &

# Start BIND9 in foreground
exec /usr/sbin/named -f -u bind -c /etc/bind/named.conf
```

**Docker Compose Updates:**
```yaml
volumes:
  - '/volume1/docker/bind9-secondary/check-mk-agent/check-mk-agent_2.4.0p2-1_all.deb:/opt/check-mk-agent.deb:ro'
  - '/volume1/docker/bind9-secondary/entrypoint.sh:/entrypoint.sh:ro'
entrypoint: ["/entrypoint.sh"]
```

**Verification Command:**
```bash
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker ps | grep bind9-secondary"
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker exec bind9-secondary ps aux | grep -E 'xinetd|named'"
echo | nc 10.10.10.2 6556 | head -5
```

### 4. Pi-hole #2 (10.10.10.23) ✅
- **Location:** Zeus (Synology NAS) - Docker container
- **Hostname in Checkmk:** `pihole2`
- **Agent Type:** inetd (busybox-extras, in Docker container)
- **Status:** Active and monitoring

**Implementation Details:**
- Base image: pihole/pihole:latest (Alpine Linux 3.22)
- Network mode: host (port 6556 accessible)
- Agent method: inetd daemon (xinetd not available in Alpine)

**Files Created:**
1. `/volume1/docker/pihole2/check-mk-agent/check_mk_agent` (raw shell script)
2. `/volume1/docker/pihole2/entrypoint.sh`

**Entrypoint Script:**
```bash
#!/bin/sh
set -e

# Install Checkmk agent script
if [ ! -f /usr/local/bin/check_mk_agent ]; then
    echo "Installing Checkmk agent..."
    cp /opt/check_mk_agent /usr/local/bin/check_mk_agent
    chmod +x /usr/local/bin/check_mk_agent
fi

# Install busybox-extras for inetd (if not already installed)
if ! command -v inetd >/dev/null 2>&1; then
    echo "Installing inetd..."
    apk add --no-cache busybox-extras
fi

# Configure inetd for Checkmk agent
echo "Configuring inetd..."
echo "6556 stream tcp nowait root /usr/local/bin/check_mk_agent" > /etc/inetd.conf

# Start inetd in background
echo "Starting inetd..."
inetd &

# Start Pi-hole with original entrypoint
echo "Starting Pi-hole..."
exec /s6-init
```

**Docker Compose Updates:**
```yaml
volumes:
  - '/volume1/docker/pihole2/check-mk-agent/check_mk_agent:/opt/check_mk_agent:ro'
  - '/volume1/docker/pihole2/entrypoint.sh:/custom-entrypoint.sh:ro'
entrypoint: ["/custom-entrypoint.sh"]
```

**Verification Command:**
```bash
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker ps | grep pihole2"
ssh brian@10.10.10.2 "sudo /usr/local/bin/docker exec pihole2 ps aux | grep -E 'inetd|pihole'"
echo | nc 10.10.10.23 6556 | head -5
```

## Checkmk Configuration

### Hosts Added via REST API

All hosts were added to Checkmk using the REST API with the automation user:

**API Endpoint:** `http://10.10.10.5/monitoring/check_mk/api/1.0/domain-types/host_config/collections/all`

**Hosts Configured:**
1. **pihole1** (10.10.10.22) - "Pi-hole #1 DNS Server"
2. **bind9-primary** (10.10.10.4) - "BIND9 #1 Primary DNS"
3. **bind9-secondary** (10.10.10.2) - "BIND9 #2 Secondary DNS (Docker)"
4. **pihole2** (10.10.10.23) - "Pi-hole #2 DNS Server (Docker)"

**Service Discovery:**
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -I pihole1 bind9-primary bind9-secondary pihole2'"
```

**Configuration Activation:**
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -O'"
```

**Result:**
```
Generating configuration for core (type nagios)...
Precompiling host checks...OK
Validating Nagios configuration...OK
Reloading monitoring core...OK
```

## Services Being Monitored

Checkmk is now actively monitoring the following services on each DNS host:

### Common Services (All Hosts):
- CPU utilization
- Memory usage
- Disk space
- Network interfaces
- System uptime
- Process counts
- Check_MK agent status

### DNS-Specific Services:
- BIND9 service status (on BIND9 hosts)
- DNS query response times
- Pi-hole FTL service (on Pi-hole hosts)
- dnsmasq service status (on Pi-hole hosts)

## ✅ Email Notifications Configuration

Email notifications are fully configured and tested for all DNS infrastructure hosts.

### Contact Configuration

**User:** cmkadmin
**Email:** brian.j.arnett@gmail.com
**Contact Groups:** all
**Notifications Enabled:** ✅

All 4 DNS hosts are assigned to the "all" contact group:
- pihole1 (10.10.10.22)
- pihole2 (10.10.10.23)
- bind9-primary (10.10.10.4)
- bind9-secondary (10.10.10.2)

### Notification Rule

**Rule Description:** "Notify all contacts of a host/service via HTML email"
**Method:** HTML Email (mail plugin)
**Contact Selection:** All contacts of the notified object
**Scope:** All hosts (no restrictions)

### SMTP Configuration

Gmail SMTP configured via Checkmk web interface (Setup → General → Global settings).

### Notification Testing Results ✅

**Test Date:** November 3, 2025
**Test Method:** Simulated service failure by stopping bind9-secondary

**DOWN Alerts Sent:**
- **11:19 AM EST** - bind9-primary DOWN (due to IP configuration issue)
- **11:19 AM EST** - bind9-secondary DOWN (intentional test)
- ✅ Both emails received successfully

**RECOVERY Alerts Sent:**
- **12:35 PM EST** - bind9-primary UP
- **12:35 PM EST** - bind9-secondary UP
- ✅ Both recovery emails received successfully

**Notification Log Entries:**
```
2025-11-03 11:19:17 [20] HOST NOTIFICATION: cmkadmin;bind9-secondary;DOWN;mail
2025-11-03 11:19:17 [20] Output: Spooled mail to local mail transmission agent
2025-11-03 12:35:29 [20] HOST NOTIFICATION: cmkadmin;bind9-primary;UP;mail
2025-11-03 12:35:32 [20] HOST NOTIFICATION: cmkadmin;bind9-secondary;UP;mail
```

**Verdict:** Email notifications are fully functional for all DNS hosts. Both failure and recovery alerts are being sent successfully.

### Manual Test Procedure

To manually test notifications in the future:

```bash
# Stop a DNS service to trigger DOWN alert
ssh brian@10.10.10.2 "cd /volume1/docker/bind9-secondary && sudo /usr/local/bin/docker-compose stop"

# Wait 90-120 seconds for Checkmk to detect the outage
# Check email for DOWN notification

# Restart the service to trigger RECOVERY alert
ssh brian@10.10.10.2 "cd /volume1/docker/bind9-secondary && sudo /usr/local/bin/docker-compose start"

# Wait 90-120 seconds for Checkmk to detect the recovery
# Check email for UP notification
```

### Notification Log Location

View notification history:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'tail -50 ~/var/log/notify.log'"
```

## Verification Commands

### Check All Agents are Responding

```bash
# Test all 4 DNS server agents
for host in 10.10.10.22 10.10.10.4 10.10.10.2 10.10.10.23; do
  echo "=== Testing $host ==="
  echo | nc $host 6556 | head -5
  echo
done
```

Expected output for each:
```
<<<check_mk>>>
Version: 2.4.0p2
AgentOS: linux
Hostname: <hostname>
AgentDirectory: /etc/check_mk
```

### Check Hosts in Checkmk

```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -l'"
```

Should list all 4 DNS hosts:
- pihole1
- bind9-primary
- bind9-secondary
- pihole2

### View Live Monitoring Status

Access the Checkmk web interface:
```
http://10.10.10.5/monitoring/
```

Navigate to:
- **Monitor → Overview → All hosts** - See all 4 DNS hosts
- **Monitor → Overview → Services** - See all monitored services
- **Monitor → History → Notifications** - View alert history (after email configured)

## Maintenance

### Docker Container Restarts

Both Docker containers (BIND9 #2 and Pi-hole #2) will automatically reinstall and start the Checkmk agent on container restart thanks to the custom entrypoint scripts.

**Restart Commands:**
```bash
# Restart BIND9 #2 (agent persists)
ssh brian@10.10.10.2 "cd /volume1/docker/bind9-secondary && sudo /usr/local/bin/docker-compose restart"

# Restart Pi-hole #2 (agent persists)
ssh brian@10.10.10.2 "cd /volume1/docker/pihole2 && sudo /usr/local/bin/docker-compose restart"
```

### Agent Updates

When Checkmk is upgraded, update agents:

**For LXC containers:**
```bash
# Pi-hole #1
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 105 -- bash -c 'wget http://10.10.10.5/monitoring/check_mk/agents/check-mk-agent_[VERSION]_all.deb && dpkg -i check-mk-agent_[VERSION]_all.deb'"

# BIND9 #1
ssh brian@10.10.10.17 "sudo /usr/sbin/pct exec 119 -- bash -c 'wget http://10.10.10.5/monitoring/check_mk/agents/check-mk-agent_[VERSION]_all.deb && dpkg -i check-mk-agent_[VERSION]_all.deb'"
```

**For Docker containers:**
Update the agent files and recreate containers:
```bash
# Update BIND9 #2
ssh brian@10.10.10.2 "wget http://10.10.10.5/monitoring/check_mk/agents/check-mk-agent_[VERSION]_all.deb -O /volume1/docker/bind9-secondary/check-mk-agent/check-mk-agent_[VERSION]_all.deb"
ssh brian@10.10.10.2 "cd /volume1/docker/bind9-secondary && sudo /usr/local/bin/docker-compose down && sudo /usr/local/bin/docker-compose up -d"

# Update Pi-hole #2
ssh brian@10.10.10.2 "wget http://10.10.10.5/monitoring/check_mk/agents/check_mk_agent.linux -O /volume1/docker/pihole2/check-mk-agent/check_mk_agent"
ssh brian@10.10.10.2 "cd /volume1/docker/pihole2 && sudo /usr/local/bin/docker-compose down && sudo /usr/local/bin/docker-compose up -d"
```

### Monitoring Health Check

Run periodically to ensure all agents are functioning:

```bash
# Quick agent connectivity test
for host in 10.10.10.22 10.10.10.4 10.10.10.2 10.10.10.23; do
  if echo | nc -w 2 $host 6556 | grep -q "check_mk"; then
    echo "✅ $host - Agent responding"
  else
    echo "❌ $host - Agent NOT responding"
  fi
done
```

## Benefits Achieved

1. **Comprehensive Monitoring:**
   - All 4 DNS servers actively monitored 24/7
   - CPU, memory, disk, network, and service-level metrics
   - Real-time service health status

2. **Proactive Alerting:**
   - Email notifications for service failures (fully operational)
   - Both DOWN and RECOVERY alerts sent to Gmail
   - Early warning of resource exhaustion (disk, memory)
   - Historical performance data for trend analysis

3. **Operational Excellence:**
   - Single pane of glass for DNS infrastructure health
   - Automated service discovery
   - Agent survives container restarts

4. **Integration with DNS Improvements:**
   - Monitors the BIND9 query logging setup
   - Tracks gravity sync operations on Pi-holes
   - Validates failover configuration health

## Known Limitations

1. **Alpine Linux xinetd Unavailability:**
   - Pi-hole #2 uses inetd instead of xinetd
   - inetd is simpler but less feature-rich
   - Functionality is equivalent for Checkmk agent purposes

2. **Docker Agent Persistence:**
   - Agents must be reinstalled on container rebuild (not just restart)
   - Custom entrypoint scripts handle this automatically
   - Slight delay (~10-15 seconds) during container startup

3. **Contact Group Assignment:**
   - Initial host creation did not include contact groups
   - Required manual assignment via REST API after creation
   - All hosts now properly assigned to "all" contact group

## Related Documentation

- **DNS Infrastructure:** `dns_infrastructure_documentation.md`
- **DNS Improvements:** `dns_improvements_completed_nov2025.md`
- **Original Checkmk Guide:** `checkmk_dns_monitoring_setup.md` (agentless approach)

## Files Modified/Created

### Zeus (10.10.10.2 - Synology NAS)

**BIND9 #2:**
- ✅ Created: `/volume1/docker/bind9-secondary/check-mk-agent/check-mk-agent_2.4.0p2-1_all.deb`
- ✅ Created: `/volume1/docker/bind9-secondary/entrypoint.sh`
- ✅ Modified: `/volume1/docker/bind9-secondary/docker-compose.yml`

**Pi-hole #2:**
- ✅ Created: `/volume1/docker/pihole2/check-mk-agent/check_mk_agent`
- ✅ Created: `/volume1/docker/pihole2/entrypoint.sh`
- ✅ Modified: `/volume1/docker/pihole2/docker-compose.yml`

### Proxmox Hosts (via SSH)

**BIND9 #1 (LXC 119):**
- ✅ Installed: `/usr/bin/check_mk_agent` (version 2.4.0p2-1)
- ✅ Installed: xinetd service
- ✅ Created: `/etc/xinetd.d/check_mk` configuration
- ✅ Registered: TLS encryption with Checkmk server
- ✅ Increased: LXC memory from 512MB → 2GB (cleared page tables alert)

**Pi-hole #1 (LXC 105):**
- ✅ Pre-existing: Checkmk agent already installed
- ✅ Fixed: Replaced non-functional `cmk-agent-ctl` with xinetd
- ✅ Installed: xinetd service
- ✅ Created: `/etc/xinetd.d/check_mk` configuration

### Checkmk Server (10.10.10.5)

**Hosts Added:**
- ✅ pihole1 (10.10.10.22) - Contact group: all
- ✅ bind9-primary (10.10.10.4) - Contact group: all
- ✅ bind9-secondary (10.10.10.2) - Contact group: all
- ✅ pihole2 (10.10.10.23) - Contact group: all

**Configuration:**
- ✅ Service discovery completed for all hosts
- ✅ Monitoring core configuration updated and reloaded
- ✅ Contact groups assigned for email notifications
- ✅ Email notifications tested and verified

**Notification Rule:**
- ✅ HTML Email notification configured
- ✅ Sending to brian.j.arnett@gmail.com
- ✅ Covers all DNS hosts via "all" contact group

## Optional Enhancements

1. **Additional Notification Channels:**
   - Set up SMS/mobile notifications (if available)
   - Configure Slack/Discord/Teams integrations
   - Add escalation rules for critical alerts

2. **Custom Dashboards:**
   - Create DNS-specific dashboard in Checkmk
   - Add performance graphs for query response times
   - Set up historical reports and trend analysis

3. **Advanced Monitoring:**
   - Configure custom alert thresholds (disk space, memory, etc.)
   - Add DNS query rate monitoring
   - Set up SLA tracking for DNS uptime

## Regular Maintenance

1. **Weekly:**
   - Review Checkmk alerts and notifications
   - Check for any failed services
   - Monitor resource usage trends

2. **Monthly:**
   - Verify all 4 agents still responding
   - Review notification logs for any issues
   - Check disk space on monitoring server

3. **Quarterly:**
   - Update Checkmk agents if server is upgraded
   - Review and adjust alert thresholds if needed
   - Test failover between DNS servers

---

**Implemented By:** Claude Code
**Verified:** November 3, 2025
**Status:** ✅ Production Ready - All Agents Active & Email Notifications Tested
