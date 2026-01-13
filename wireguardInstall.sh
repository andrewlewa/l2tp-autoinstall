#!/bin/bash

# Script untuk install dan konfigurasi WireGuard client di Ubuntu secara interaktif
# Jalankan sebagai root: sudo bash script.sh

# Fungsi untuk install WireGuard jika belum ada
install_wireguard() {
    if ! command -v wg &> /dev/null; then
        echo "WireGuard belum terinstall. Menginstall sekarang..."
        apt update
        apt install -y wireguard
    else
        echo "WireGuard sudah terinstall."
    fi
}

# Fungsi untuk generate key jika belum ada
generate_keys() {
    if [ ! -f /etc/wireguard/private.key ]; then
        wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
        chmod 600 /etc/wireguard/private.key
    fi
    PUBLIC_KEY=$(cat /etc/wireguard/public.key)
    PRIVATE_KEY=$(cat /etc/wireguard/private.key)
}

# Fungsi untuk buat config file
create_config() {
    cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = $LOCAL_IP
PrivateKey = $PRIVATE_KEY
DNS = 8.8.8.8  # Bisa diganti jika perlu

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_IP:$PORT
AllowedIPs = 0.0.0.0/0  # Route all traffic through VPN
PersistentKeepalive = 25  # Untuk auto reconnect instant
EOF
}

# Fungsi untuk enable auto start on boot
enable_autostart() {
    systemctl enable wg-quick@wg0
    echo "Auto start on boot telah diaktifkan."
}

# Mulai script
if [ "$EUID" -ne 0 ]; then
    echo "Jalankan script ini sebagai root: sudo bash $0"
    exit 1
fi

install_wireguard
generate_keys

# Loop utama untuk input dan edit
while true; do
    # Input data
    read -p "Masukkan IP server: " SERVER_IP
    read -p "Masukkan port server: " PORT
    read -p "Masukkan public key server: " SERVER_PUBKEY
    read -p "Masukkan IP lokal untuk client (contoh: 10.0.0.2/32): " LOCAL_IP

    # Tampilkan summary
    echo ""
    echo "Summary konfigurasi:"
    echo "1. IP server: $SERVER_IP"
    echo "2. Port: $PORT"
    echo "3. Public key server: $SERVER_PUBKEY"
    echo "4. IP lokal client: $LOCAL_IP"
    echo "5. Public key client Anda: $PUBLIC_KEY"
    echo ""

    # Konfirmasi
    read -p "Apakah data di atas benar? (y/n): " CONFIRM
    if [ "$CONFIRM" == "y" ] || [ "$CONFIRM" == "Y" ]; then
        break
    else
        while true; do
            read -p "Masukkan nomor field yang ingin di-edit (1-4, atau 'q' untuk batal): " EDIT_FIELD
            if [ "$EDIT_FIELD" == "q" ]; then
                exit 0
            fi
            case $EDIT_FIELD in
                1) read -p "Masukkan IP server baru: " SERVER_IP ;;
                2) read -p "Masukkan port baru: " PORT ;;
                3) read -p "Masukkan public key server baru: " SERVER_PUBKEY ;;
                4) read -p "Masukkan IP lokal baru: " LOCAL_IP ;;
                *) echo "Nomor tidak valid. Coba lagi." ;;
            esac
            # Tampilkan summary lagi setelah edit
            echo ""
            echo "Summary konfigurasi terupdate:"
            echo "1. IP server: $SERVER_IP"
            echo "2. Port: $PORT"
            echo "3. Public key server: $SERVER_PUBKEY"
            echo "4. IP lokal client: $LOCAL_IP"
            echo "5. Public key client Anda: $PUBLIC_KEY"
            echo ""
            read -p "Apakah sekarang benar? (y/n): " CONFIRM
            if [ "$CONFIRM" == "y" ] || [ "$CONFIRM" == "Y" ]; then
                break 2
            fi
        done
    fi
done

# Buat config
create_config

# Enable auto start
enable_autostart

# Start VPN
wg-quick up wg0
echo "WireGuard client telah dikonfigurasi dan dijalankan."
echo "Public key client Anda: $PUBLIC_KEY"
echo "Untuk stop: wg-quick down wg0"
echo "Fitur auto reconnect diaktifkan dengan PersistentKeepalive=25 (reconnect setiap 25 detik jika putus)."
