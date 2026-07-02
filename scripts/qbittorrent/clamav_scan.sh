TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ] || [ ! -e "$TARGET_PATH" ]; then
  echo "$(date): Error: target path invalid or missing: '$TARGET_PATH'" >> "$SCAN_LOG"
  exit 1
fi

# -r recursive, --quiet only reports on detection. Exit 0 = clean.
if clamscan -r --quiet "$TARGET_PATH"; then
  mv "$TARGET_PATH" "$TARGET_PATH.ready"
else
  # Exit 1 = threat found, 2 = error. Leave the file in place for review.
  echo "$(date): THREAT DETECTED or ERROR scanning $TARGET_PATH" >> "$SCAN_LOG"
fi
