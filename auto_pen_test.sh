#!/usr/bin/env bash
set -euo pipefail

# auto_pen_test.sh
# Simple, non-destructive automation of common reconnaissance tasks.
# WARNING: Only run against systems/networks you own or have written permission to test.

usage() {
  cat <<EOF
Usage: $0 target

Example:
  $0 example.com

This script will run nmap (scans + vuln scripts), attempt nikto, fetch headers and
optionally run a directory discovery tool if available. Results are saved to a
timestamped directory.
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

TARGET="$1"
OUTDIR="pentest_${TARGET}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

echo "Output directory: $OUTDIR"

echo "Checking required tools..."
command -v nmap >/dev/null 2>&1 || { echo "nmap is required. Install it and re-run."; exit 2; }

# Optional tools
have_nikto=0; command -v nikto >/dev/null 2>&1 && have_nikto=1
have_gobuster=0; command -v gobuster >/dev/null 2>&1 && have_gobuster=1
have_dirb=0; command -v dirb >/dev/null 2>&1 && have_dirb=1

# 1) Nmap - quick top ports
echo "[nmap] top ports (1000)"
nmap -sS -sV -T4 --top-ports 1000 -oN "$OUTDIR/nmap_top1000.txt" "$TARGET"

# 2) Nmap - full TCP port scan with vuln scripts (can be slow)
echo "[nmap] full TCP scan with basic vuln scripts (may take time)"
# non-destructive NSE scripts: vuln, safe scripts are used; avoid intrusive exploit scripts
nmap -sS -sV -O --script "default,vuln" -T3 -p- -oA "$OUTDIR/nmap_full" "$TARGET" || true

# 3) Fetch HTTP headers (if webserver)
echo "[http] fetching headers (http/https)"
if curl -Is "http://$TARGET" -m 10 -o "$OUTDIR/http_headers_http.txt"; then
  echo "HTTP headers saved to $OUTDIR/http_headers_http.txt"
else
  echo "No http:// response or timed out"
fi
if curl -Is "https://$TARGET" -m 10 -o "$OUTDIR/http_headers_https.txt"; then
  echo "HTTPS headers saved to $OUTDIR/http_headers_https.txt"
else
  echo "No https:// response or timed out"
fi

# 4) Nikto (optional)
if [ "$have_nikto" -eq 1 ]; then
  echo "[nikto] running nikto against $TARGET"
  nikto -host "$TARGET" -o "$OUTDIR/nikto.txt" || echo "nikto finished with non-zero status"
else
  echo "nikto not found; skipping"
fi

# 5) Directory discovery (gobuster or dirb)
WORDLISTS=("/usr/share/wordlists/dirb/common.txt" "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt" "/usr/share/wordlists/rockyou.txt")
WORDLIST=""
for w in "${WORDLISTS[@]}"; do
  [ -f "$w" ] && { WORDLIST="$w"; break; }
done

if [ -n "$WORDLIST" ]; then
  if [ "$have_gobuster" -eq 1 ]; then
    echo "[gobuster] running directory scan (may need root for some options)"
    gobuster dir -u "http://$TARGET" -w "$WORDLIST" -o "$OUTDIR/gobuster_http.txt" || true
    gobuster dir -u "https://$TARGET" -w "$WORDLIST" -o "$OUTDIR/gobuster_https.txt" || true
  elif [ "$have_dirb" -eq 1 ]; then
    echo "[dirb] running dirb"
    dirb "http://$TARGET" "$WORDLIST" -o "$OUTDIR/dirb_http.txt" || true
    dirb "https://$TARGET" "$WORDLIST" -o "$OUTDIR/dirb_https.txt" || true
  else
    echo "No gobuster/dirb found; skipping directory discovery"
  fi
else
  echo "No common wordlist found; skipping directory discovery"
fi

# 6) Summarize
echo "\nScan complete. Results are in: $OUTDIR"
ls -la "$OUTDIR"

echo "Reminder: Only run these scans on targets you own or have explicit permission to test."
