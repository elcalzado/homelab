WEBUI="http://127.0.0.1:$WEBUI_PORT"
IFACE="wg0"
LAST_PORT=""
TUNNEL_WAS_DOWN=true

set_qbt_port() {
  # $1 = listen_port, $2 = current_network_interface
  curl -fsS -H "Referer: $WEBUI" "$WEBUI/api/v2/app/setPreferences" \
    --data-urlencode "json={\"listen_port\":$1,\"current_network_interface\":\"$2\",\"random_port\":false,\"upnp\":false}" \
    >/dev/null
}

while true; do
  # Renew the mapping for both protocols; the gateway assigns the same port to both.
  if ! natpmpc -a 1 0 udp 60 -g "$GATEWAY" >/dev/null 2>&1 \
     || ! TCP_OUT=$(natpmpc -a 1 0 tcp 60 -g "$GATEWAY" 2>&1); then
    if [ "$TUNNEL_WAS_DOWN" = false ]; then
      echo "natpmpc request failed (is wg0 up?); resetting qBittorrent to lo/0"
      set_qbt_port 0 lo || true
      TUNNEL_WAS_DOWN=true
      LAST_PORT=""
    fi
    sleep 5; continue
  fi

  PORT=$(printf '%s\n' "$TCP_OUT" \
    | sed -n 's/.*Mapped public port \([0-9]\{1,\}\).*/\1/p' | head -n1)
  if [ -z "$PORT" ]; then
    echo "could not parse forwarded port from natpmpc output; retrying"
    sleep 5; continue
  fi

  if [ "$PORT" = "$LAST_PORT" ] && [ "$TUNNEL_WAS_DOWN" = false ]; then
    sleep 45; continue
  fi

  echo "forwarded port: $PORT (was ${LAST_PORT:-none}); updating qBittorrent"
  # Referer must match the WebUI host or qBittorrent's CSRF check rejects the POST.
  if set_qbt_port "$PORT" "$IFACE"; then
    LAST_PORT="$PORT"
    TUNNEL_WAS_DOWN=false
    sleep 45
  else
    echo "failed to push port to qBittorrent WebUI (not up yet?); retrying soon"
    sleep 5
  fi
done
