# Checkmk Agent Update Guide: 2.3.0p24 → 2.4.0p2

## Overview

This guide covers updating Checkmk agents from version 2.3.0p24 to 2.4.0p2 to match the server version.

## Current Status

### Hosts Needing Updates (2.3.0p24 → 2.4.0p2)

| Host | IP | OS | Current Version | Status |
|------|----|----|----------------|---------|
| bookworm | 10.10.10.7 | Debian 12 | 2.3.0p24 | Needs Update |
| geekom | 10.10.10.9 | Windows 10 | 2.3.0p24 | Needs Update |
| ser8 | 10.10.10.96 | Linux 22.2 | 2.3.0p24 | Needs Update |
| jarvis | 10.10.10.49 | Ubuntu 24.04 | 2.3.0p24 | Needs Update |
| jellyfin | 10.10.10.42 | Ubuntu 22.04 | 2.3.0p24 | Needs Update |
| zeus | 10.10.10.2 | Linux | 2.3.0p24 | Needs Update |

### Hosts Already Updated

| Host | IP | Version | Notes |
|------|----|---------| ------|
| checkmk | 127.0.0.1 | 2.4.0p2 | Monitoring server |
| homeassistant | 10.10.10.6 | 2.4.0p2 | Updated via SSH (Alpine Linux) |

### Hosts with Connection Issues

| Host | Issue | Action Needed |
|------|-------|---------------|
| omv | No route to host | Check network connectivity |
| proxmox | TLS connection error | Check agent registration |
| zero | Connection refused | Check if agent is running |

---

## Update Methods

### Method 1: Linux Hosts (Debian/Ubuntu) - Automated

This is the recommended method for Debian-based systems that you can SSH into.

#### Step 1: Download Agent Packages

Agent packages are located on your Checkmk server at:
```
/omd/sites/monitoring/share/check_mk/agents/
```

Available packages:
- `check-mk-agent_2.4.0p2-1_all.deb` (Debian/Ubuntu)
- `check-mk-agent-2.4.0p2-1.noarch.rpm` (RHEL/CentOS/Rocky)

#### Step 2: Update Linux Hosts via SSH

**For bookworm (Debian 12):**
```bash
# Copy package to host
scp /omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb brian@10.10.10.7:/tmp/

# SSH to host and install
ssh brian@10.10.10.7
sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb
sudo systemctl restart check-mk-agent.socket
exit

# Verify from Checkmk server
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d bookworm | grep Version'"
```

**For jarvis (Ubuntu 24.04):**
```bash
scp /omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb brian@10.10.10.49:/tmp/
ssh brian@10.10.10.49 "sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb && sudo systemctl restart check-mk-agent.socket"
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d jarvis | grep Version'"
```

**For jellyfin (Ubuntu 22.04):**
```bash
scp /omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb brian@10.10.10.42:/tmp/
ssh brian@10.10.10.42 "sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb && sudo systemctl restart check-mk-agent.socket"
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d jellyfin | grep Version'"
```

**For ser8 (Linux 22.2):**
```bash
# Determine the distribution first
ssh brian@10.10.10.96 "cat /etc/os-release"

# If Debian/Ubuntu based:
scp /omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb brian@10.10.10.96:/tmp/
ssh brian@10.10.10.96 "sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb && sudo systemctl restart check-mk-agent.socket"

# If RPM based (Rocky/RHEL/CentOS):
scp /omd/sites/monitoring/share/check_mk/agents/check-mk-agent-2.4.0p2-1.noarch.rpm brian@10.10.10.96:/tmp/
ssh brian@10.10.10.96 "sudo rpm -U /tmp/check-mk-agent-2.4.0p2-1.noarch.rpm && sudo systemctl restart check-mk-agent.socket"

# Verify
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d ser8 | grep Version'"
```

**For zeus (Linux):**
```bash
# Determine OS first
ssh brian@10.10.10.2 "cat /etc/os-release"

# Use appropriate package (deb or rpm) based on OS
scp /omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb brian@10.10.10.2:/tmp/
ssh brian@10.10.10.2 "sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb && sudo systemctl restart check-mk-agent.socket"

# Verify
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d zeus | grep Version'"
```

---

### Method 2: Windows Hosts - Manual Installation

**For geekom (Windows 10):**

