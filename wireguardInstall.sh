#!/bin/bash

WG_INTERFACE="wg0-client"
WG_DIR="/etc/wireguard"

# ===================== FUNCTIONS =====================
input() {
    local prompt="$1"
    local default="$2"
    read -p "$prompt [$default]: " val
    echo "${val:-$default}"
}

confirm() {
    local name="$1"
    local value="$2"
    while true; do
        echo "$name: $value"
        read -p "Benar? (y/n): " yn
        case $yn in
            [Yy]*) break ;;
            [Nn]*) read -p "Masukkan ulang $name: " value ;;
            *) echo "y atau n" ;;
        esac
    done
    echo "$value"
}

# ===================== INPUT =====================
SERVER_IP=$(confirm "IP Server" "$(input 'Masukkan IP server' '')")
SERVER_PORT=$(confirm "Port Server" "$(input 'Masukkan port server' '51820')")
SERVER_PUBKEY=$(confirm "Public Key Server" "$(input 'Masukkan public key server' '')")
USER_IP=$(confirm "IP Lokal User (contoh 10.0.0.2/24)" "$(input 'Masukkan IP lokal user' '10.0.0.2/24')")

# ===================== INSTALL =====================
if ! command -v wg &>/dev/null; then
    echo "Install WireGuard..."
    sudo apt update
    sudo apt install -y wireguard
fi

# ===================== KEYS =====================
sudo mkdir -p "$WG_DIR"
sudo chmod 700 "$WG_DIR"

USER_PRIVKEY=$(wg genkey)
USER_PUBKEY=$(echo "$USER_PRIVKEY" | wg pubkey)

echo
echo "======================================"
echo " PUBLIC KEY USER (KIRIM KE SERVER)"
echo " $USER_PUBKEY"
echo "======================================"
echo

# ===================== CONFIG =====================
sudo bash -c "cat > $WG_DIR/$WG_INTERFACE.conf" <<EOF
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

echo "Config dibuat: $WG_DIR/$WG_INTERFACE.conf"

# ===================== AUTOSTART =====================
echo "Enable WireGuard auto-start on boot..."
sudo systemctl enable wg-quick@$WG_INTERFACE.service

# ===================== AUTO-RECONNECT (WRAPPER) =====================
SERVICE="/etc/systemd/system/wg-autorestart@$WG_INTERFACE.service"

sudo bash -c "cat > $SERVICE" <<EOF
[Unit]
Description=WireGuard AutoReconnect for $WG_INTERFACE
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

# ===================== START =====================
read -p "Jalankan WireGuard sekarang? (y/n): " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    sudo systemctl start wg-autorestart@$WG_INTERFACE.service
    echo "WireGuard AKTIF + AUTO RECONNECT!"
else
    echo "Jalankan manual:"
    echo "sudo systemctl start wg-autorestart@$WG_INTERFACE.service"
fi
