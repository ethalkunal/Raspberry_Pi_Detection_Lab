# Threat Model — Raspberry Pi Detection Lab

## System Overview

A controlled adversary-emulation lab on two Raspberry Pis connected via Tailscale.
No services are exposed to the public internet. All attacks originate from a Mac/Kali
machine on the same Tailscale network.

```
Attacker (Mac/Kali)
  └── Tailscale
       ├── Pi 3B (Honeypot)
       │     Cowrie SSH  port 22 → 2222
       │     Cowrie Telnet  port 23 → 2223
       │     auditd  host-based syscall auditing
       │
       └── Pi 4B (SIEM)
             Loki:    log aggregation (port 3100)
             Grafana: dashboards (port 3000)
```

---

## Adversary Profile

**Persona:** External attacker with no prior credentials, targeting internet-facing Linux services.  
**Goal:** Initial access → command execution → persistence → data exfiltration.  
**Skill level:** Moderate (nmap, hydra, metasploit, curl).  

---

## Attack Catalog

### Reconnaissance

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A01 | Active port scan | T1595.001 | nmap -sS |
| A02 | Service version scan | T1595.002 | nmap -sV |
| A03 | OS fingerprint | T1595 | nmap -O |

### Initial Access

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A04 | SSH brute force | T1110.001 | hydra |
| A05 | SSH credential stuffing | T1110.004 | hydra |
| A06 | SSH password spray | T1110.003 | hydra |
| A07 | Telnet brute force | T1110.001 | hydra |
| A08 | FTP anonymous login | T1078.001 | ftp |
| A09 | FTP brute force | T1110.001 | hydra |

### Execution

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A10 | Shell command execution | T1059.004 | ssh |
| A11 | Environment discovery | T1082 | env/printenv |
| A12 | Process listing | T1057 | ps |
| A13 | Network connection listing | T1049 | netstat/ss |
| A14 | Bash -c execution | T1059.004 | bash -c |

### Discovery

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A15 | File and directory discovery | T1083 | ls/find |
| A16 | User account discovery | T1087.001 | cat /etc/passwd |
| A17 | Password file access | T1003.008 | cat /etc/shadow |
| A18 | SSH config inspection | T1552.004 | cat sshd_config |
| A19 | Sudo rules inspection | T1548.003 | cat /etc/sudoers |

### Privilege Escalation

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A20 | Sudo execution | T1548.003 | sudo -l |
| A21 | SUID binary discovery | T1548.001 | find -perm -4000 |

### Credential Access

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A22 | /etc/passwd dump | T1003.008 | cat /etc/passwd |
| A23 | SSH key exfiltration | T1552.004 | cat ~/.ssh/id_rsa |

### Persistence

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A24 | Cron job creation | T1053.003 | crontab |
| A25 | SSH authorized_keys modification | T1098.004 | echo >> authorized_keys |
| A26 | Backdoor user creation | T1136.001 | useradd |

### Command and Control / Exfiltration

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A27 | Tool download via wget | T1105 | wget |
| A28 | Tool download via curl | T1105 | curl |
| A29 | Netcat reverse shell | T1059.004 | nc |
| A30 | Data exfiltration | T1041 | tar + curl |

### Defense Evasion

| ID | Technique | MITRE | Tool |
|----|-----------|-------|------|
| A31 | Log clearing | T1070.002 | > /var/log/auth.log |
| A32 | History clearing | T1070.003 | history -c |

---

## Detection Rules

| Rule | Name | Attack IDs | MITRE | Severity |
|------|------|-----------|-------|----------|
| DR-001 | SSH brute-force burst | A04,A05,A06 | T1110 | High |
| DR-002 | Successful login post-burst | A04 | T1110 | Critical |
| DR-003 | Telnet brute-force | A07 | T1110.001 | Medium |
| DR-004 | Sensitive file read | A16,A17,A18,A19 | T1003.008 | High |
| DR-005 | auditd identity key | A16,A17,A22,A26 | T1003.008 | High |
| DR-006 | auditd privesc key | A20 | T1548 | Critical |
| DR-007 | Recon tool execution | A27,A28,A29 | T1105 | High |
| DR-008 | Persistence write | A24,A25 | T1053.003 | Critical |
| DR-009 | New honeypot session | A04–A32 | T1078 | Low |
| DR-010 | Multi-protocol scan | A01,A02 | T1595 | Medium |
