#!/bin/bash

# =========================================
# Installazione VPN Aziendale
# =========================================

CONFIG_DIR="$HOME/.config/openfortivpn"
CONFIG_FILE="$CONFIG_DIR/config"

# ---------- Colori ----------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

echo -e "${GREEN}Installazione VPN Aziendale${NC}"
echo

# ---------- Controllo sudo ----------
if ! sudo -v; then
    echo -e "${RED}Errore: sudo necessario${NC}"
    exit 1
fi

# ---------- Controllo distribuzione ----------
if ! command -v apt &>/dev/null; then
    echo -e "${RED}Questo installer supporta solo sistemi Debian/Ubuntu${NC}"
    exit 1
fi

# ---------- Installazione openfortivpn ----------
if ! command -v openfortivpn &>/dev/null; then
    echo -e "${YELLOW}openfortivpn non trovato. Installazione...${NC}"

    sudo apt update
    sudo apt install -y openfortivpn

    echo -e "${GREEN}openfortivpn installato${NC}"
else
    echo -e "${GREEN}openfortivpn già installato${NC}"
fi

echo

# ---------- Creazione directory config ----------
mkdir -p "$CONFIG_DIR"

# ---------- Controllo config esistente ----------
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Configurazione già esistente:${NC}"
    echo "$CONFIG_FILE"

    read -p "Sovrascrivere? (y/N): " OVERWRITE

    if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
        echo "Installazione annullata."
        exit 0
    fi
fi

echo
echo "Inserire i dati della VPN"
echo

# ---------- Raccolta dati ----------
read -p "Host VPN: " VPN_HOST
read -p "Username: " VPN_USER
read -s -p "Password: " VPN_PASS
echo
read -p "Trusted Cert: " VPN_CERT

# ---------- Creazione config ----------
cat > "$CONFIG_FILE" <<EOF
host = $VPN_HOST
port = 443
username = $VPN_USER
password = $VPN_PASS
trusted-cert = $VPN_CERT
EOF

# ---------- Permessi sicurezza ----------
chmod 600 "$CONFIG_FILE"

echo
echo -e "${GREEN}Configurazione creata:${NC}"
echo "$CONFIG_FILE"

# ---------- Permessi script ----------
chmod +x vpn-aziendale.sh

echo
echo -e "${GREEN}Installazione completata!${NC}"
echo
echo "Per avviare la VPN:"
echo "./vpn-aziendale.sh start"
echo
