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

* creazione files di configurazione

```
~/.config/openfortivpn/config
~/.config/openfortivpn/dnsservers
~/.config/openfortivpn/dnsdomain
```

* recupero automatico del fingerprint del certificato VPN

Durante l'installazione verranno richiesti:

* host VPN
* porta VPN
* username VPN
* password VPN
* DNS ASIENDALI (separati da spazio)
* Default domain

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

---

# Struttura del progetto

```
vpn-aziendale
│
├── install.sh
├── vpn-aziendale.sh
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
```

---

# Licenza

Questo progetto è distribuito sotto licenza open source.

---

# Autore

Andrea Rossetti

[1]: https://github.com/adrienverge/openfortivpn?utm_source=chatgpt.com "GitHub - adrienverge/openfortivpn: Client for PPP+TLS VPN tunnel services"
