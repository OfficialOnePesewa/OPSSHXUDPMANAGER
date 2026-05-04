#!/bin/bash
# OPSSHXUDPMANAGER - ZIVPN UDP Installer (No password prompt)
# Repository: https://github.com/OfficialOnePesewa/OPSSHXUDPMANAGER

# --- Configuration ---
ZIVPN_BIN="/usr/local/bin/zivpn"
ZIVPN_CONF="/etc/zivpn/config.json"
DEFAULT_PASSWORD="opsshxudp"
# --- End Configuration ---

echo -e "Updating server"
sudo apt-get update && apt-get upgrade -y
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "Downloading UDP Service"
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O "$ZIVPN_BIN" 1> /dev/null 2> /dev/null
chmod +x "$ZIVPN_BIN"

mkdir /etc/zivpn 1> /dev/null 2> /dev/null

wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O "$ZIVPN_CONF" 1> /dev/null 2> /dev/null

echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Set default password without prompt
echo "Setting default password: $DEFAULT_PASSWORD"
new_config_str="\"config\": [\"$DEFAULT_PASSWORD\"]"
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" "$ZIVPN_CONF"

systemctl enable zivpn.service
systemctl start zivpn.service

iptables -t nat -A PREROUTING -i $(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1) -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp

rm zi.* 1> /dev/null 2> /dev/null
echo -e "ZIVPN UDP Installed"
