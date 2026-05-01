#!/usr/bin/env bash
# Bootstrap Pi 4B — baseline packages, pre-create SIEM directories
# Run on Pi 4B: bash bootstrap_siem.sh
set -euo pipefail
LOG="$HOME/bootstrap_siem.log"
exec > >(tee -a "$LOG") 2>&1

echo "======================================================"
echo " Detection Lab — Bootstrap SIEM Pi"
echo " $(date -u)"
echo "======================================================"

echo "[1/3] System update..."
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl wget jq vim git unzip build-essential net-tools

echo "[2/3] System info..."
echo "Hostname: $(hostname)"
echo "Arch:     $(uname -m)"
echo "RAM:      $(free -h | awk '/^Mem:/{print $2}')"
echo "Disk:     $(df -h / | awk 'NR==2{print $4 " free"}')"

echo "[3/3] Checking ports for Loki and Grafana..."
for port in 3000 3100 9080; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  PORT $port: IN USE"
    else
        echo "  PORT $port: free"
    fi
done

sudo mkdir -p /etc/loki /var/lib/loki /etc/promtail /var/lib/promtail /etc/grafana

echo ""
echo "======================================================"
echo " Bootstrap complete — log: $LOG"
echo "======================================================"
