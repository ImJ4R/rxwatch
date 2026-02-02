#!/usr/bin/env bash
# rxwatch_rolling.sh
# Periodically collects RX-path diagnostics with a rolling storage limit.

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  rxwatch.sh -i <iface> -t <seconds> -n <count> -o <dir> [-m <max_mb>]

Options:
  -i  Interfaces (comma-separated).
  -t  Interval in seconds between samples.
  -n  Number of samples (use 0 for infinite/continuous).
  -o  Output directory.
  -m  Max directory size in MB before deleting oldest logs (Default: 1024).
  -h  Help
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found" >&2; exit 1; }
}

# --- Default Settings ---
IFACES=""
INTERVAL=""
SAMPLES=""
OUTDIR=""
MAX_MB=1024 # Default 1GB rolling limit

while getopts ":i:t:n:o:m:h" opt; do
  case "$opt" in
    i) IFACES="$OPTARG" ;;
    t) INTERVAL="$OPTARG" ;;
    n) SAMPLES="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    m) MAX_MB="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [[ -z "$IFACES" || -z "$INTERVAL" || -z "$SAMPLES" || -z "$OUTDIR" ]]; then
  usage; exit 1
fi

need_cmd ip; need_cmd ethtool; need_cmd netstat; need_cmd du

mkdir -p "$OUTDIR"
IFS=',' read -r -a IFACE_ARR <<< "$IFACES"

cleanup_old_logs() {
  # Calculate current size of logs in MB
  local current_size
  current_size=$(du -sm "$OUTDIR" | cut -f1)

  while [[ "$current_size" -gt "$MAX_MB" ]]; do
    local oldest
    # Get oldest .log file
    oldest=$(ls -1tr "$OUTDIR"/*.log 2>/dev/null | head -n 1)
    
    if [[ -z "$oldest" ]]; then break; fi
    
    rm "$oldest"
    current_size=$(du -sm "$OUTDIR" | cut -f1)
  done
}

section() {
  echo -e "\n================================================================================\n$1\n================================================================================"
}

# --- Main Collection Loop ---
i=1
while true; do
  # If -n was not 0, check if we've reached the limit
  if [[ "$SAMPLES" -ne 0 && "$i" -gt "$SAMPLES" ]]; then
    break
  fi

  TS_FILE="$(date -u +"%Y%m%dT%H%M%SZ")"
  OUTFILE="$OUTDIR/rxwatch_${TS_FILE}_sample$(printf "%05d" "$i").log"

  {
    echo "Timestamp: $(date -u)"
    echo "Host: $(hostname)"
    
    section "KERNEL SOFTNET STAT (/proc/net/softnet_stat)"
    cat /proc/net/softnet_stat

    section "TCP STATS (netstat -s)"
    netstat -s

    for iface in "${IFACE_ARR[@]}"; do
      section "IFACE: $iface | ETHTOOL STATS"
      ethtool -S "$iface" 2>&1
      section "IFACE: $iface | RING CONFIG"
      ethtool -g "$iface" 2>&1
      section "IFACE: $iface | IP LINK STATS"
      ip -s link show dev "$iface" 2>&1
    done
  } > "$OUTFILE"

  echo "[$i] Wrote $OUTFILE (Dir Size: $(du -sh "$OUTDIR" | cut -f1))"
  
  # Perform the rolling cleanup
  cleanup_old_logs
  
  ((i++))
  sleep "$INTERVAL"
done
