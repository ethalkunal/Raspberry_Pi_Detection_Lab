#!/usr/bin/env bash
# Bootstrap Pi 3B — SSH hardening, package install, auditd rules
# Run on Pi 3B: bash bootstrap_honeypot.sh
set -euo pipefail
LOG="$HOME/bootstrap_honeypot.log"
exec > >(tee -a "$LOG") 2>&1

echo "======================================================"
echo " Detection Lab — Bootstrap Honeypot Pi"
echo " $(date -u)"
echo "======================================================"

echo "[1/4] System update..."
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y \
    git python3-venv python3-pip build-essential \
    libssl-dev libffi-dev python3-dev \
    jq curl wget vim auditd \
    iptables-persistent net-tools

echo "[2/4] Moving SSH to port 2200..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
grep -q "^Port 2200" /etc/ssh/sshd_config || echo "Port 2200" | sudo tee -a /etc/ssh/sshd_config
sudo sed -i 's/^Port 22$/Port 2200/' /etc/ssh/sshd_config

echo ""
echo "Before restarting SSH, test port 2200 in a second terminal:"
echo "  ssh -p 2200 pi3@<IP> 'echo ok'"
echo "Then run: sudo systemctl restart ssh"
echo ""

echo "[3/4] Configuring auditd rules..."
sudo tee /etc/audit/rules.d/security.rules > /dev/null <<'AUDIT'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/sudoers.d -p wa -k identity
-w /etc/ssh/sshd_config -p wa -k sshd_config_change
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/sudo -k privesc
-a always,exit -F arch=b32 -S execve -F path=/bin/su -k privesc
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/su -k privesc
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/wget -k recon
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/curl -k recon
-a always,exit -F arch=b32 -S execve -F path=/bin/nc -k recon
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/ncat -k recon
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/nmap -k recon
-w /root/.ssh -p wa -k ssh_key
-w /home -p wa -k ssh_key
-w /etc/cron.d -p wa -k persistence
-w /etc/crontab -p wa -k persistence
-w /var/spool/cron -p wa -k persistence
-a always,exit -F arch=b32 -S init_module,delete_module -k kernel_module
AUDIT

sudo augenrules --load 2>/dev/null || sudo auditctl -R /etc/audit/rules.d/security.rules
sudo systemctl enable --now auditd

echo "[4/4] System info..."
echo "Hostname: $(hostname)"
echo "Arch:     $(uname -m)"
echo "RAM:      $(free -h | awk '/^Mem:/{print $2}')"
echo "Disk:     $(df -h / | awk 'NR==2{print $4 " free"}')"
echo "auditd rules loaded: $(sudo auditctl -l | grep -vc '^No rules')"

echo ""
echo "======================================================"
echo " Bootstrap complete — log: $LOG"
echo "======================================================"
