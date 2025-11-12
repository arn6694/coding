# Checkmk Email Configuration Quick Reference

## Problem
After server restore, Checkmk notifications were queued but emails weren't sending. Port 25 blocked, no SMTP relay configured, missing SASL modules.

## Solution - Gmail SMTP Relay Setup

### 1. Install SASL modules
```bash
sudo apt-get update
sudo apt-get install -y libsasl2-modules
```

### 2. Configure Postfix main.cf
```bash
sudo nano /etc/postfix/main.cf
```

Add to the end:
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

### 3. Create SASL password file
```bash
sudo mkdir -p /etc/postfix/sasl
sudo nano /etc/postfix/sasl/sasl_passwd
```

Add this line (replace with your Gmail App Password):
```
[smtp.gmail.com]:587 brian.j.arnett@gmail.com:your-app-password-here
```

### 4. Secure and hash the password file
```bash
sudo chmod 600 /etc/postfix/sasl/sasl_passwd
sudo postmap /etc/postfix/sasl/sasl_passwd
```

### 5. Restart Postfix
```bash
sudo postfix check
sudo systemctl restart postfix
```

### 6. Flush any queued mail
```bash
sudo postqueue -f
sudo mailq
```

## Verify It's Working
```bash
# Queue should be empty
sudo mailq

# Send test email
echo "Test" | mail -s "Test from Checkmk" brian.j.arnett@gmail.com

# Watch logs
sudo tail -f /var/log/mail.log
```

## Gmail App Password
1. Go to: https://myaccount.google.com/apppasswords
2. Enable 2-factor authentication if needed
3. Generate App Password for "Mail" > "Other (Checkmk)"
4. Use the 16-character password in sasl_passwd file

## Backup for Next Rebuild
```bash
sudo tar -czf postfix-config-backup.tar.gz \
  /etc/postfix/main.cf \
  /etc/postfix/sasl/sasl_passwd
```

## Restore on New Server
```bash
# Extract backup
sudo tar -xzf postfix-config-backup.tar.gz -C /

# Install SASL modules
sudo apt-get install -y libsasl2-modules

# Rehash password file
sudo postmap /etc/postfix/sasl/sasl_passwd

# Restart Postfix
sudo systemctl restart postfix
```

---
**Server:** 10.10.10.5 (checkmk.lan)
**Email:** brian.j.arnett@gmail.com
**Fixed:** 2025-10-29
