#!/usr/bin/env bash
# Install Loki + Grafana + Promtail on Pi 4B (SIEM)
# Run on Pi 4B: bash install_loki_grafana.sh
set -euo pipefail
LOG="$HOME/install_loki_grafana.log"
exec > >(tee -a "$LOG") 2>&1

LOKI_VER="3.1.1"
PROMTAIL_VER="3.1.1"

echo "======================================================"
echo " Detection Lab — Install Loki + Grafana (SIEM)"
echo " $(date -u)"
echo "======================================================"

echo "[1/5] Installing Loki v${LOKI_VER}..."
cd /tmp
wget -q "https://github.com/grafana/loki/releases/download/v${LOKI_VER}/loki-linux-arm64.zip" -O loki.zip
unzip -o loki.zip
sudo mv loki-linux-arm64 /usr/local/bin/loki
sudo chmod +x /usr/local/bin/loki
loki --version 2>&1 | head -1

echo "[2/5] Configuring Loki..."
sudo mkdir -p /etc/loki /var/lib/loki/chunks /var/lib/loki/rules

sudo tee /etc/loki/loki-config.yaml > /dev/null <<'LOKI_CONF'
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0
  grpc_listen_port: 9096
  log_level: info

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  allow_structured_metadata: true
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

compactor:
  working_directory: /var/lib/loki/compactor

analytics:
  reporting_enabled: false
LOKI_CONF

sudo tee /etc/systemd/system/loki.service > /dev/null <<'LOKI_SVC'
[Unit]
Description=Loki Log Aggregator
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yaml
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
LOKI_SVC

sudo systemctl daemon-reload
sudo systemctl enable --now loki
sleep 4
curl -s http://localhost:3100/ready && echo " — Loki ready"

echo "[3/5] Installing Promtail v${PROMTAIL_VER}..."
cd /tmp
wget -q "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VER}/promtail-linux-arm64.zip" -O promtail.zip
unzip -o promtail.zip
sudo mv promtail-linux-arm64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail

sudo mkdir -p /etc/promtail /var/lib/promtail
sudo tee /etc/promtail/promtail-config.yaml > /dev/null <<'PROMTAIL_CONF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          host: pi4
          __path__: /var/log/syslog

  - job_name: auth
    static_configs:
      - targets: [localhost]
        labels:
          job: auth
          host: pi4
          __path__: /var/log/auth.log
PROMTAIL_CONF

sudo tee /etc/systemd/system/promtail-siem.service > /dev/null <<'PROMTAIL_SVC'
[Unit]
Description=Promtail Log Shipper (SIEM local logs)
After=loki.service

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
PROMTAIL_SVC

sudo systemctl daemon-reload
sudo systemctl enable --now promtail-siem

echo "[4/5] Installing Grafana..."
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update && sudo apt install -y grafana
sudo systemctl enable --now grafana-server
sleep 3

echo "[5/5] Service status..."
for svc in loki grafana-server promtail-siem; do
    state=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    echo "  $svc: $state"
done

TS_IP=$(tailscale ip -4 2>/dev/null || hostname -I | awk '{print $1}')
echo ""
echo "======================================================"
echo " SIEM install complete — log: $LOG"
echo ""
echo " Access Grafana via SSH tunnel from your Mac:"
echo "   ssh -L 3000:localhost:3000 pi4@${TS_IP}"
echo "   Open: http://localhost:3000  (admin/admin)"
echo ""
echo " Add Loki data source: http://localhost:3100"
echo "======================================================"
