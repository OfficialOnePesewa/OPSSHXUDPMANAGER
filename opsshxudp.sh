#!/bin/bash
# OPSSHXUDPMANAGER - Main Menu
# Repository: https://github.com/OfficialOnePesewa/OPSSHXUDPMANAGER

# --- Configuration ---
REPO_BASE="https://raw.githubusercontent.com/OfficialOnePesewa/OPSSHXUDPMANAGER/main"
CONFIG_DIR="/etc/opsshxudp"
BIN_DIR="/usr/local/bin"
UDP_CUSTOM_BIN="$BIN_DIR/udp-custom"
ZIVPN_BIN="$BIN_DIR/zivpn"
ZIVPN_CONF="/etc/zivpn/config.json"
MENU_VERSION="1.0.0"
# --- End Configuration ---

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Root check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root.${NC}"
   exit 1
fi

# ---------- Helper Functions ----------
display_system_info() {
    echo -e "${GREEN}--- System Information ---${NC}"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Architecture: $(uname -m)"
    echo "ISP: $(curl -s ifconfig.co/isp)"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
    echo "IP Address: $(curl -s ifconfig.me)"
    echo "RAM Usage: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')"
}

optimize_udp() {
    echo -e "${YELLOW}Optimizing UDP buffer sizes...${NC}"
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
    grep -q "^net.core.rmem_max" /etc/sysctl.conf || echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
    grep -q "^net.core.wmem_max" /etc/sysctl.conf || echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
    echo -e "${GREEN}Buffer sizes set.${NC}"
}

create_swap() {
    echo -e "${YELLOW}Creating swap file...${NC}"
    read -p "Enter swap size in MB: " swap_size
    if [[ "$swap_size" =~ ^[0-9]+$ ]]; then
        fallocate -l ${swap_size}M /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
        echo -e "${GREEN}Swap file of ${swap_size}MB created.${NC}"
    else
        echo -e "${RED}Invalid size.${NC}"
    fi
}

enable_bbr() {
    echo -e "${YELLOW}Enabling BBR...${NC}"
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}BBR enabled.${NC}"
}

run_speedtest() {
    echo -e "${YELLOW}Running speedtest...${NC}"
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
}

view_disclaimer() {
    echo -e "${RED}DISCLAIMER:${NC}"
    echo "This script is provided as-is. Use at your own risk."
    echo "The developers are not responsible for any misuse or damages."
}

uninstall_manager() {
    echo -e "${RED}Uninstalling OPSSHXUDPMANAGER...${NC}"
    systemctl stop udp-custom zivpn 2>/dev/null
    systemctl disable udp-custom zivpn 2>/dev/null
    rm -f /etc/systemd/system/udp-custom.service /etc/systemd/system/zivpn.service
    rm -f "$UDP_CUSTOM_BIN" "$ZIVPN_BIN"
    rm -rf "$CONFIG_DIR" /etc/zivpn
    rm -f "$MENU_PATH"
    echo -e "${GREEN}OPSSHXUDPMANAGER uninstalled.${NC}"
}

backup_accounts() {
    echo -e "${YELLOW}Backing up configs...${NC}"
    tar -czf /root/opsshxudp-backup.tar.gz "$CONFIG_DIR" /etc/zivpn 2>/dev/null
    echo -e "${GREEN}Backup saved to /root/opsshxudp-backup.tar.gz${NC}"
}

restore_accounts() {
    echo -e "${YELLOW}Restoring configs...${NC}"
    if [[ -f /root/opsshxudp-backup.tar.gz ]]; then
        tar -xzf /root/opsshxudp-backup.tar.gz -C /
        echo -e "${GREEN}Configs restored.${NC}"
    else
        echo -e "${RED}No backup file found.${NC}"
    fi
}

