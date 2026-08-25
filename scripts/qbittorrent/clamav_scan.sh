TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ] || [ ! -e "$TARGET_PATH" ]; then
  echo "$(date): Error: target path invalid or missing: '$TARGET_PATH'" >> "$SCAN_LOG"
  exit 1
fi

# -r recursive. --database points clamscan at the freshclam-managed DB
set +e
output="$(clamdscan --fdpass --multiscan "$TARGET_PATH" 2>&1)"
rc=$?
set -e

case "$rc" in
  0)  # clean: leave the download in place so seeding + *arr import proceed
    ;;
  1)  # threat found: log the evidence, then delete the offending file/dir
    echo "$(date): THREAT DETECTED in $TARGET_PATH [DELETED]" >> "$SCAN_LOG"
    echo "$output" >> "$SCAN_LOG"
    rm -rf "$TARGET_PATH"
    ;;
  *)  # 2 (or other) = scan error
    echo "$(date): SCAN ERROR (rc=$rc) for $TARGET_PATH" >> "$SCAN_LOG"
    echo "$output" >> "$SCAN_LOG"
    ;;
esac
