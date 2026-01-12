#!/bin/bash

WG_INTERFACE="wg0-client"
WG_DIR="/etc/wireguard"

ask() {
    local var
    read -p "$1: " var
    echo "$var"
}

confirm_loop() {
    local name="$1"
    local value="$2"

    while true; do
        echo "$name = $value"
        read -p "Benar? (y/n): " yn
        case $yn in
            [Yy]*) echo "$value"; return ;;
            [Nn]*) read -p "Masukkan ulang $name: " value ;;
            *) echo "Ketik y atau n" ;;
        esac
    done
}

# ================= INPUT =================
SERVER_IP=$(confirm_loop "IP Server" "$(ask 'Masukkan IP Server')")
SERVER_PORT=$(confirm_loop "Port Server" "$(ask 'Masukkan Port Server')")
SERVER_PUBKEY=$(confirm_loop "Public Key Server" "$(ask 'Masukkan Public Key Server')")
USER_IP=$(confirm_loop "IP Lokal User (contoh 10.0.0.2/24)" "$(ask 'Masukkan IP Lokal User')")

# ================= INSTALL =================
if ! command -v wg &>/dev/null; then
    sudo apt update
    sudo apt install -y wireguard
fi

# ================= KEYS =================
sudo mkdir -p "$WG_DIR"
sudo chmod 700 "$WG_DIR"

USER_PRIVKEY=$(wg genkey)
USER_PUBKEY=$(echo "$USER_PRIVKEY" | wg pubkey)

echo
echo "================ PUBLIC KEY USER ================"
echo "$USER_PUBKEY"
echo "================================================="
echo

# ================= CONFIG =================
sudo tee "$WG_DIR/$WG_INTERFACE.conf" > /dev/null <<EOF
[Interface]
PrivateKey = $USER_PRIVKEY
Address = $USER_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

sudo chmod 600 "$WG_DIR/$WG_INTERFACE.conf"

# ================= AUTOSTART =================
sudo systemctl enable wg-quick@$WG_INTERFACE.service

# ================= AUTO RECONNECT (SAFE) =================
sudo tee /etc/systemd/system/wg-autorestart@$WG_INTERFACE.service > /dev/null <<EOF
[Unit]
Description=WireGuard AutoReconnect $WG_INTERFACE
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/wg-quick up $WG_INTERFACE
ExecStop=/usr/bin/wg-quick down $WG_INTERFACE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wg-autorestart@$WG_INTERFACE.service

read -p "Start sekarang? (y/n): " yn
[[ "$yn" =~ ^[Yy]$ ]] && sudo systemctl start wg-autorestart@$WG_INTERFACE.service
