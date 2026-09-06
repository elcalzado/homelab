#!/usr/bin/env bash
overall=0
for file in secrets/*.yaml; do
  plain=$(mktemp)
  chmod 600 "$plain"
  sops -d "$file" > "$plain" 2>/dev/null

  mapfile -t keys_b64 < <(
    yq eval -o=json '[.. | select(tag == "!!map") | select(has("sshKey")) | .sshKey | select(. != null and . != "")]' "$plain" 2>/dev/null \
      | jq -r '.[] | @base64'
  )

  if [ "${#keys_b64[@]}" -eq 0 ]; then
    printf 'NONE %s\n' "$file"
  else
    status=OK
    for enc in "${keys_b64[@]}"; do
      tmp=$(mktemp)
      chmod 600 "$tmp"
      base64 -d <<< "$enc" > "$tmp"
      ssh-keygen -y -f "$tmp" >/dev/null 2>&1 || status=BAD
      rm -f "$tmp"
    done
    printf '%s %s\n' "$status" "$file"
    [ "$status" = BAD ] && overall=1
  fi

  rm -f "$plain"
done
exit "$overall"