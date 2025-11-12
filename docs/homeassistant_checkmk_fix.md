# Home Assistant Checkmk Monitoring Fix

## Problem
Home Assistant host at 10.10.10.6 was showing as "stale" in Checkmk monitoring. The agent was not installed and an old SSH datasource rule was pointing to an incorrect IP address (10.10.10.80).

## Environment
- **Home Assistant**: 10.10.10.6 (Alpine Linux 3.22.0, ARM64, Home Assistant OS)
- **Checkmk Server**: 10.10.10.5 (Debian 12, Checkmk 2.4.0p2)
- **Monitoring Site**: monitoring
- **Host Name in Checkmk**: homeassistant

## Solution Steps

### 1. Install Checkmk Agent on Home Assistant

Home Assistant OS doesn't support the standard Checkmk agent package, so we used the standalone Linux agent script.

```bash
# From Checkmk server, copy agent to Home Assistant
ssh brian@10.10.10.5 "cat /omd/sites/monitoring/share/check_mk/agents/check_mk_agent.linux" | \
ssh root@10.10.10.6 "cat > /usr/local/bin/check_mk_agent && chmod +x /usr/local/bin/check_mk_agent"
```

Verify agent works:
```bash
ssh root@10.10.10.6 "/usr/local/bin/check_mk_agent"
```

### 2. Set Up SSH Key Authentication

Generate SSH key for monitoring user (if not already exists):
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'ssh-keygen -t rsa -N \"\" -f ~/.ssh/id_rsa'"
```

Get the public key:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cat ~/.ssh/id_rsa.pub'"
```

Add the public key to Home Assistant:
```bash
ssh root@10.10.10.6 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEbttoM/VR/o7v9mQ26ku7VS0dCvGgbzp0/qTP40AeIJ/EZJj/8WkrW8KfbwXC+MOX8U1w84e8JD+7oGTQzrIF+JJQ25cPgNZmse2D0dmALAW7Ijf4qPVVx3ms3iTl2QDmyF5YGZdRyR6Gj8V7NP8Uiq+rdVrZ5GhPb5i0Hd9Dy/q2emu6wco9Rsm8++6j/TFGolEwBoSKtGHTwJ0WLpZ42LlJi0GNPxLyc1WG3DoOKG1KLY5UAHNpQaNxM0VmdRBu1IyDYAjJKHWl67Bs8Jm6ofTgOC2eYBmBjVVpWCC8wyhbqIsDrSr89hRggie80H6dEo4zPeYqnvC+TCaLIYsLKSMOSNJrXQCAozsBZPC/1q7SBCYriNgqZDtX6px1V3xExBTXdROPY81lkOxB7TczMFeQknfOKItvTXmnV2uWKSzLW0Dk9EnChmIKFZ3/aaCI8pCuEhYTYfdzUx+MHH2JTMpwIrcwtVLFDK1+MNnwxvJJ2pXEe8YRWfWSUqzOLgs= monitoring@valheim' >> ~/.ssh/authorized_keys && \
chmod 600 ~/.ssh/authorized_keys"
```

Test SSH connection:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'ssh -o StrictHostKeyChecking=no root@10.10.10.6 /usr/local/bin/check_mk_agent | head -20'"
```

### 3. Remove Old Incorrect SSH Rule

The old rule was pointing to the wrong IP (10.10.10.80). First, find the rule ID:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'grep -r \"10.10.10.80\" ~/etc/check_mk/conf.d/'"
```

Delete the old rule via API:
```bash
ssh brian@10.10.10.5 "curl -X DELETE 'http://localhost/monitoring/check_mk/api/1.0/objects/rule/30e14317-d4ed-465b-898b-96519fa8602c' \
  -H 'Authorization: Bearer automation WIRVRNAXXGYWDRAHXQXM'"
```

### 4. Create SSH Datasource Rule

