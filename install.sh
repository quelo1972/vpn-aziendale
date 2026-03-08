#!/bin/bash

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

echo "=== Installazione configurazione openfortivpn ==="
echo

if ! command -v openfortivpn >/dev/null 2>&1; then
    echo "Errore: openfortivpn non è installato."
    exit 1
fi

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
echo

echo
echo "Recupero fingerprint del certificato VPN..."

# esegue openfortivpn e salva output
vpn_output=$(openfortivpn "$VPN_HOST:$VPN_PORT" -u "$VPN_USER" -p "$VPN_PASS" 2>&1)

# controlla se il comando è fallito
if [ $? -ne 0 ]; then
    echo "Errore durante il tentativo di connessione alla VPN."
    echo
    echo "Output:"
    echo "$vpn_output"
    echo
    echo "Controllare host, porta, username e password."
    exit 1
fi

# estrai fingerprint
fingerprint=$(echo "$vpn_output" | grep -i "fingerprint" | awk '{print $NF}')

# controlla se vuoto
if [ -z "$fingerprint" ]; then
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
if ! [[ "$fingerprint" =~ ^[a-fA-F0-9]{64}$ ]]; then
    echo
    echo "Fingerprint ricevuto non valido:"
    echo "$fingerprint"
    exit 1
fi

echo
echo "Fingerprint rilevato:"
echo "$fingerprint"

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
trusted-cert = $VPN_CERT
set-dns = 0
EOF

chmod 600 "$CONFIG_FILE"

echo
echo "Configurazione salvata in $CONFIG_FILE"
echo "Installazione completata con successo."
