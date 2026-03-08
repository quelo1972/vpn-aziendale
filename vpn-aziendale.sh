#!/bin/bash

# =========================================
# VPN Aziendale con openfortivpn
# =========================================

CONFIG_BASEDIR="$HOME/.config/openfortivpn"
CONFIG="$CONFIG_BASEDIR/config"
PID_FILE="$CONFIG_BASEDIR/vpn.pid"
LOG_UP="$CONFIG_BASEDIR/vpn-up.log"
MAX_WAIT=15   # secondi massimi di attesa connessione
DNS_FILE="$CONFIG_BASEDIR/dnsservers"
DNS_FILE_DOMAIN="$CONFIG_BASEDIR/dnsdomain"

#if [ -f "$DNS_FILE" ]; then
#    DNS_SERVERS=$(cat "$DNS_FILE")
#    echo "Imposto DNS VPN: $DNS_SERVERS"
#    DNS_DOMAIN=$(cat "$DNS_FILE_DOMAIN")
#    echo "Imposto DomainDNS VPN: $DNS_DOMAIN"
#else
#    echo "Nessun file DNS trovato ($DNS_FILE)"
#fi

# ---------- Funzioni ----------

vpn_is_up() {
    ip link show ppp0 >/dev/null 2>&1
}

start_vpn() {
    if [ -f "$DNS_FILE" ]; then
        DNS_SERVERS=$(cat "$DNS_FILE")
        echo "Imposto DNS VPN: $DNS_SERVERS"
        DNS_DOMAIN=$(cat "$DNS_FILE_DOMAIN")
        echo "Imposto DomainDNS VPN: $DNS_DOMAIN"
    else
        echo "Nessun file DNS trovato ($DNS_FILE)"
    fi

    if vpn_is_up; then
        echo "VPN già attiva."
        return
    fi

    if [ ! -f "$CONFIG" ]; then
        echo "Errore: file di configurazione $CONFIG non trovato!"
        echo "Usa lo script install.sh per crearlo"
        exit 1
    fi
    echo "Avvio VPN..."
    nohup sudo openfortivpn --config "$CONFIG" > "$LOG_UP" 2>&1 &
    VPN_PID=$!
    sleep 3 # attendo 3 secondi per permettere a tutti i log di raggiungere $LOG_UP
    echo "Connessione in corso..."
    for ((i=1;i<=MAX_WAIT;i++)); do
        if vpn_is_up; then
            echo "$VPN_PID" > "$PID_FILE"
            # imposto dns resolver e dafault domain aziendali
            sudo resolvectl dns ppp0 $DNS_SERVERS
            sudo resolvectl domain ppp0 $DNS_DOMAIN
            ip address show ppp0 >> $LOG_UP
            #resolvectl status | awk '/Link .* \(ppp0\)/,/^$/'
            echo "DNS $(resolvectl dns ppp0)" >> $LOG_UP
            notify-send "VPN" "Connessa"
            echo "VPN connessa (PID $VPN_PID)"
            echo "------ Contenuto vpn-up.log ------"
            cat "$LOG_UP"
            echo "---------------------------------"
            return
        fi
        sleep 1
    done
    echo "Errore: la VPN non si è connessa entro $MAX_WAIT secondi."
    echo "------ Contenuto vpn-up.log ------"
    cat "$LOG_UP"
    echo "---------------------------------"
    sudo kill "$VPN_PID" 2>/dev/null
    rm -f "$PID_FILE"
}

stop_vpn() {
    if vpn_is_up; then
        echo "Arresto VPN..."
        VPN_PID=$(cat "$PID_FILE" 2>/dev/null)
        sudo kill "$VPN_PID" 2>/dev/null
        sleep 2
        rm -f "$PID_FILE"
        notify-send "VPN" "Disconnessa"
        echo "VPN disconnessa."
    else
        notify-send "VPN" "VPN non attiva"
        echo "VPN non attiva."
    fi
}

status_vpn() {
    if vpn_is_up; then
        echo "VPN attiva."
        echo "------ Contenuto vpn-up.log ------"
        cat "$LOG_UP"
        echo "---------------------------------"
    else
        echo "VPN non attiva."
    fi
}

# ---------- Main ----------

# forza richiesta password sudo
sudo -v

case "$1" in
    start) start_vpn ;;
    stop) stop_vpn ;;
    status) status_vpn ;;
    *)
        echo "Uso: $0 {start|stop|status}"
        exit 1
        ;;
esac
