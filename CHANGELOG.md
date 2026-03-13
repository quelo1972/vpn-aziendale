# Changelog

## Unreleased

### DNS e domini extra
- Supporto a `dnsdomain-extra` per aggiungere routing domain aggiuntivi su `pppX`.
- Aggiunto comando `reload-dns` per ricaricare DNS/domains senza disconnessione.
- Cleanup DNS/domains piu' pulito allo `stop`.

### Diagnostica
- Verifica dei routing domain applicati (inclusi extra).
- Test attivo di risoluzione: `resolvectl query comune.spoleto.pg.it`.

### Documentazione
- Aggiornato README con domini extra, diagnostica e nuovo comando.

## v1.2.0

### Affidabilità DNS
- Corretti i falsi negativi quando il link PPP è in stato UNKNOWN rilevando qualsiasi interfaccia `pppX`.
- Aggiunta attesa di presenza interfaccia PPP, assegnazione IP e route verso i DNS prima della configurazione DNS.
- Attesa che systemd-resolved registri il link PPP prima di applicare i DNS.

### Comportamento DNS
- Applicati i DNS VPN e il routing domain (`~comune.spoleto.local`) al link PPP.
- Aggiunto il dominio di ricerca VPN alla interfaccia di default e forzata la priorità come primo in lista.
- Backup e ripristino dei domini di ricerca della interfaccia di default allo stop.

### Diagnostica
- Aggiunto `dns-apply.log` con timestamp per tentativo e output di `resolvectl`.
- Esteso il report di debug con interfaccia/IP/DNS/domini VPN e domini della interfaccia di default.
- Aggiunto `resolv.conf` mode nel riepilogo debug.
- Aggiunti controlli per `resolvectl` e `systemd-resolved` (fatale in `start`, warning in `debug`).

### Documentazione
- Documentato il comportamento dei routing-domain e la priorità dei search-domain.
- Documentate le assunzioni di portabilità e il requisito di `systemd-resolved`.
