#!/bin/bash
# OPSSHXUDPMANAGER Installer
# Repository: https://github.com/OfficialOnePesewa/OPSSHXUDPMANAGER

set -e

REPO_BASE="https://raw.githubusercontent.com/OfficialOnePesewa/OPSSHXUDPMANAGER/main"
MENU_SCRIPT="opsshxudp.sh"
MENU_PATH="/usr/local/bin/opsshxudp"
UDP_CUSTOM_BIN="/usr/local/bin/udp-custom"
UDP_CUSTOM_CONFIG_DIR="/etc/opsshxudp/cstm"

echo "====================================="
echo "  OPSSHXUDPMANAGER Installer"
echo "====================================="

apt-get update -y && apt-get upgrade -y
apt-get install -y wget curl jq net-tools openssl iptables

# UDP Custom
echo "Installing UDP Custom..."
wget --no-cache -q -O "$UDP_CUSTOM_BIN" "$REPO_BASE/bin/udp-custom" || {
    echo "ERROR: Failed to download UDP Custom binary."
    exit 1
}
chmod +x "$UDP_CUSTOM_BIN"

mkdir -p "$UDP_CUSTOM_CONFIG_DIR"
cat > "$UDP_CUSTOM_CONFIG_DIR/config.json" <<EOF
{
    "listen": ":25525",
    "stream_buffer": 209715200,
    "receive_buffer": 209715200,
    "auth": {
        "mode": "passwords",
        "passwords": ["opsshxudp"]
    }
}
EOF

cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Service (OPSSHXUDPMANAGER)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$UDP_CUSTOM_BIN server -c $UDP_CUSTOM_CONFIG_DIR/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom
echo "UDP Custom installed."

# ZIVPN
echo "Downloading and running ZIVPN installer..."
wget --no-cache -q -O /tmp/install_zivpn.sh "$REPO_BASE/zivpn/install_zivpn.sh" || {
    echo "ERROR: Failed to download ZIVPN installer."
    exit 1
}
chmod +x /tmp/install_zivpn.sh
sudo /tmp/install_zivpn.sh
rm -f /tmp/install_zivpn.sh

# Menu
echo "Installing the OPSSHXUDPMANAGER menu..."
wget --no-cache -q -O "$MENU_PATH" "$REPO_BASE/$MENU_SCRIPT" || {
    echo "ERROR: Failed to download menu script."
    exit 1
}
chmod 777 "$MENU_PATH"

echo "====================================="
echo " Installation complete!"
echo " Type 'opsshxudp' to open the menu."
echo "====================================="
