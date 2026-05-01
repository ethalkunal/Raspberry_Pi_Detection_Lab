#!/usr/bin/env bash
# Install Cowrie SSH/Telnet honeypot on Pi 3B
# Run on Pi 3B: bash install_cowrie.sh
set -euo pipefail
LOG="$HOME/install_cowrie.log"
exec > >(tee -a "$LOG") 2>&1

echo "======================================================"
echo " Detection Lab — Install Cowrie Honeypot"
echo " $(date -u)"
echo "======================================================"

echo "[1/5] Creating cowrie user..."
if id cowrie &>/dev/null; then
    echo "  cowrie user exists"
else
    sudo adduser --disabled-password --gecos "" cowrie
fi

echo "[2/5] Cloning and installing Cowrie..."
sudo -u cowrie bash <<'COWRIE_INSTALL'
set -e
cd /home/cowrie
if [ -d cowrie ]; then
    cd cowrie && git pull
else
    git clone https://github.com/cowrie/cowrie.git
    cd cowrie
fi
python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install --upgrade pip wheel
pip install --upgrade -r requirements.txt
pip install -e .
COWRIE_INSTALL

echo "[3/5] Configuring Cowrie..."
sudo -u cowrie cp /home/cowrie/cowrie/etc/cowrie.cfg.dist /home/cowrie/cowrie/etc/cowrie.cfg
sudo -u cowrie sed -i 's/^#\?hostname\s*=.*/hostname = ubuntu-srv-prod-01/' /home/cowrie/cowrie/etc/cowrie.cfg
sudo -u cowrie sed -i 's/^#\?listen_endpoints\s*=.*/listen_endpoints = tcp:2222:interface=0.0.0.0/' /home/cowrie/cowrie/etc/cowrie.cfg
sudo -u cowrie sed -i "714s/enabled = false/enabled = true/" /home/cowrie/cowrie/etc/cowrie.cfg
sudo -u cowrie sed -i "714a listen_endpoints = tcp:2223:interface=0.0.0.0" /home/cowrie/cowrie/etc/cowrie.cfg

echo "[4/5] Setting up iptables redirect 22->2222, 23->2223..."
sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2222
sudo iptables -t nat -A PREROUTING -p tcp --dport 23 -j REDIRECT --to-port 2223
sudo netfilter-persistent save

echo "[5/5] Installing systemd service..."
sudo tee /etc/systemd/system/cowrie.service > /dev/null <<'UNIT'
[Unit]
Description=Cowrie SSH/Telnet Honeypot
After=network.target

[Service]
Type=simple
User=cowrie
Group=cowrie
WorkingDirectory=/home/cowrie/cowrie
Environment="PATH=/home/cowrie/cowrie/cowrie-env/bin:/usr/local/bin:/usr/bin:/bin"
Environment="VIRTUAL_ENV=/home/cowrie/cowrie/cowrie-env"
Environment="COWRIE_STDOUT=yes"
ExecStart=/home/cowrie/cowrie/cowrie-env/bin/cowrie start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo -u cowrie mkdir -p /home/cowrie/cowrie/var/log/cowrie /home/cowrie/cowrie/var/run
sudo systemctl daemon-reload
sudo systemctl enable --now cowrie
sleep 4

echo ""
sudo systemctl status cowrie --no-pager | head -8
echo ""
ss -tlnp | grep -E "2222|2223" && echo "Cowrie listening" || echo "Check: sudo journalctl -u cowrie -n 30"

echo ""
echo "======================================================"
echo " Cowrie install complete — log: $LOG"
echo " Test: ssh root@<THIS_IP>  (any password)"
echo " Logs: sudo tail -f /home/cowrie/cowrie/var/log/cowrie/cowrie.json | jq ."
echo "======================================================"