# ---------- ZIVPN User Management ----------
manage_zivpn_users() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is not installed. Installing...${NC}"
        apt-get install -y jq
    fi

    if [[ ! -f "$ZIVPN_CONF" ]]; then
        echo -e "${RED}ZIVPN config not found at $ZIVPN_CONF${NC}"
        read -p "Press Enter to return..."
        return
    fi

    while true; do
        clear
        echo -e "${BLUE}=====================================${NC}"
        echo -e "${BLUE}    ZIVPN USER MANAGEMENT${NC}"
        echo -e "${BLUE}=====================================${NC}"
        echo -e " ${GREEN}1.${NC} List existing users"
        echo -e " ${GREEN}2.${NC} Add a new user"
        echo -e " ${GREEN}3.${NC} Delete a user"
        echo -e " ${RED}0.${NC} Back to Main Menu"
        echo -e "${BLUE}=====================================${NC}"
        read -p "Choose an option: " zchoice

        case $zchoice in
            1)
                echo -e "${YELLOW}Current users (passwords):${NC}"
                jq -r '.auth.passwords[]' "$ZIVPN_CONF" 2>/dev/null || echo "Could not read config."
                ;;
            2)
                read -p "Enter new password: " newpass
                if [[ -z "$newpass" ]]; then
                    echo -e "${RED}Password cannot be empty.${NC}"
                else
                    # Add password if not already present
                    if jq -e --arg p "$newpass" '.auth.passwords | index($p)' "$ZIVPN_CONF" >/dev/null; then
                        echo -e "${YELLOW}Password already exists.${NC}"
                    else
                        tmp=$(mktemp)
                        jq --arg p "$newpass" '.auth.passwords += [$p]' "$ZIVPN_CONF" > "$tmp" && mv "$tmp" "$ZIVPN_CONF"
                        echo -e "${GREEN}User/password added.${NC}"
                        systemctl restart zivpn
                        echo "ZIVPN restarted to apply changes."
                    fi
                fi
                ;;
            3)
                read -p "Enter password to delete: " delpass
                if [[ -z "$delpass" ]]; then
                    echo -e "${RED}Password cannot be empty.${NC}"
                else
                    # Remove password (if exists)
                    if jq -e --arg p "$delpass" '.auth.passwords | index($p)' "$ZIVPN_CONF" >/dev/null; then
                        tmp=$(mktemp)
                        jq --arg p "$delpass" '.auth.passwords -= [$p]' "$ZIVPN_CONF" > "$tmp" && mv "$tmp" "$ZIVPN_CONF"
                        echo -e "${GREEN}User/password deleted.${NC}"
                        systemctl restart zivpn
                        echo "ZIVPN restarted to apply changes."
                    else
                        echo -e "${YELLOW}Password not found.${NC}"
                    fi
                fi
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# ---------- UDP Management Sub‑menu ----------
udp_management() {
    while true; do
        clear
        echo -e "${BLUE}=====================================${NC}"
        echo -e "${BLUE}       UDP MANAGEMENT MENU${NC}"
        echo -e "${BLUE}=====================================${NC}"
        echo -e " ${GREEN}1.${NC} Start / Install UDP Custom"
        echo -e " ${GREEN}2.${NC} Stop UDP Custom"
        echo -e " ${GREEN}3.${NC} Restart UDP Custom"
        echo -e " ${GREEN}4.${NC} Start ZIVPN"
        echo -e " ${GREEN}5.${NC} Stop ZIVPN"
        echo -e " ${GREEN}6.${NC} Restart ZIVPN"
        echo -e " ${GREEN}7.${NC} Status of Both Services"
        echo -e " ${GREEN}8.${NC} Manage ZIVPN Users (passwords)"
        echo -e " ${RED}0.${NC} Back to Main Menu"
        echo -e "${BLUE}=====================================${NC}"
        read -p "Choose an option: " udp_choice

        case $udp_choice in
            1)
                if [[ -f "$UDP_CUSTOM_BIN" ]]; then
                    systemctl start udp-custom
                    echo "UDP Custom started."
                else
                    echo "UDP Custom binary not found. Installing..."
                    wget -q -O "$UDP_CUSTOM_BIN" "$REPO_BASE/bin/udp-custom" && chmod +x "$UDP_CUSTOM_BIN"
                    systemctl start udp-custom && echo "UDP Custom installed and started."
                fi
                ;;
            2) systemctl stop udp-custom ;;
            3) systemctl restart udp-custom ;;
            4)
                if systemctl is-active --quiet zivpn; then
                    echo "ZIVPN is already running."
                else
                    systemctl start zivpn
                    echo "ZIVPN started."
                fi
                ;;
            5) systemctl stop zivpn ;;
            6) systemctl restart zivpn ;;
            7)
                echo -e "\n${GREEN}UDP Custom:${NC}"
                systemctl status udp-custom --no-pager -l | head -n 5
                echo -e "\n${GREEN}ZIVPN:${NC}"
                systemctl status zivpn --no-pager -l | head -n 5
                ;;
            8) manage_zivpn_users ;;
            0) break ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# ---------- Main Menu ----------
show_menu() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}     OPSSHXUDPMANAGER v$MENU_VERSION${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e " ${GREEN}1.${NC} Display System Information"
    echo -e " ${GREEN}2.${NC} UDP Management (Custom + ZIVPN)"
    echo -e " ${GREEN}3.${NC} Optimize UDP Speed"
    echo -e " ${GREEN}4.${NC} Create Swap-file"
    echo -e " ${GREEN}5.${NC} Enable BBR"
    echo -e " ${GREEN}6.${NC} Run Speedtest"
    echo -e " ${GREEN}7.${NC} Manage ZIVPN Users"
    echo -e " ${GREEN}8.${NC} Backup Configs"
    echo -e " ${GREEN}9.${NC} Restore Configs"
    echo -e " ${GREEN}10.${NC} View Disclaimer"
    echo -e " ${RED}11.${NC} Uninstall OPSSHXUDPMANAGER"
    echo -e " ${GREEN}0.${NC} Exit"
    echo -e "${BLUE}=====================================${NC}"
    read -p "Enter your choice: " choice

    case $choice in
        1) display_system_info ;;
        2) udp_management ;;
        3) optimize_udp ;;
        4) create_swap ;;
        5) enable_bbr ;;
        6) run_speedtest ;;
        7) manage_zivpn_users ;;
        8) backup_accounts ;;
        9) restore_accounts ;;
        10) view_disclaimer ;;
        11) uninstall_manager ; exit 0 ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac

    read -p "Press Enter to continue..."
    show_menu
}

# Start the menu
show_menu
