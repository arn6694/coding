  Complete DNS Edit Workflow

  Step 1: SSH into BIND9 Server

  ssh brian@10.10.10.4

  Step 2: Edit the Zone File

  sudo nano /etc/bind/zones/db.lan

  Step 3: Make Your Changes

  To add a new host:
  newhost         IN      A       10.10.10.XX

  To change an existing host's IP:
  Find the line and change the IP:
  # Change this:
  oldhost         IN      A       10.10.10.50

  # To this:
  oldhost         IN      A       10.10.10.60

  Step 4: Increment the Serial Number (CRITICAL!)

  Find the serial number near the top:
  @       IN      SOA     dns1.lan. admin.lan. (
                                2025110301         ; Serial ← Change this!

  Increment it by 1:
  - If it's 2025110301, change to 2025110302
  - If it's 2025110302, change to 2025110303
  - Or use today's date: 2025110401 (for Nov 4th, revision 01)

  Step 5: Save and Exit

  - Press Ctrl+X
  - Press Y (to confirm save)
  - Press Enter (to confirm filename)

  Step 6: Validate the Zone File

  sudo named-checkzone lan /etc/bind/zones/db.lan

  Expected output:
  zone lan/IN: loaded serial 2025110302
  OK

  If you see errors, go back and fix them before proceeding!

  Step 7: Restart BIND9

  sudo systemctl restart named

  Step 8: Verify DNS is Working

  dig @localhost hostname.lan +short

  This should return the IP address you just set.

  Step 9: Flush Pi-hole Cache

  # Exit from BIND9 server first (Ctrl+D or type 'exit')

  # Then from your workstation:
  ssh brian@10.10.10.22 "sudo pihole reloaddns && sudo unbound-control flush_zone lan"

  Step 10: Test from Your Workstation

  dig hostname.lan +short
  ping hostname.lan

  ---
  Quick Reference Card

  1. ssh brian@10.10.10.4
  2. sudo nano /etc/bind/zones/db.lan
  3. Make changes + INCREMENT SERIAL NUMBER
  4. Ctrl+X, Y, Enter
  5. sudo named-checkzone lan /etc/bind/zones/db.lan
  6. sudo systemctl restart named
  7. dig @localhost hostname.lan +short
  8. ssh brian@10.10.10.22 "sudo pihole reloaddns && sudo unbound-control flush_zone lan"
  9. Test: dig hostname.lan +short

  ---
  Common Mistakes to Avoid

  ❌ Forgot to increment serial → Changes won't load❌ Used rndc reload instead of systemctl restart named →
  Sometimes doesn't work❌ Forgot to flush Pi-hole cache → DNS still shows old data❌ Typos in hostname → DNS
  won't resolve❌ Missing periods after domain names in SOA → Zone file syntax error

  ---
  Save this as a reference! Every time you need to update DNS, just follow these 10 steps in order.


