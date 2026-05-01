#!/usr/bin/env bash
# Install Promtail on honeypot Pi — ships logs to Loki on SIEM Pi
# Usage: bash ship_logs.sh <SIEM_TAILSCALE_IP>
set -euo pipefail

LOKI_IP="${1:?Usage: bash ship_logs.sh <SIEM_TAILSCALE_IP>}"
PROMTAIL_VER="3.1.1"
LOG="$HOME/ship_logs.log"
exec > >(tee -a "$LOG") 2>&1

echo "======================================================"
echo " Detection Lab — Install Promtail on Honeypot Pi"
echo " Shipping to Loki: $LOKI_IP:3100"
echo " $(date -u)"
echo "======================================================"

echo "[1/4] Installing Promtail v${PROMTAIL_VER} for armv7..."
cd /tmp
wget -q "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VER}/promtail-linux-arm.zip" -O promtail.zip
unzip -o promtail.zip
sudo mv promtail-linux-arm /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
/usr/local/bin/promtail --version 2>&1 | head -1

echo "[2/4] Configuring Promtail..."
sudo mkdir -p /etc/promtail /var/lib/promtail

sudo tee /etc/promtail/promtail-config.yaml > /dev/null <<PROMTAIL_CONF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://${LOKI_IP}:3100/loki/api/v1/push
    batchsize: 1048576
    batchwait: 1s

scrape_configs:
  - job_name: cowrie
    static_configs:
      - targets: [localhost]
        labels:
          job: cowrie
          host: pi3
          __path__: /home/cowrie/cowrie/var/log/cowrie/cowrie.json
    pipeline_stages:
      - json:
          expressions:
            event_id: eventid
            src_ip: src_ip
            username: username
            password: password
      - labels:
          event_id:
          src_ip:

  - job_name: cowrie_text
    static_configs:
      - targets: [localhost]
        labels:
          job: cowrie_text
          host: pi3
          __path__: /home/cowrie/cowrie/var/log/cowrie/cowrie.log

  - job_name: auditd
    static_configs:
      - targets: [localhost]
        labels:
          job: auditd
          host: pi3
          __path__: /var/log/audit/audit.log

  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          host: pi3
          __path__: /var/log/syslog

  - job_name: auth
    static_configs:
      - targets: [localhost]
        labels:
          job: auth
          host: pi3
          __path__: /var/log/auth.log
PROMTAIL_CONF

echo "[3/4] Creating systemd service..."
sudo tee /etc/systemd/system/promtail.service > /dev/null <<'PROMTAIL_SVC'
[Unit]
Description=Promtail Log Shipper
After=network.target cowrie.service

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
PROMTAIL_SVC

sudo systemctl daemon-reload
sudo systemctl enable --now promtail
sleep 3

echo "[4/4] Verification..."
sudo systemctl status promtail --no-pager | head -5

if curl -s --max-time 5 "http://${LOKI_IP}:3100/ready" | grep -q "ready"; then
    echo "  Loki at ${LOKI_IP}:3100 is reachable"
else
    echo "  Cannot reach Loki — check Tailscale: tailscale ping ${LOKI_IP}"
fi

echo ""
echo "======================================================"
echo " Promtail install complete — log: $LOG"
echo "======================================================"
