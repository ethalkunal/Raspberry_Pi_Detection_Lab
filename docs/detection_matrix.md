# Detection Matrix — Results

All 32 attacks executed against the Cowrie honeypot. Results measured in Grafana via Loki LogQL queries.

| Attack | Technique | Tactic | Tool | Rules Triggered | Outcome | MTTD |
|--------|-----------|--------|------|----------------|---------|------|
| A01 | T1595.001 | Reconnaissance | nmap -sT | DR-009 | TP | <5s |
| A02 | T1595.002 | Reconnaissance | nmap -sV | DR-009 | TP | <5s |
| A03 | T1595 | Reconnaissance | nmap -O | — | FN | — |
| A04 | T1110.001 | Initial Access | hydra SSH | DR-001, DR-009 | TP | <10s |
| A05 | T1110.004 | Initial Access | hydra stuffing | DR-001, DR-009 | TP | <10s |
| A06 | T1110.003 | Initial Access | hydra spray | DR-001, DR-009 | TP | <10s |
| A07 | T1110.001 | Initial Access | hydra Telnet | DR-003, DR-009 | TP | <30s |
| A08 | T1078.001 | Initial Access | ftp anonymous | — | FN | — |
| A09 | T1110.001 | Initial Access | hydra FTP | — | FN | — |
| A10 | T1059.004 | Execution | whoami | DR-009 | TP | <3s |
| A11 | T1082 | Discovery | env/printenv | DR-009 | TP | <3s |
| A12 | T1057 | Discovery | ps aux | DR-009 | TP | <3s |
| A13 | T1049 | Discovery | netstat/ss | DR-009 | TP | <3s |
| A14 | T1059.004 | Execution | bash -c | DR-009 | TP | <3s |
| A15 | T1083 | Discovery | ls/find | DR-009 | TP | <3s |
| A16 | T1087.001 | Discovery | cat /etc/passwd | DR-004, DR-009 | TP | <3s |
| A17 | T1003.008 | Credential Access | cat /etc/shadow | DR-004, DR-009 | TP | <3s |
| A18 | T1552.004 | Credential Access | cat sshd_config | DR-004, DR-009 | TP | <3s |
| A19 | T1548.003 | Privilege Escalation | cat /etc/sudoers | DR-004, DR-009 | TP | <3s |
| A20 | T1548.003 | Privilege Escalation | sudo -l | DR-004, DR-006, DR-009 | TP | <3s |
| A21 | T1548.001 | Privilege Escalation | find -perm -4000 | DR-004, DR-009 | TP | <3s |
| A22 | T1003.008 | Credential Access | cat /etc/passwd | DR-004, DR-009 | TP | <3s |
| A23 | T1552.004 | Credential Access | cat ~/.ssh/id_rsa | DR-004, DR-009 | TP | <3s |
| A24 | T1053.003 | Persistence | crontab | DR-008, DR-009 | TP | <3s |
| A25 | T1098.004 | Persistence | authorized_keys | DR-008, DR-009 | TP | <3s |
| A26 | T1136.001 | Persistence | useradd | DR-009 | TP | <3s |
| A27 | T1105 | C2 | wget | DR-007, DR-009 | TP | <5s |
| A28 | T1105 | C2 | curl | DR-007, DR-009 | TP | <5s |
| A29 | T1059.004 | C2 | nc reverse shell | DR-007, DR-009 | TP | <5s |
| A30 | T1041 | Exfiltration | tar + curl | DR-007, DR-009 | TP | <5s |
| A31 | T1070.002 | Defense Evasion | > auth.log | DR-009 | TP | <3s |
| A32 | T1070.003 | Defense Evasion | history -c | DR-009 | TP | <3s |

---

## Summary

| Metric | Value |
|--------|-------|
| Total attacks | 32 |
| True Positives | 29 |
| False Negatives | 3 |
| Detection coverage | **91%** |
| MTTD (commands) | **3 seconds** |
| MTTD (brute force) | **10 seconds** |

### False Negatives

| Attack | Reason |
|--------|--------|
| A03 | nmap OS scan requires root — not executed from Mac |
| A08 | No FTP honeypot — python-honeypots incompatible with Python 3.13 |
| A09 | No FTP honeypot — same reason as A08 |

### Per-tactic coverage

| Tactic | Attacks | TPs | Coverage |
|--------|---------|-----|----------|
| Reconnaissance | 3 | 2 | 67% |
| Initial Access | 6 | 4 | 67% |
| Execution | 4 | 4 | 100% |
| Discovery | 5 | 5 | 100% |
| Privilege Escalation | 3 | 3 | 100% |
| Credential Access | 4 | 4 | 100% |
| Persistence | 3 | 3 | 100% |
| Command & Control | 4 | 4 | 100% |
| Defense Evasion | 2 | 2 | 100% |

### Key findings

- Cowrie logs every command with sub-second precision including failed download attempts (`cowrie.session.file_download.failed`)
- Crontab manipulation, authorized_keys append, and backdoor user creation all captured under persistence
- Hydra's rapid parallel connections trigger Cowrie rate-limiting but still generate 50+ session events — DR-001 fires correctly
- Cowrie accepts common IoT passwords by default — realistic threat scenario for Pi-based deployments
