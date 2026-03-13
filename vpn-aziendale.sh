#!/bin/bash

# =========================================
# VPN Aziendale con openfortivpn
# =========================================

CONFIG_BASEDIR="$HOME/.config/openfortivpn"
CONFIG="$CONFIG_BASEDIR/config"
PID_FILE="$CONFIG_BASEDIR/vpn.pid"
LOG_UP="$CONFIG_BASEDIR/vpn-up.log"
MAX_WAIT=15   # secondi massimi di attesa connessione
DNS_WAIT=10   # secondi massimi di attesa applicazione DNS
DNS_LOG="$CONFIG_BASEDIR/dns-apply.log"
DEBUG_LOG="$CONFIG_BASEDIR/debug.log"
DNS_SEARCH_BACKUP="$CONFIG_BASEDIR/dns-search.backup"
DNS_FILE="$CONFIG_BASEDIR/dnsservers"
DNS_DOMAIN_FILE="$CONFIG_BASEDIR/dnsdomain"
DNS_EXTRA_DOMAINS_FILE="$CONFIG_BASEDIR/dnsdomain-extra"

#if [ -f "$DNS_FILE" ]; then
#    DNS_SERVERS=$(cat "$DNS_FILE")
#    echo "Imposto DNS VPN: $DNS_SERVERS"
#    DNS_DOMAIN=$(cat "$DNS_DOMAIN_FILE")
#    echo "Imposto DomainDNS VPN: $DNS_DOMAIN"
#else
#    echo "Nessun file DNS trovato ($DNS_FILE)"
#fi

# ---------- Funzioni ----------

vpn_is_up() {
    ip -o link show 2>/dev/null | awk '/ppp[0-9]+/ {found=1} END{exit !found}'
}

detect_ppp_iface() {
    # Preferisci un'interfaccia ppp "UP", altrimenti fallback a ppp0
    local iface
    iface=$(ip -o link show 2>/dev/null | awk -F': ' '/ppp[0-9]+/ && $0 ~ /state UP/ {print $2; exit}')
    if [ -z "$iface" ]; then
        iface=$(ip -o link show 2>/dev/null | awk -F': ' '/ppp[0-9]+/ {print $2; exit}')
    fi
    if [ -z "$iface" ]; then
        iface="ppp0"
    fi
    echo "$iface"
}

wait_ppp_iface() {
    local i
    for ((i=1;i<=MAX_WAIT;i++)); do
        if ip -o link show 2>/dev/null | awk '/ppp[0-9]+/ {found=1} END{exit !found}'; then
            return 0
        fi
        sleep 1
    done
    return 1
}

wait_ppp_ip() {
    local iface="$1"
    local i
    for ((i=1;i<=MAX_WAIT;i++)); do
        if ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/'; then
            return 0
        fi
        sleep 1
    done
    return 1
}

