#!/bin/bash
set -e

echo "=== UNINSTALL L2TP/IPsec VPN CLIENT ==="
echo "=== By Bandrew ==="
echo "=== https://github.com/andrewlewa ==="
echo ""
echo ""

# --- Stop and disable VPN service ---
echo "[*] Stopping and disabling VPN auto-connect service..."
systemctl stop vpn-auto-connect.service 2>/dev/null || true
systemctl disable vpn-auto-connect.service 2>/dev/null || true

# --- Stop StrongSwan service ---
echo "[*] Stopping StrongSwan..."
systemctl stop strongswan-starter 2>/dev/null || true
systemctl disable strongswan-starter 2>/dev/null || true

# --- Kill running xl2tpd ---
echo "[*] Killing running xl2tpd processes..."
pkill xl2tpd 2>/dev/null || true

# --- Remove systemd service ---
echo "[*] Removing systemd service files..."
rm -f /etc/systemd/system/vpn-auto-connect.service
systemctl daemon-reload

# --- Remove auto-connect script ---
echo "[*] Removing auto-connect script..."
rm -f /usr/local/bin/vpn-auto-connect.sh

# --- Remove configuration files ---
echo "[*] Removing configuration files..."
rm -f /etc/ipsec.conf
rm -f /etc/ipsec.secrets
rm -rf /etc/xl2tpd
rm -rf /etc/ppp/options.l2tpd.client

# --- Remove xl2tpd runtime files ---
echo "[*] Removing xl2tpd runtime files..."
rm -rf /var/run/xl2tpd

# --- Uninstall packages ---
echo "[*] Removing packages installed by the VPN script..."
apt remove --purge -y strongswan xl2tpd ppp
apt autoremove -y
apt clean

# --- Reset network (optional) ---
echo "[*] Resetting network (optional)..."
# You can uncomment this if you want to restart networking
# systemctl restart networking

echo "=== UNINSTALL COMPLETE ==="
echo "All VPN files, services, and packages have been removed."
