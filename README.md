# VPN Aziendale

Script Bash semplice e robusto per connettersi alla SSL/VPN aziendale (FORTINET) tramite **openfortivpn** su sistemi Linux.

Progettato per ambienti **Kubuntu / Ubuntu**, consente di:

- avviare la VPN
- disconnettere la VPN
- verificare lo stato della connessione

Lo script gestisce automaticamente:

- autenticazione
- log della connessione
- notifiche desktop
- gestione del processo VPN

---

# Requisiti

- Linux (testato su Kubuntu)
- sudo
- openfortivpn

Installazione dipendenze:

```bash
Da ora è automatizzata nello script install.sh
