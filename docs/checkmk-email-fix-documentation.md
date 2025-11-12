# Checkmk Email Notification Fix Documentation

## Date: October 29, 2025
## Issue: Checkmk email notifications not being delivered

---

## Problem Summary

After restoring a Checkmk server backup to a new server (10.10.10.5), email notifications stopped working. The Checkmk notification system was functioning correctly and queuing emails to Postfix, but the emails were not being delivered to recipients.

---

## Root Cause Analysis

### Symptoms
- Checkmk logs showed successful notification execution: `Spooled mail to local mail transmission agent`
- 13 emails were stuck in the Postfix mail queue
- Mail queue errors showed connection timeouts

### Issues Identified

1. **Port 25 Blocked**
   - Postfix was attempting direct delivery to Gmail's MX servers on port 25
   - Connection attempts timed out: `connect to alt2.gmail-smtp-in.l.google.com[173.194.76.26]:25: Connection timed out`
   - Port 25 is commonly blocked by ISPs and cloud providers

2. **Missing SMTP Relay Configuration**
   - Postfix `relayhost` parameter was empty
   - No SMTP relay server configured

3. **Missing SASL Authentication Library**
   - `libsasl2-modules` package was not installed
   - Error: `SASL authentication failed; cannot authenticate to server smtp.gmail.com: no mechanism available`

4. **IPv6 Connectivity Issues**
   - Postfix was attempting IPv6 connections first
   - Error: `connect to smtp.gmail.com[2607:f8b0:4004:c07::6c]:587: Network is unreachable`

---

## Solution Implementation

### Prerequisites
- Gmail account with 2-factor authentication enabled
- Gmail App Password generated (not regular Gmail password)
- SSH access to Checkmk server

### Step 1: Configure Postfix for Gmail SMTP Relay

Edit `/etc/postfix/main.cf` and add the following configuration:

```bash
sudo nano /etc/postfix/main.cf
```

Add these lines to the bottom of the file:

```
# Gmail SMTP Relay Configuration
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_use_tls = yes
smtp_address_preference = ipv4
```

**Configuration Explanation:**
- `relayhost = [smtp.gmail.com]:587` - Use Gmail's SMTP server on port 587 (submission port)
- `smtp_sasl_auth_enable = yes` - Enable SASL authentication
- `smtp_sasl_password_maps` - Path to the hashed password file
- `smtp_sasl_security_options = noanonymous` - Require authenticated connections
- `smtp_tls_CAfile` - CA certificate bundle for TLS verification
- `smtp_use_tls = yes` - Enable TLS encryption
- `smtp_address_preference = ipv4` - Prefer IPv4 connections (fixes IPv6 issues)

### Step 2: Install SASL Authentication Modules

```bash
sudo apt-get update
sudo apt-get install -y libsasl2-modules
```

This package provides the necessary SASL authentication mechanisms for Postfix.

### Step 3: Create SASL Password File

Create the directory if it doesn't exist:

```bash
sudo mkdir -p /etc/postfix/sasl
```

Create the password file:

```bash
sudo nano /etc/postfix/sasl/sasl_passwd
```

Add your Gmail credentials (replace with your actual email and App Password):

```
[smtp.gmail.com]:587 your-email@gmail.com:your-app-password
```

**Example:**
```
[smtp.gmail.com]:587 brian.j.arnett@gmail.com:wxnm snet puru arpt
```

**Security Note:** This file will contain your Gmail App Password in plain text initially. We'll secure it in the next step.

### Step 4: Secure and Hash the Password File

Set restrictive permissions (readable only by root):

```bash
sudo chmod 600 /etc/postfix/sasl/sasl_passwd
```

Create the hashed database file:

```bash
sudo postmap /etc/postfix/sasl/sasl_passwd
```

This creates `/etc/postfix/sasl/sasl_passwd.db` which Postfix uses for authentication.

Verify the files were created:

```bash
sudo ls -la /etc/postfix/sasl/
```

Expected output:
```
-rw------- 1 root root    66 Oct 29 23:13 sasl_passwd
-rw------- 1 root root 12288 Oct 29 23:14 sasl_passwd.db
```

### Step 5: Validate and Restart Postfix

Test the Postfix configuration:

```bash
sudo postfix check
```

If no errors are displayed, restart Postfix:

```bash
sudo systemctl restart postfix
```

Verify Postfix is running:

```bash
sudo systemctl status postfix
```

### Step 6: Flush the Mail Queue

Send any queued emails:

```bash
sudo postqueue -f
```

Check the mail queue status:

```bash
sudo mailq
```

If successful, you should see: `Mail queue is empty`

### Step 7: Monitor Mail Logs

Watch the mail log in real-time to verify emails are being sent:

```bash
sudo tail -f /var/log/mail.log
```

Look for successful delivery messages:
```
status=sent (250 2.0.0 OK ... - gsmtp)
```

---

## Verification Steps

### 1. Check Mail Queue
```bash
sudo mailq
```
Should show: `Mail queue is empty`

### 2. Test Email Sending
Send a test email from the Checkmk server:

```bash
echo "Test email from Checkmk" | mail -s "Test Subject" your-email@gmail.com
```

### 3. Check Postfix Configuration
```bash
sudo postconf | grep -E '(relayhost|smtp_sasl|smtp_tls)'
```

