# Changelog

## v1.2.0

### DNS reliability
- Fixed false negatives when PPP link is state UNKNOWN by detecting any `pppX` interface.
- Added wait for PPP interface presence, IP assignment, and route to DNS servers before DNS setup.
- Wait for systemd-resolved to register the PPP link before applying DNS.

### DNS behavior
- Apply VPN DNS servers and routing domain (`~comune.spoleto.local`) to the PPP link.
- Add VPN search domain to the default interface and force it to be first in the list.
- Backup and restore default interface search domains on stop.

### Diagnostics
- Added `dns-apply.log` with per-try timestamps and `resolvectl` output.
- Expanded debug report with VPN iface/IP/DNS/domains and default iface domains.
- Added `resolv.conf` mode to debug summary.
- Added checks for `resolvectl` and `systemd-resolved` (fatal in `start`, warning in `debug`).

### Docs
- Documented routing-domain behavior and search-domain priority.
- Documented portability assumptions and `systemd-resolved` requirement.