Create a new datasource program rule that tells Checkmk to use SSH to fetch agent data:

```bash
ssh brian@10.10.10.5 "curl -X POST 'http://localhost/monitoring/check_mk/api/1.0/domain-types/rule/collections/all' \
  -H 'Authorization: Bearer automation WIRVRNAXXGYWDRAHXQXM' \
  -H 'Content-Type: application/json' \
  -d '{
    \"ruleset\": \"datasource_programs\",
    \"folder\": \"/\",
    \"properties\": {
      \"disabled\": false
    },
    \"value_raw\": \"\\\"ssh -o StrictHostKeyChecking=no root@\$HOSTADDRESS\$ /usr/local/bin/check_mk_agent\\\"\",
    \"conditions\": {
      \"host_name\": {
        \"match_on\": [\"homeassistant\"],
        \"operator\": \"one_of\"
      }
    }
  }'"
```

**Key Points:**
- Uses `$HOSTADDRESS$` macro to dynamically use the IP configured in Checkmk (10.10.10.6)
- `StrictHostKeyChecking=no` prevents SSH from prompting about host keys
- Applies only to the "homeassistant" host

### 5. Activate Configuration and Discover Services

Activate the configuration changes:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -O'"
```

Test the agent connection:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d homeassistant'"
```

Discover services on the host:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -v --discover homeassistant && cmk -O'"
```

## Results

After applying the fix:
- ✅ Home Assistant agent responding correctly via SSH
- ✅ Host no longer showing as "stale"
- ✅ 10 services discovered and monitored:
  - Checkmk Agent status
  - CPU utilization
  - Memory usage
  - Disk statistics
  - 3 Network interfaces
  - File system mounts
  - TCP connection statistics
  - System uptime
- ✅ 6 host labels automatically detected

## Verification

To verify the fix is working:

1. **Check agent output directly:**
   ```bash
   ssh root@10.10.10.6 /usr/local/bin/check_mk_agent
   ```

2. **Check via Checkmk:**
   ```bash
   ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -d homeassistant'"
   ```

3. **Check in Web UI:**
   - Navigate to: http://10.10.10.5/monitoring/
   - Look for "homeassistant" host
   - Verify host is UP (green) and services are OK

## Maintenance Notes

### Agent Persistence
Home Assistant OS runs in a containerized environment. The agent installed at `/usr/local/bin/check_mk_agent` should persist across reboots, but if Home Assistant OS is upgraded, you may need to reinstall the agent.

### SSH Key Persistence
The SSH authorized_keys file should persist across Home Assistant updates. If SSH connection fails after an update, verify the key is still in `/root/.ssh/authorized_keys`.

### Updating the Agent
When upgrading Checkmk server, you may need to update the agent on Home Assistant:
```bash
ssh brian@10.10.10.5 "cat /omd/sites/monitoring/share/check_mk/agents/check_mk_agent.linux" | \
ssh root@10.10.10.6 "cat > /usr/local/bin/check_mk_agent && chmod +x /usr/local/bin/check_mk_agent"
```

Then rediscover services:
```bash
ssh brian@10.10.10.5 "sudo su - monitoring -c 'cmk -v --discover homeassistant && cmk -O'"
```

## Alternative: Agent Controller (Not Used)

Home Assistant OS doesn't support the modern Checkmk agent controller package due to its minimalist Alpine Linux base. The SSH-based monitoring approach is the recommended method for Home Assistant OS.

## Summary

This fix enables Checkmk to monitor Home Assistant by:
1. Installing the standalone Checkmk agent script
2. Using SSH-based agent fetching (instead of the standard agent port 6556)
3. Configuring proper authentication and datasource rules

This approach is suitable for minimal Linux systems that don't support the full Checkmk agent package.

---
**Document Created:** 2025-10-29
**Checkmk Version:** 2.4.0p2
**Home Assistant OS:** Alpine Linux 3.22.0 (ARM64)