1. **Download the agent installer:**
   - Access your Checkmk web interface: http://10.10.10.5/monitoring/
   - Navigate to: **Setup → Agents → Windows**
   - Download: `check_mk_agent.msi` (2.4.0p2)

   Or via direct URL:
   ```
   http://10.10.10.5/monitoring/check_mk/agents/windows/check_mk_agent.msi
   ```

2. **On the Windows machine (geekom):**
   - Copy the downloaded `check_mk_agent.msi` to the Windows machine
   - Right-click and select "Run as Administrator"
   - Follow the installation wizard
   - The installer will automatically upgrade the existing agent
   - No need to uninstall the old version first

3. **Verify the update:**
   - On Windows, open PowerShell as Administrator:
     ```powershell
     Get-Service -Name "Check MK Agent" | Select-Object Status
     & "C:\Program Files (x86)\checkmk\service\check_mk_agent.exe" test
     ```

   - From Checkmk server:
     ```bash
     ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d geekom | grep Version'"
     ```

4. **Post-update steps:**
   - The agent service should restart automatically
   - If needed, manually restart: `Restart-Service "Check MK Agent"`

---

### Method 3: Bulk Update Script

For efficiency, you can use this script to update multiple Linux hosts at once:

```bash
#!/bin/bash
# bulk_agent_update.sh
# Run from your local machine

CHECKMK_SERVER="10.10.10.5"
AGENT_PKG="/omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb"

# List of hosts to update (hostname:ip:user)
HOSTS=(
    "bookworm:10.10.10.7:brian"
    "jarvis:10.10.10.49:brian"
    "jellyfin:10.10.10.42:brian"
    "ser8:10.10.10.96:brian"
    "zeus:10.10.10.2:brian"
)

echo "Checkmk Agent Bulk Update Script"
echo "=================================="
echo ""

for host_entry in "${HOSTS[@]}"; do
    IFS=':' read -r hostname ip user <<< "$host_entry"

    echo "Updating $hostname ($ip)..."

    # Copy package to host
    scp brian@$CHECKMK_SERVER:$AGENT_PKG /tmp/check-mk-agent_2.4.0p2-1_all.deb
    scp /tmp/check-mk-agent_2.4.0p2-1_all.deb $user@$ip:/tmp/

    # Install on remote host
    ssh $user@$ip "sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb && sudo systemctl restart check-mk-agent.socket"

    if [ $? -eq 0 ]; then
        echo "✓ $hostname updated successfully"
    else
        echo "✗ $hostname update failed"
    fi

    # Verify version
    ssh brian@$CHECKMK_SERVER "sudo su - monitoring -c 'cmk -d $hostname | grep Version'"
    echo ""
done

rm -f /tmp/check-mk-agent_2.4.0p2-1_all.deb
echo "Update complete!"
```

Save this as `bulk_agent_update.sh`, make it executable, and run:
```bash
chmod +x bulk_agent_update.sh
./bulk_agent_update.sh
```

---

## Verification Steps

After updating each host, verify the update was successful:

### 1. Check Individual Host from Checkmk Server
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d <hostname> | grep Version'"
```

Expected output:
```
Version: 2.4.0p2
```

### 2. Check All Hosts at Once
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'for host in bookworm geekom ser8 jarvis jellyfin zeus; do echo \"=== \$host ===\"; cmk -d \$host 2>&1 | grep -E \"Version:\" | head -1; done'"
```

### 3. Via Web Interface
1. Navigate to: http://10.10.10.5/monitoring/
2. Go to: **Monitor → Overview → All hosts**
3. Click on each host
4. Check the "Checkmk agent" service
5. Version should show: **2.4.0p2**

---

## Troubleshooting

### Issue: "Connection refused" or "No route to host"

**Check if agent service is running:**
```bash
# On the remote host
sudo systemctl status check-mk-agent.socket
sudo systemctl status cmk-agent-ctl-daemon.service
```

**Restart services:**
```bash
sudo systemctl restart check-mk-agent.socket
sudo systemctl restart cmk-agent-ctl-daemon.service
```

**Check firewall:**
```bash
# Ensure port 6556 is open
sudo ss -tlnp | grep 6556
```

### Issue: "TLS connection error" (like proxmox)

This means the agent needs to be re-registered with the server.