Expected output should include:
```
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd
smtp_use_tls = yes
smtp_address_preference = ipv4
```

### 4. Verify SASL Modules
```bash
dpkg -l | grep libsasl2-modules
```

Should show the package is installed.

### 5. Test SMTP Connectivity
```bash
nc -zv smtp.gmail.com 587
```

Should show: `smtp.gmail.com [IP_ADDRESS] 587 (submission) open`

---

## Troubleshooting

### Issue: "SASL authentication failed: no mechanism available"

**Solution:** Install SASL modules
```bash
sudo apt-get install -y libsasl2-modules
sudo systemctl restart postfix
```

### Issue: "Network is unreachable" for IPv6

**Solution:** Prefer IPv4
```bash
sudo postconf -e 'smtp_address_preference = ipv4'
sudo systemctl restart postfix
```

### Issue: "Connection timed out" on port 587

**Check connectivity:**
```bash
telnet smtp.gmail.com 587
```

If this fails, your firewall or ISP may be blocking port 587.

### Issue: "Authentication failed" with valid credentials

**Possible causes:**
1. Using regular Gmail password instead of App Password
2. 2-factor authentication not enabled on Gmail account
3. App Password not generated or incorrect

**Solution:**
1. Go to Google Account settings
2. Enable 2-factor authentication
3. Generate a new App Password
4. Update `/etc/postfix/sasl/sasl_passwd` with new App Password
5. Run `sudo postmap /etc/postfix/sasl/sasl_passwd`
6. Restart Postfix: `sudo systemctl restart postfix`

### Issue: Emails go to spam

Gmail may flag emails from your server as spam if:
- SPF records are not configured
- DKIM is not configured
- PTR (reverse DNS) record is missing or incorrect

**Recommendations:**
1. Configure SPF records for your domain
2. Set up DKIM signing in Postfix
3. Ensure your server has a proper PTR record

---

## How to Generate a Gmail App Password

1. Go to your Google Account: https://myaccount.google.com/
2. Navigate to Security
3. Enable 2-Step Verification if not already enabled
4. Search for "App passwords" or go to: https://myaccount.google.com/apppasswords
5. Select app: "Mail"
6. Select device: "Other" (enter "Checkmk Server")
7. Click "Generate"
8. Copy the 16-character password (spaces don't matter)
9. Use this password in your `/etc/postfix/sasl/sasl_passwd` file

---

## Future Maintenance

### Updating Gmail Credentials

If you need to change the Gmail password or email address:

1. Edit the password file:
```bash
sudo nano /etc/postfix/sasl/sasl_passwd
```

2. Update the credentials

3. Rehash the password file:
```bash
sudo postmap /etc/postfix/sasl/sasl_passwd
```

4. Restart Postfix:
```bash
sudo systemctl restart postfix
```

### Backing Up Configuration

To preserve this configuration when migrating or backing up:

**Files to backup:**
- `/etc/postfix/main.cf` - Main Postfix configuration
- `/etc/postfix/sasl/sasl_passwd` - Gmail credentials (encrypted)

**Backup command:**
```bash
sudo tar -czf postfix-backup-$(date +%Y%m%d).tar.gz \
  /etc/postfix/main.cf \
  /etc/postfix/sasl/sasl_passwd
```

**Restore on new server:**
```bash
sudo tar -xzf postfix-backup-YYYYMMDD.tar.gz -C /
sudo postmap /etc/postfix/sasl/sasl_passwd
sudo apt-get install -y libsasl2-modules
sudo systemctl restart postfix
```

---

## Server Details

- **Checkmk Server:** 10.10.10.5 (checkmk.lan)
- **Checkmk Version:** 2.4.0p2.cre (OMD)
- **Site Name:** monitoring
- **OS:** Debian GNU/Linux 12 (Bookworm)
- **MTA:** Postfix
- **SMTP Relay:** Gmail (smtp.gmail.com:587)
- **Recipient:** brian.j.arnett@gmail.com

---

## Results

After implementing the fix:
- ✓ All 13 queued emails were successfully delivered
- ✓ Mail queue is empty
- ✓ Future notifications are working correctly
- ✓ Configuration persists across reboots
- ✓ Emails delivered with TLS encryption
- ✓ SASL authentication working properly

---

## Additional Resources

- [Postfix SASL Authentication](http://www.postfix.org/SASL_README.html)
- [Postfix TLS Support](http://www.postfix.org/TLS_README.html)
- [Gmail SMTP Settings](https://support.google.com/mail/answer/7126229)
- [Checkmk Notifications](https://docs.checkmk.com/latest/en/notifications.html)

---

## Notes

- This configuration uses Gmail's SMTP relay, which has sending limits (typically 500 emails per day for free accounts)
- For production environments with high email volume, consider using a dedicated SMTP service or running your own mail server
- The App Password method is more secure than using your main Gmail password
- TLS encryption ensures email contents are protected in transit
- The configuration is persistent and will survive server reboots

---

## Change Log

**2025-10-29:** Initial configuration completed
- Configured Postfix to relay through Gmail SMTP
- Installed libsasl2-modules
- Created and secured SASL password file
- Configured TLS encryption
- Set IPv4 preference
- Successfully delivered 13 queued emails
