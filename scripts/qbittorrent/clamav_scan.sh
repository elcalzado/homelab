TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ] || [ ! -e "$TARGET_PATH" ]; then
  echo "$(date): Error: target path invalid or missing: '$TARGET_PATH'" >> "$SCAN_LOG"
  exit 1
fi

# -r recursive. --database points clamscan at the freshclam-managed DB
set +e
output="$(clamscan -r --database="$CLAMAV_DB" "$TARGET_PATH" 2>&1)"
rc=$?
set -e

case "$rc" in
  0)  # clean
    mv "$TARGET_PATH" "$TARGET_PATH.ready"
    ;;
  1)  # threat found
    echo "$(date): THREAT DETECTED in $TARGET_PATH" >> "$SCAN_LOG"
    echo "$output" >> "$SCAN_LOG"
    ;;
  *)  # 2 (or other) = scan error
    echo "$(date): SCAN ERROR (rc=$rc) for $TARGET_PATH" >> "$SCAN_LOG"
    echo "$output" >> "$SCAN_LOG"
    ;;
esac
