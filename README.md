# vpn-aziendale

Script Bash semplice e robusto per connettersi alla SSL/VPN aziendale (FORTINET) tramite openfortivpn su sistemi Linux.

Il progetto automatizza:

* installazione delle dipendenze
* configurazione della VPN
* recupero automatico del fingerprint del certificato
* gestione della connessione VPN
* assegnazione permessi ristretti (700) alla directory ~/.config/openfortivpn/
* assegnazione permessi ristretti (600) al file ~/.config/openfortivpn/config
* assegnazione permessi ristretti (600) al file ~/.config/openfortivpn/dnsservers
* assegnazione permessi ristretti (600) al file ~/.config/openfortivpn/dnsdomain
* assegnazione permessi ristretti (600) al file ~/.config/openfortivpn/dnsdomain-extra (opzionale)

Testato su **Ubuntu / Kubuntu**.

---

# Requisiti

Sistema operativo supportato:

* Ubuntu
* Kubuntu
* Debian-based Linux

Dipendenza principale:

* `openfortivpn`

Il client openfortivpn crea un tunnel PPP e gestisce la comunicazione SSL/VPN con il gateway Fortinet. ([GitHub][1])

---

# Installazione

Clonare il repository:

```bash
git clone https://github.com/quelo1972/vpn-aziendale.git
cd vpn-aziendale
```

Passare al ramo desiderato (opzionale):
default master

```bash
git switch master
```
```bash
git switch dev
```

Rendere eseguibile lo script di installazione (ma dovrebbe già esserlo):

```bash
chmod +x install.sh
```

Eseguire l'installazione:

```bash
./install.sh
```

Lo script eseguirà automaticamente:

* installazione di `openfortivpn` (se non presente)
* creazione directory configurazione

```
~/.config/openfortivpn
```

* recupero automatico del fingerprint del certificato VPN

File creati/aggiornati da `install.sh`:

* `~/.config/openfortivpn/` (directory)
* `~/.config/openfortivpn/config`
* `~/.config/openfortivpn/dnsservers`
* `~/.config/openfortivpn/dnsdomain`
* `~/.config/openfortivpn/dnsdomain-extra` (opzionale)

Durante l'installazione verranno richiesti:

* host VPN
* porta VPN
* username VPN
* password VPN
* DNS ASIENDALI (separati da spazio)
* Default domain
* Domini aggiuntivi (opzionale, separati da spazio)

---

# Utilizzo

Per connettersi alla VPN:

```bash
./vpn-aziendale.sh start
```
lo script restituisce il log completo resituito dal comando openfortivpn comprese informazioni sull'interfaccia ppp0 e i server dns e il default domain aggiunti dopo che il tunnel viene stabilito

Per disconnettersi:

```bash
./vpn-aziendale.sh stop
```

Per verificare lo stato della connessione:

```bash
./vpn-aziendale.sh status
```

Per una diagnostica completa (log estesi e riepilogo):

```bash
./vpn-aziendale.sh debug
```

---

# Verifica della connessione

Quando la VPN è attiva dovrebbe comparire l'interfaccia:

```
ppp0
```

Verifica:

```bash
ip address show ppp0
```

Controllo DNS assegnato dalla VPN:

```bash
resolvectl dns ppp0
```

Controllo domini e link di default:

```bash
resolvectl domain ppp0
resolvectl status
```

Nota importante sulla risoluzione dei nomi corti:

* il dominio su `ppp0` viene impostato come **routing domain** (`~comune.spoleto.local`) per limitare l'inoltro solo alle query interne
* i nomi **senza dominio** (es. `srvw3kdc01`) usano i *search domain* della **link di default**
* per questo lo script aggiunge `comune.spoleto.local` come **primo search domain** sulla link di default (es. `wlp2s0`)
* al comando `stop`, il dominio precedente viene ripristinato automaticamente

Portabilità su altri sistemi:

* lo script è **indipendente dal nome della link di default** (usa `ip route` per trovarla)
* gestisce automaticamente interfacce `pppX` create da `openfortivpn`
* **richiede `systemd-resolved` e `resolvectl`** per configurare i DNS
  * se `resolvectl` non è presente o `systemd-resolved` non è attivo, lo script segnala l'errore e si ferma

Log generati:

* `~/.config/openfortivpn/vpn-up.log` — log di openfortivpn e stato interfaccia
* `~/.config/openfortivpn/dns-apply.log` — tentativi di applicazione DNS con timestamp
* `~/.config/openfortivpn/debug.log` — output completo del comando `debug`
* `~/.config/openfortivpn/dnsdomain-extra` — domini aggiuntivi da risolvere via VPN (routing)

File creati/aggiornati da `vpn-aziendale.sh`:

* `~/.config/openfortivpn/vpn.pid` — PID della sessione VPN
* `~/.config/openfortivpn/vpn-up.log`
* `~/.config/openfortivpn/dns-apply.log`
* `~/.config/openfortivpn/debug.log`
* `~/.config/openfortivpn/dns-search.backup` — backup dei search domain della link di default
* `~/.config/openfortivpn/dnsdomain-extra` — domini aggiuntivi da risolvere via VPN (routing)

---

# Struttura del progetto

```
vpn-aziendale
│
├── install.sh
├── vpn-aziendale.sh
├── CHANGELOG.md
└── README.md
```

### install.sh

Script di installazione che:

* installa `openfortivpn`
* crea la configurazione
* recupera il fingerprint del certificato
* salva il file config

### vpn-aziendale.sh

Script principale per la gestione della VPN:

* avvio della connessione
* disconnessione
* verifica stato VPN
* diagnostica estesa (`debug`)

---

# Troubleshooting

### openfortivpn non installato

Installarlo manualmente:

```bash
sudo apt update
sudo apt install openfortivpn
```

---

### la VPN non si connette

Controllare:

* host VPN
* porta VPN
* username/password
* fingerprint certificato

---

### interfaccia ppp0 non presente

Controllare lo stato della connessione:

```bash
ip link show
```

---

# Sicurezza

I files di configurazione contiengono le credenziali, dns servers, default domain e vengono creati con permessi restrittivi:

```
chmod 600 ~/.config/openfortivpn/config
chmod 600 ~/.config/openfortivpn/dnsservers
chmod 600 ~/.config/openfortivpn/dnsdomain
chmod 600 ~/.config/openfortivpn/dnsdomain-extra
```

---

# Licenza

Questo progetto è distribuito sotto licenza open source.

---

# Autore

Andrea Rossetti

---

# Changelog

Vedi `CHANGELOG.md` per la lista delle modifiche per versione.
Ultimo rilascio: `v1.2.0`.

[1]: https://github.com/adrienverge/openfortivpn?utm_source=chatgpt.com "GitHub - adrienverge/openfortivpn: Client for PPP+TLS VPN tunnel services"
