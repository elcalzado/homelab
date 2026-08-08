# Network

## Host addresses

| Host        | Address       | Platform |
|-------------|---------------|----------|
| omada       | `10.0.10.2`   | LXC      |
| qbittorrent | `10.0.30.5`   | VM       |
| glance      | `10.0.30.6`   | LXC      |
| jellyfin    | `10.0.30.7`   | VM       |
| servarr     | `10.0.30.8`   | VM       |
| immich      | `10.0.30.9`   | VM       |

## qbittorrent VPN / kill-switch

The qbittorrent service tunnels all traffic through a VPN (`wg0`) and enforces
a default-drop nftables kill-switch. If `wg0` drops, only the VPN handshake and
the LAN subnets remain reachable.