**Re-register the agent:**
```bash
# Get automation password from Checkmk server
AUTOMATION_PWD=$(ssh brian@10.10.10.5 "sudo -u monitoring cat /omd/sites/monitoring/var/check_mk/web/automation/automation.secret")

# On the host with TLS error (e.g., proxmox)
ssh root@10.10.10.17 "cmk-agent-ctl delete-all && cmk-agent-ctl register --hostname proxmox --server 10.10.10.5 --site monitoring --user automation --password $AUTOMATION_PWD --trust-cert"
```

### Issue: Package installation fails

**Check existing installation:**
```bash
dpkg -l | grep check-mk-agent
```

**Force reinstall if needed:**
```bash
sudo dpkg --purge check-mk-agent
sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb
```

### Issue: Agent shows old version after update

**Clear agent cache and force re-check:**
```bash
# On Checkmk server
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk --flush <hostname> && cmk -d <hostname> | grep Version'"
```

---

## Post-Update Tasks

### 1. Rediscover Services (Optional but Recommended)

After updating agents, you may want to rediscover services to pick up any new checks available in 2.4.0p2:

```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -v --discover <hostname> && cmk -O'"
```

Or bulk discovery:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'for host in bookworm geekom ser8 jarvis jellyfin zeus; do echo \"Discovering \$host\"; cmk -v --discover \$host; done && cmk -O'"
```

### 2. Check for New Services

In the web interface:
1. Navigate to: **Setup → Hosts → Hosts**
2. Select each updated host
3. Click "Services" → "Fix all"
4. Review any new or changed services
5. Activate changes

### 3. Review Agent Updates in 2.4

Checkmk 2.4 includes improvements to:
- Better performance for agent data processing
- Enhanced TLS security
- New monitoring plugins
- Improved Windows agent stability

---

## Important Notes

### Agent Compatibility
- Checkmk agents are backward compatible
- A 2.4.0p2 server can monitor 2.3.0p24 agents (but you'll miss new features)
- Recommended: Keep agents within 1-2 minor versions of the server

### Agent Registration
- Modern agents (2.0+) use TLS with registration
- If you see "insecure mode" warnings, use `cmk-agent-ctl register` to secure the connection
- Home Assistant uses SSH method and doesn't need registration

### Backup Consideration
Before bulk updates, consider:
1. Taking a backup of your Checkmk server configuration
2. Testing on 1-2 hosts first
3. Having a rollback plan if needed

### Network Devices
Network devices (Orbi routers, switches, cameras) monitored via SNMP don't have Checkmk agents and don't need updates.

---

## Quick Reference Commands

**Check all agent versions:**
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk --list-hosts | while read host; do echo -n \"\$host: \"; cmk -d \$host 2>&1 | grep \"Version:\" | head -1; done'"
```

**Update single Linux host (one-liner):**
```bash
HOST="bookworm"; IP="10.10.10.7"; scp brian@10.10.10.5:/omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb /tmp/ && scp /tmp/check-mk-agent_2.4.0p2-1_all.deb brian@$IP:/tmp/ && ssh brian@$IP "sudo dpkg -i /tmp/check-mk-agent_2.4.0p2-1_all.deb && sudo systemctl restart check-mk-agent.socket" && ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d $HOST | grep Version'"
```

**Restart agent on remote host:**
```bash
ssh brian@<host-ip> "sudo systemctl restart check-mk-agent.socket cmk-agent-ctl-daemon.service"
```

**Get automation password (for agent registration):**
```bash
ssh brian@10.10.10.5 "sudo -u monitoring cat /omd/sites/monitoring/var/check_mk/web/automation/automation.secret"
```

---

## Summary Checklist

- [ ] bookworm (10.10.10.7) - Linux agent updated
- [ ] geekom (10.10.10.9) - Windows agent updated
- [ ] ser8 (10.10.10.96) - Linux agent updated
- [ ] jarvis (10.10.10.49) - Linux agent updated
- [ ] jellyfin (10.10.10.42) - Linux agent updated
- [ ] zeus (10.10.10.2) - Linux agent updated
- [ ] All agents verified at version 2.4.0p2
- [ ] Services rediscovered on updated hosts
- [ ] Web UI checked - all hosts showing correct version
- [ ] Connection issues resolved (omv, proxmox, zero)

---

**Document Created:** 2025-10-29
**Server Version:** Checkmk 2.4.0p2
**Upgrading From:** 2.3.0p24
**Total Hosts Requiring Update:** 6 (5 Linux, 1 Windows)
