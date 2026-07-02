webui="http://127.0.0.1:$WEBUI_PORT"
last_port=""

while true; do
  if ! natpmpc -a 1 0 udp 60 -g "$GATEWAY" >/dev/null 2>&1 \
     || ! tcp_out=$(natpmpc -a 1 0 tcp 60 -g "$GATEWAY" 2>&1); then
    echo "natpmpc request failed (is wg0 up?); retrying"
    sleep 5; continue
  fi

  port=$(printf '%s\n' "$tcp_out" \
    | sed -n 's/.*Mapped public port \([0-9]\{1,\}\).*/\1/p' | head -n1)
  if [ -z "$port" ]; then
    echo "could not parse forwarded port from natpmpc output; retrying"
    sleep 5; continue
  fi

  if [ "$port" = "$last_port" ]; then
    sleep 45; continue
  fi

  echo "forwarded port: $port (was ${last_port:-none}); updating qBittorrent"
  if curl -fsS -H "Referer: $webui" "$webui/api/v2/app/setPreferences" \
       --data-urlencode "json={\"listen_port\":$port,\"random_port\":false,\"upnp\":false}" \
       >/dev/null; then
    last_port="$port"
    sleep 45
  else
    echo "failed to push port to qBittorrent WebUI (not up yet?); retrying soon"
    sleep 5
  fi
done
