#!/bin/bash
sudo -v
# Verifica se openfortivpn è installato
if ! command -v openfortivpn &> /dev/null
then
    echo "openfortivpn non trovato. Installazione in corso..."

    sudo apt update
    sudo apt install -y openfortivpn

    echo "openfortivpn installato."
else
    echo "openfortivpn è già installato."
fi

CONFIG_DIR="$HOME/.config/openfortivpn"
CONFIG_FILE="$CONFIG_DIR/config"

# Crea directory
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    echo "Creata directory $CONFIG_DIR"
fi

# Sovrascrittura
if [ -f "$CONFIG_FILE" ]; then
    read -p "Il file config esiste già. Sovrascriverlo? (s/N): " OVERWRITE
    if [[ "$OVERWRITE" != "s" && "$OVERWRITE" != "S" ]]; then
        echo "Operazione annullata."
        exit 0
    fi
fi

# Input utente
read -p "Host VPN: " VPN_HOST
read -p "Porta VPN [443]: " VPN_PORT
VPN_PORT=${VPN_PORT:-443}
read -p "Username VPN: " VPN_USER
read -s -p "Password VPN: " VPN_PASS
echo

echo "Recupero fingerprint del certificato VPN..."
echo "potrebbe essere richiesto l'inserimento della password sudo"

# LANCIO COME ROOT SENZA PASSWORD VPN
TMP_OUTPUT=$(echo "" | sudo timeout 8 openfortivpn ${VPN_HOST}:${VPN_PORT} \
    --username=${VPN_USER} 2>&1)

FINGERPRINT=$(echo "$TMP_OUTPUT" | grep -oE '[a-f0-9]{64}' | head -n1)

# verifica se fingerprint trovato
if [ -z "$FINGERPRINT" ]; then
    echo
    echo "Errore: impossibile recuperare il fingerprint dal server VPN."
    echo
    echo "Output restituito da openfortivpn:"
    echo "--------------------------------"
    echo "$vpn_output"
    echo "--------------------------------"
    echo
    echo "Controllare:"
    echo "- host VPN"
    echo "- porta"
    echo "- username/password"
    echo "- raggiungibilità del server"
    echo
    exit 1
fi

# controlla se vuoto
if [ -z "$FINGERPRINT" ]; then
    echo
    echo "Errore: nessun fingerprint restituito dal server VPN."
    echo
    echo "Possibili cause:"
    echo "- host VPN errato"
    echo "- porta errata"
    echo "- server non raggiungibile"
    echo "- autenticazione fallita"
    echo
    exit 1
fi

# verifica formato SHA256 (64 hex)
if ! [[ "$FINGERPRINT" =~ ^[a-fA-F0-9]{64}$ ]]; then
    echo
    echo "Fingerprint ricevuto non valido:"
    echo "$FINGERPRINT"
    exit 1
fi

echo
echo "Fingerprint rilevato:"
echo "$FINGERPRINT"

read -p "Confermi di volerlo usare? (S/n): " CONFIRM
if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
    echo "Operazione annullata."
    exit 0
fi

# Scrittura config
cat > "$CONFIG_FILE" <<EOF
host = $VPN_HOST
port = $VPN_PORT
username = $VPN_USER
password = $VPN_PASS
trusted-cert = $FINGERPRINT
set-dns = 0
EOF

chmod 600 "$CONFIG_FILE"

echo
echo "Configurazione salvata in $CONFIG_FILE"
echo "Installazione completata con successo."
