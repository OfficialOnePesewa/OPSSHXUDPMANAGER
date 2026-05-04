# OPSSHXUDPMANAGER

**OPSSHXUDPMANAGER** is a streamlined UDP tunnel management suite that bundles:
- **UDP Custom** – a password‑protected UDP tunnelling service
- **ZIVPN** – a high‑performance UDP VPN with user management

All controlled from a single interactive menu.

## 🚀 One‑Command Install

Copy and paste this on a **fresh Ubuntu/Debian** server as root:

```bash
sudo -s
rm -f install.sh; apt-get update -y; apt-get upgrade -y; wget --no-cache "https://raw.githubusercontent.com/OfficialOnePesewa/OPSSHXUDPMANAGER/main/install.sh" -O install.sh >/dev/null 2>&1; chmod 777 install.sh;./install.sh; rm -f install.sh# OPSSHXUDPMANAGER


After installation, open the management menu:
```bash
opsshxudp

✨ Features
UDP Custom service with configurable password list

ZIVPN UDP VPN with automatic certificate generation

User management – add/remove ZIVPN users directly from the menu

System optimization – enable BBR, create swap, tune UDP buffers

Backup & restore – save and restore all configs easily

🛠️ Menu Options
Display System Information

UDP Management (Start/Stop/Restart UDP Custom & ZIVPN, manage ZIVPN users)

Optimize UDP Speed

Create Swap-file

Enable BBR

Run Speedtest

Manage ZIVPN Users

Backup Configs

Restore Configs

View Disclaimer

Uninstall OPSSHXUDPMANAGER
