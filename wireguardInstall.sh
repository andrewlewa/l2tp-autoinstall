#!/bin/bash
echo "==============================="
echo "Bandrew Auto isnatll wireguard"
echo "==============================="

# Fungsi untuk meminta input dengan default
function input() {
    local prompt="$1"
    local default="$2"
    read -p "$prompt [$default]: " input_value
    echo "${input_value:-$default}"
}

# Fungsi untuk konfirmasi dan edit
function confirm_input() {
    local var_name="$1"
    local var_value="$2"
    while true; do
        echo "$var_name: $var_value"
        read -p "Apakah ini benar? (y/n): " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) read -p "Masukkan ulang $var_name: " val
                   var_value="$val";;
            * ) echo "Silakan ketik y atau n.";;
        esac
    done
    echo "$var_value"
}

# 1. Input konfigurasi
SERVER_IP=$(confirm_input "IP Server WireGuard" "$(input 'Masukkan IP server' '')")
SERVER_PORT=$(confirm_input "Port Server WireGuard" "$(input 'Masukkan port server' '51820')")
SERVER_PUBLIC_KEY=$(confirm_input "Public Key Server" "$(input 'Masukkan public key server' '')")
USER_IP=$(confirm_input "IP Lokal User (misal 10.0.0.2/24)" "$(input 'Masukkan IP lokal user' '10.0.0.2/24')")

# 2. Install WireGuard jika belum ada
if ! command -v wg &> /dev/null
then
    echo "WireGuard tidak ditemukan. Menginstal..."
    sudo apt update
    sudo apt install -y wireguard
fi

# 3. Buat kunci user
WG_DIR="/etc/wireguard"
USER_PRIVATE_KEY=$(wg genkey)
USER_PUBLIC_KEY=$(echo $USER_PRIVATE_KEY | wg pubkey)

# 4. Tampilkan public key user
echo "==============================="
echo "Public key user Anda adalah: $USER_PUBLIC_KEY"
echo "==============================="

# 5. Buat konfigurasi client
CLIENT_CONF="$WG_DIR/wg0-client.conf"

sudo bash -c "cat > $CLIENT_CONF" <<EOL
[Interface]
PrivateKey = $USER_PRIVATE_KEY
Address = $USER_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOL

echo "Konfigurasi client dibuat di $CLIENT_CONF"

# 6. Berikan opsi untuk memulai WireGuard
read -p "Apakah ingin langsung mengaktifkan WireGuard sekarang? (y/n): " start_now
if [[ "$start_now" =~ ^[Yy]$ ]]; then
    sudo wg-quick up wg0-client
    echo "WireGuard aktif!"
else
    echo "Anda bisa mengaktifkannya nanti dengan: sudo wg-quick up wg0-client"
fi