wait_route_to_dns() {
    local iface="$1"
    local dns_servers="$2"
    local first_dns
    local i
    first_dns=$(echo "$dns_servers" | awk '{print $1}')
    if [ -z "$first_dns" ]; then
        return 1
    fi
    for ((i=1;i<=MAX_WAIT;i++)); do
        if ip route get "$first_dns" 2>/dev/null | grep -q "dev $iface"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

default_iface() {
    ip route show default 2>/dev/null | awk '{print $5; exit}'
}

get_iface_domains() {
    local iface="$1"
    resolvectl domain "$iface" 2>/dev/null | sed -E 's/^[^:]*: ?//'
}

apply_search_domain_to_default_iface() {
    local search_domain="$1"
    local iface
    local existing
    iface=$(default_iface)
    if [ -z "$iface" ]; then
        echo "$(date '+%F %T') default iface non trovato" >> "$DNS_LOG"
        return 1
    fi
    existing=$(get_iface_domains "$iface")
    echo "$iface|$existing" > "$DNS_SEARCH_BACKUP"
    if echo "$existing" | grep -q "$search_domain"; then
        echo "$(date '+%F %T') search domain già presente su $iface: $search_domain" >> "$DNS_LOG"
        return 0
    fi
    if [ -n "$existing" ]; then
        # Metti il dominio VPN per primo per risolvere i nomi corti con priorità
        sudo resolvectl domain "$iface" "$search_domain" $existing >>"$DNS_LOG" 2>&1
    else
        sudo resolvectl domain "$iface" "$search_domain" >>"$DNS_LOG" 2>&1
    fi
    echo "$(date '+%F %T') aggiunto search domain su $iface (first): $search_domain" >> "$DNS_LOG"
    return 0
}

restore_search_domain_on_default_iface() {
    local iface
    local existing
    if [ ! -f "$DNS_SEARCH_BACKUP" ]; then
        return 0
    fi
    iface=$(cut -d'|' -f1 "$DNS_SEARCH_BACKUP")
    existing=$(cut -d'|' -f2- "$DNS_SEARCH_BACKUP")
    if [ -z "$iface" ]; then
        rm -f "$DNS_SEARCH_BACKUP"
        return 0
    fi
    if [ -n "$existing" ]; then
        sudo resolvectl domain "$iface" $existing >/dev/null 2>&1
    else
        sudo resolvectl domain "$iface" >/dev/null 2>&1
    fi
    rm -f "$DNS_SEARCH_BACKUP"
    return 0
}

check_resolved() {
    local mode="$1"
    if ! command -v resolvectl >/dev/null 2>&1; then
        echo "Errore: resolvectl non trovato. Serve systemd-resolved attivo."
        echo "Su Ubuntu/Debian: sudo apt install systemd-resolved && sudo systemctl enable --now systemd-resolved"
        [ "$mode" = "warn" ] || exit 1
        return 1
    fi
    if ! systemctl is-active --quiet systemd-resolved; then
        echo "Errore: systemd-resolved non è attivo."
        echo "Avvia: sudo systemctl enable --now systemd-resolved"
        [ "$mode" = "warn" ] || exit 1
        return 1
    fi
}

wait_resolved_link() {
    local iface="$1"
    local i
    for ((i=1;i<=DNS_WAIT;i++)); do
        if resolvectl status "$iface" >/dev/null 2>&1; then
            echo "$(date '+%F %T') resolved link ok: $iface (try $i)" >> "$DNS_LOG"
            return 0
        fi
        echo "$(date '+%F %T') resolved link not ready: $iface (try $i)" >> "$DNS_LOG"
        sleep 1
    done
    return 1
}

apply_dns_settings() {
    local iface="$1"
    local dns_servers="$2"
    local dns_domain="$3"
    local extra_domains="$4"
    local i
    local clean_domain
    local domain_args

    clean_domain="${dns_domain#~}"
    domain_args=("$clean_domain" "~$clean_domain")
    if [ -n "$extra_domains" ]; then
        for d in $extra_domains; do
            d="${d#~}"
            if [ -n "$d" ]; then
                domain_args+=("~$d")
            fi
        done
    fi

    for ((i=1;i<=DNS_WAIT;i++)); do
        echo "$(date '+%F %T') apply dns try $i iface=$iface dns='$dns_servers' domain='$clean_domain' extra='${extra_domains:-n/a}'" >> "$DNS_LOG"
        # Imposta DNS e domain (domain anche come routing per evitare override)
        if sudo resolvectl dns "$iface" $dns_servers >>"$DNS_LOG" 2>&1 \
            && sudo resolvectl domain "$iface" "${domain_args[@]}" >>"$DNS_LOG" 2>&1; then
            sleep 1
            if resolvectl dns "$iface" 2>/dev/null | grep -q "$(echo "$dns_servers" | awk '{print $1}')" \
                && resolvectl domain "$iface" 2>/dev/null | grep -q "$clean_domain"; then
                echo "$(date '+%F %T') apply dns ok: iface=$iface" >> "$DNS_LOG"
                return 0
            fi
        fi
        echo "$(date '+%F %T') apply dns verify failed: iface=$iface" >> "$DNS_LOG"
        sleep 1
    done
    return 1
}

verify_routing_domains() {
    local iface="$1"
    local main_domain="$2"
    local extra_domains="$3"
    local domains_line
    local missing=""
    local d

    domains_line=$(resolvectl domain "$iface" 2>/dev/null | sed -E 's/^[^:]*: ?//')
    for d in $main_domain $extra_domains; do
        d="${d#~}"
        [ -z "$d" ] && continue
        if ! echo "$domains_line" | grep -q "~$d"; then
            missing="$missing $d"
        fi
    done

    if [ -z "$missing" ]; then
        echo "$(date '+%F %T') routing domains ok: iface=$iface main='$main_domain' extra='${extra_domains:-n/a}'" >> "$DNS_LOG"
        echo "Routing domains OK su $iface (extra: ${extra_domains:-n/a})"
        return 0
    fi
    echo "$(date '+%F %T') routing domains missing: iface=$iface missing='${missing# }' domains='$domains_line'" >> "$DNS_LOG"
    echo "Attenzione: routing domains mancanti su $iface:${missing}"
    return 1
}

start_vpn() {
    : > "$DNS_LOG"
    check_resolved
    if [ -f "$DNS_FILE" ]; then
        DNS_SERVERS=$(cat "$DNS_FILE")
        echo "Imposto DNS VPN: $DNS_SERVERS"
        if [ -z "$DNS_SERVERS" ]; then
            echo "Errore: lista DNS vuota in $DNS_FILE"
            exit 1
        fi
    else
        echo "Nessun file DNS trovato ($DNS_FILE)"
        echo "Riesegui install.sh o edita a mano $DNS_FILE"
        exit 1
    fi

    if [ -f "$DNS_DOMAIN_FILE" ]; then
        DNS_DOMAIN=$(cat "$DNS_DOMAIN_FILE")
        echo "Imposto Default domain VPN: $DNS_DOMAIN"
        if [ -z "$DNS_DOMAIN" ]; then
            echo "Errore: default domain vuoto in $DNS_DOMAIN_FILE"
            exit 1
        fi
    else
        echo "Nessun file Default domain trovato ($DNS_DOMAIN_FILE)"
        echo "Riesegui install.sh o edita a mano $DNS_DOMAIN_FILE"
        exit 1
    fi
    DNS_EXTRA_DOMAINS=""
    if [ -f "$DNS_EXTRA_DOMAINS_FILE" ]; then
        DNS_EXTRA_DOMAINS=$(cat "$DNS_EXTRA_DOMAINS_FILE")
        if [ -n "$DNS_EXTRA_DOMAINS" ]; then
            echo "Imposto domini extra VPN (routing): $DNS_EXTRA_DOMAINS"
        fi
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
    sleep 5 # attendo 3 secondi per permettere a tutti i log di raggiungere $LOG_UP
    echo "Connessione in corso..."
    for ((i=1;i<=MAX_WAIT;i++)); do
        if wait_ppp_iface; then
            echo "$VPN_PID" > "$PID_FILE"
            VPN_IFACE=$(detect_ppp_iface)
            if ! wait_ppp_ip "$VPN_IFACE"; then
                echo "$(date '+%F %T') ppp ip non assegnato entro tempo su $VPN_IFACE" >> "$DNS_LOG"
            fi
            if ! wait_route_to_dns "$VPN_IFACE" "$DNS_SERVERS"; then
                echo "$(date '+%F %T') route ai DNS non pronta su $VPN_IFACE" >> "$DNS_LOG"
            fi
            # Imposto DNS dopo che systemd-resolved vede l'interfaccia
            if ! wait_resolved_link "$VPN_IFACE"; then
                echo "Attenzione: systemd-resolved non ha ancora registrato $VPN_IFACE"
            fi
            DNS_APPLIED=0
            if ! apply_dns_settings "$VPN_IFACE" "$DNS_SERVERS" "$DNS_DOMAIN" "$DNS_EXTRA_DOMAINS"; then
                echo "Attenzione: impossibile applicare i DNS su $VPN_IFACE"
            else
                DNS_APPLIED=1
            fi
            apply_search_domain_to_default_iface "$DNS_DOMAIN"
            if [ -n "$DNS_EXTRA_DOMAINS" ]; then
                if [ "$DNS_APPLIED" -eq 1 ]; then
                    echo "Domini extra applicati su $VPN_IFACE (routing): $DNS_EXTRA_DOMAINS"
                else
                    echo "Domini extra non applicati (routing) per errore DNS: $DNS_EXTRA_DOMAINS"
                fi
            fi
            verify_routing_domains "$VPN_IFACE" "$DNS_DOMAIN" "$DNS_EXTRA_DOMAINS"
            ip address show "$VPN_IFACE" >> "$LOG_UP"
            echo "DNS $(resolvectl dns "$VPN_IFACE")" >> "$LOG_UP"
            echo "Default domain: $DNS_DOMAIN" >> $LOG_UP
            notify-send "VPN" "Connessa"
            echo "VPN connessa (PID $VPN_PID, IFACE $VPN_IFACE)"
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
        VPN_IFACE=$(detect_ppp_iface)
        if ip link show "$VPN_IFACE" >/dev/null 2>&1; then
            # Pulisce DNS/domains espliciti prima del revert
            sudo resolvectl domain "$VPN_IFACE" >/dev/null 2>&1
            sudo resolvectl dns "$VPN_IFACE" >/dev/null 2>&1
            sudo resolvectl revert "$VPN_IFACE" >/dev/null 2>&1
        fi
        restore_search_domain_on_default_iface
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

debug_vpn() {
    : > "$DEBUG_LOG"
    echo "Debug VPN - $(date '+%F %T')" | tee -a "$DEBUG_LOG"
    echo "Config dir: $CONFIG_BASEDIR" | tee -a "$DEBUG_LOG"
    echo "PID file: $PID_FILE" | tee -a "$DEBUG_LOG"
    echo "DNS file: $DNS_FILE" | tee -a "$DEBUG_LOG"
    echo "DNS domain file: $DNS_DOMAIN_FILE" | tee -a "$DEBUG_LOG"
    echo "DNS extra domain file: $DNS_EXTRA_DOMAINS_FILE" | tee -a "$DEBUG_LOG"
    check_resolved warn | tee -a "$DEBUG_LOG"
    RESOLVED_OK=$?
    echo "--- ip link ---" | tee -a "$DEBUG_LOG"
    ip -o link show | tee -a "$DEBUG_LOG"
    echo "--- ip addr ---" | tee -a "$DEBUG_LOG"
    ip -o addr show | tee -a "$DEBUG_LOG"
    echo "--- resolvectl status ---" | tee -a "$DEBUG_LOG"
    RESOLV_STATUS=$(resolvectl status 2>/dev/null)
    echo "$RESOLV_STATUS" | tee -a "$DEBUG_LOG"
    RESOLVCONF_MODE=$(echo "$RESOLV_STATUS" | awk -F': ' '/resolv.conf mode/ {print $2; exit}')
    VPN_IFACE=$(detect_ppp_iface)
    echo "--- resolvectl status $VPN_IFACE ---" | tee -a "$DEBUG_LOG"
    resolvectl status "$VPN_IFACE" | tee -a "$DEBUG_LOG"
    echo "--- resolvectl dns $VPN_IFACE ---" | tee -a "$DEBUG_LOG"
    resolvectl dns "$VPN_IFACE" | tee -a "$DEBUG_LOG"
    echo "--- resolvectl domain $VPN_IFACE ---" | tee -a "$DEBUG_LOG"
    resolvectl domain "$VPN_IFACE" | tee -a "$DEBUG_LOG"
    echo "--- resolvectl query comune.spoleto.pg.it ---" | tee -a "$DEBUG_LOG"
    resolvectl query comune.spoleto.pg.it 2>&1 | tee -a "$DEBUG_LOG"
    if [ -f "$DNS_EXTRA_DOMAINS_FILE" ]; then
        echo "--- dnsdomain-extra ---" | tee -a "$DEBUG_LOG"
        cat "$DNS_EXTRA_DOMAINS_FILE" | tee -a "$DEBUG_LOG"
    fi
    echo "--- journalctl (systemd-resolved, last 200) ---" | tee -a "$DEBUG_LOG"
    sudo journalctl -u systemd-resolved -n 200 | tee -a "$DEBUG_LOG"
    echo "--- summary ---" | tee -a "$DEBUG_LOG"
    if [ "$RESOLVED_OK" -eq 0 ]; then
        echo "systemd-resolved: OK" | tee -a "$DEBUG_LOG"
    else
        echo "systemd-resolved: FAIL" | tee -a "$DEBUG_LOG"
    fi
    if vpn_is_up; then
        VPN_IFACE=$(detect_ppp_iface)
        VPN_IP=$(ip -o -4 addr show dev "$VPN_IFACE" 2>/dev/null | awk '{print $4; exit}')
        VPN_DNS=$(resolvectl dns "$VPN_IFACE" 2>/dev/null | sed -E 's/^[^:]*: ?//')
        VPN_DOMAINS=$(resolvectl domain "$VPN_IFACE" 2>/dev/null | sed -E 's/^[^:]*: ?//')
        DEF_IFACE=$(default_iface)
        DEF_DOMAINS=$(resolvectl domain "$DEF_IFACE" 2>/dev/null | sed -E 's/^[^:]*: ?//')
        DNS_DOMAIN=""
        if [ -f "$DNS_DOMAIN_FILE" ]; then
            DNS_DOMAIN=$(cat "$DNS_DOMAIN_FILE")
        fi
        EXTRA_DOMAINS=""
        if [ -f "$DNS_EXTRA_DOMAINS_FILE" ]; then
            EXTRA_DOMAINS=$(cat "$DNS_EXTRA_DOMAINS_FILE")
        fi
        echo "vpn: UP" | tee -a "$DEBUG_LOG"
        echo "vpn_iface: $VPN_IFACE" | tee -a "$DEBUG_LOG"
        echo "vpn_ip: ${VPN_IP:-n/a}" | tee -a "$DEBUG_LOG"
        echo "vpn_dns: ${VPN_DNS:-n/a}" | tee -a "$DEBUG_LOG"
        echo "vpn_domains: ${VPN_DOMAINS:-n/a}" | tee -a "$DEBUG_LOG"
        echo "default_iface: ${DEF_IFACE:-n/a}" | tee -a "$DEBUG_LOG"
        echo "default_domains: ${DEF_DOMAINS:-n/a}" | tee -a "$DEBUG_LOG"
        verify_routing_domains "$VPN_IFACE" "$DNS_DOMAIN" "$EXTRA_DOMAINS" | tee -a "$DEBUG_LOG"
    else
        echo "vpn: DOWN" | tee -a "$DEBUG_LOG"
    fi
    echo "resolv.conf mode: ${RESOLVCONF_MODE:-n/a}" | tee -a "$DEBUG_LOG"
    echo "Log salvato in $DEBUG_LOG"
}

# ---------- Main ----------

# forza richiesta password sudo
sudo -v

case "$1" in
    start) start_vpn ;;
    stop) stop_vpn ;;
    status) status_vpn ;;
    debug) debug_vpn ;;
    *)
        echo "Uso: $0 {start|stop|status|debug}"
        exit 1
        ;;
esac
