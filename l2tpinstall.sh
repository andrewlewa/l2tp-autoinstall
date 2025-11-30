#!/bin/bash

# All-in-One Script: Setup L2TP/IPsec VPN Client on Ubuntu Server
# Versi interaktif: bisa set IP, PSK, username, password

set -e

# --- Input User ---
echo "=== INSTALL L2TP/IPsec VPN CLIENT ==="
echo "=== By Bandrew ==="
echo "=== https://github.com/andrewlewa ==="
echo ""
echo ""
read -p "Masukkan IP Server VPN: " VPN_IP
read -p "Masukkan IPsec PSK: " VPN_PSK
read -p "Masukkan Username VPN: " VPN_USER
read -sp "Masukkan Password VPN: " VPN_PASS
echo ""

# --- Update dan install package ---
apt update -y
apt install -y strongswan xl2tpd ppp

# --- Stop dan disable xl2tpd lama ---
systemctl disable --now xl2tpd || true

# --- Konfigurasi IPsec ---
cat <<EOF > /etc/ipsec.conf
config setup
    uniqueids = no

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev1
    authby=psk

conn l2tp-vpn
    auto=add
    left=%any
    leftprotoport=17/1701
    right=$VPN_IP
    rightprotoport=17/1701
    type=transport
    forceencaps=yes
    dpddelay=40s
    dpdtimeout=130s
    dpdaction=clear
EOF

# --- IPsec secrets ---
cat <<EOF > /etc/ipsec.secrets
%any %any : PSK "$VPN_PSK"
EOF

# --- xl2tpd config ---
mkdir -p /etc/xl2tpd
cat <<EOF > /etc/xl2tpd/xl2tpd.conf
[lac vpn]
lns = $VPN_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
redial = yes
redial timeout = 5
max redials = 0
EOF

# --- PPP options ---
mkdir -p /etc/ppp
cat <<EOF > /etc/ppp/options.l2tpd.client
ipcp-accept-local
ipcp-accept-remote
refuse-eap
refuse-chap
refuse-mschap
refuse-pap
require-mschap-v2
noccp
noauth
idle 1800
mtu 1410
mru 1410
nodefaultroute
usepeerdns
debug
connect-delay 5000
name $VPN_USER
password $VPN_PASS
EOF

# --- Secure files ---
chmod 600 /etc/ipsec.secrets
chmod 600 /etc/ppp/options.l2tpd.client

# --- Auto-connect script ---
cat <<'EOF' > /usr/local/bin/vpn-auto-connect.sh
#!/bin/bash

while true; do
    if ip link show ppp0 > /dev/null 2>&1; then
        sleep 30
        continue
    fi

    echo "$(date): VPN disconnected, reconnecting..."

    # Restart StrongSwan
    systemctl restart strongswan-starter

    # Clean up old xl2tpd
    pkill xl2tpd || true
    rm -rf /var/run/xl2tpd
    mkdir -p /var/run/xl2tpd

    # Start xl2tpd
    xl2tpd -D -c /etc/xl2tpd/xl2tpd.conf -p /var/run/xl2tpd.pid -C /var/run/xl2tpd/l2tp-control &

    sleep 10

    # Connect
    echo "c vpn" > /var/run/xl2tpd/l2tp-control

    sleep 10
done
EOF

chmod +x /usr/local/bin/vpn-auto-connect.sh

# --- Systemd service ---
cat <<EOF > /etc/systemd/system/vpn-auto-connect.service
[Unit]
Description=VPN Auto-Connect Service
After=network.target strongswan-starter.service

[Service]
ExecStart=/usr/local/bin/vpn-auto-connect.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# --- Enable dan start service ---
systemctl daemon-reload
systemctl enable strongswan-starter
systemctl enable vpn-auto-connect.service
systemctl restart vpn-auto-connect.service

echo "Setup selesai! VPN akan otomatis connect ulang tanpa batas & start saat boot."
echo "Cek status: systemctl status vpn-auto-connect.service"
echo "Log realtime: journalctl -u vpn-auto-connect.service -f"
echo "Jika masih gagal, cek log xl2tpd: journalctl -xe | grep xl2tpd"
