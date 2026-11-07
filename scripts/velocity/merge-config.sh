TARGET="$DATA_DIR/velocity.toml"

if [ ! -f "$TARGET" ]; then
    exit 0
fi

base_json=$(yj -tj < "$TARGET")
overrides_json=$(yj -tj < "$OVERRIDES_FILE")

merged_json=$(jq -n \
    --argjson base "$base_json" \
    --argjson overrides "$overrides_json" \
    '($base | del(.servers, .["forced-hosts"])) * $overrides')

echo "$merged_json" | yj -jt > "$TARGET"