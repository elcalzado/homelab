port=$(sed -n 's/^eap\.mongod\.port=\([0-9][0-9]*\).*$/\1/p' "$PROPERTIES")
[ -n "$port" ] || {
  printf 'omada-mongodump: no eap.mongod.port in %s\n' "$PROPERTIES" >&2
  exit 1
}

work="$DUMP_DIR.new"
rm -rf "${work:?}"
mongodump --host 127.0.0.1 --port "$port" --out "$work" --quiet
rm -rf "${DUMP_DIR:?}"
mv "$work" "$DUMP_DIR"
