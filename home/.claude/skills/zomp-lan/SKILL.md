---
name: zomp-lan
description: Zomp conventions for a home or office LAN - which host addresses are reserved for which kind of device, keeping DHCP reservations outside the dynamic pool, adding or moving a reservation on an OpenWrt router with uci, and the randomized-MAC and lease-renewal catches. Load this before reserving, assigning or changing a device's IP address, or changing a router's DHCP pool.
---

# LAN addressing

These extend `AGENTS.md`, which stays in force.

## Address plan

On a /24 LAN with the router at `.1`, the last octet says what a device is:

| Range | For |
|---|---|
| `.2`-`.19` | network gear and shared devices: access points, switches, printers, NAS |
| `.20`-`.49` | PCs and servers |
| `.50`-`.99` | phones and tablets |
| `.100`-`.249` | DHCP pool: guests and anything without a reservation |

- **Every reservation goes below `.100`, never inside the pool.** An address below `.100` was set on purpose; one from `.100` up is passing through. A reservation inside the pool can collide with a lease another device already holds.
- **Take the next free address in the device's range.** Check both the reservations and the live leases first.
- **A device found in the pool that others depend on (a printer, a server) gets moved into its range,** not reserved where it happens to sit.
- **Leave reservations for other networks alone.** An entry whose address is outside this LAN's subnet may belong to a device the user keeps on another network; ask before removing it.

## OpenWrt (uci)

Look before changing anything: `uci show dhcp | grep -E '@host\[[0-9]+\]\.(name|mac|ip)='`, `cat /tmp/dhcp.leases`, and `uci show dhcp.lan` for the pool (`start`, `limit`).

Add a reservation, skipping it if the MAC already has one:

```sh
uci show dhcp | grep -qi '<mac>' && echo already || {
  s=$(uci add dhcp host)
  uci set dhcp.$s.name='<name>'; uci set dhcp.$s.mac='<mac>'; uci set dhcp.$s.ip='<ip>'
  uci commit dhcp; /etc/init.d/dnsmasq reload
}
```

To move one, `uci set dhcp.@host[<i>].ip=...`, then the same commit and reload.

## Catches

- **The device keeps its old address until it renews its lease.** Reconnecting its Wi-Fi or rebooting it does that at once; otherwise it happens at lease expiry. Say which, and check `/tmp/dhcp.leases` afterwards.
- **Phones and tablets use a randomized MAC per network.** It stays stable until the network is forgotten and re-joined, which changes it and silently orphans the reservation. Confirm the MAC from the live lease, not from the device's hardware MAC.
- **Reservation names don't always resolve in DNS.** Reach a device by its IP, or add a `Host` entry to `~/.ssh/config`, rather than changing the router's DNS unasked.
