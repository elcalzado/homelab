# Network

## Host addresses

| Host        | Address       | Platform |
|-------------|---------------|----------|
| glance      | `10.0.30.6`   | LXC      |
| qbittorrent | `10.0.30.5`   | VM       |
| omada       | `10.0.10.2`   | LXC      |

## qbittorrent VPN / kill-switch

The qbittorrent service tunnels all traffic through a VPN (`wg0`) and enforces a
default-drop nftables kill-switch. If `wg0` drops, only the VPN handshake and the
LAN subnets remain reachable.
