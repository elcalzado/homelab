fail() {
  printf 'backup: %s\n' "$*" >&2
  exit 1
}

staged_names="|"

stage_database() {
  local src=$1
  local dest
  local verdict
  [ -f "$src" ] || fail "database missing: $src"
  dest="$STAGE/${src##*/}"
  sqlite3 "$src" ".backup '$dest.new'"
  verdict=$(sqlite3 "$dest.new" 'PRAGMA quick_check')
  rm -f "$dest.new-wal" "$dest.new-shm"
  [ "$verdict" = ok ] || fail "quick_check failed for $src: $verdict"
  mv "$dest.new" "$dest"
  staged_names="$staged_names${src##*/}|"
}

stage_file() {
  local src=$1
  [ -f "$src" ] || fail "file missing: $src"
  cp -p "$src" "$STAGE/${src##*/}"
  staged_names="$staged_names${src##*/}|"
}

stage_tree() {
  local src=$1
  [ -d "$src" ] || fail "tree missing: $src"
  rsync --recursive --links --perms --times --delete \
    "${exclude_args[@]}" "$src/" "$STAGE/${src##*/}/"
  staged_names="$staged_names${src##*/}|"
}

require_fresh() {
  local src
  while IFS= read -r src <&3; do
    [ -n "$src" ] || continue
    [ -n "$(find "$src" -type f -newermt "-$MAX_AGE_HOURS hours" -print -quit)" ] ||
      fail "nothing under $src is newer than $MAX_AGE_HOURS hours"
  done 3<<<"$MAX_AGE_PATHS"
}

drop_unstaged() {
  local entry
  while IFS= read -r entry <&3; do
    case "$staged_names" in
    *"|${entry##*/}|"*) ;;
    *) rm -rf -- "$entry" ;;
    esac
  done 3< <(find "$STAGE" -mindepth 1 -maxdepth 1)
}

exclude_args=()
while IFS= read -r pattern <&3; do
  [ -n "$pattern" ] || continue
  exclude_args+=(--exclude "$pattern")
done 3<<<"$EXCLUDES"

while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  stage_database "$path"
done 3<<<"$DATABASES"

while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  stage_file "$path"
done 3<<<"$FILES"

while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  stage_tree "$path"
done 3<<<"$TREES"

if [ -n "$MAX_AGE_HOURS" ]; then
  require_fresh
fi

drop_unstaged

if [ -z "$(find "$STAGE" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  fail "staging is empty; refusing to ship"
fi

rsync \
  --recursive --links --perms --times \
  --inplace --block-size=32768 \
  --delete-after --max-delete="$MAX_DELETE" \
  --timeout=300 \
  --rsh="ssh -i $IDENTITY -o IdentitiesOnly=yes -o StrictHostKeyChecking=$STRICT_HOST_KEY -o UserKnownHostsFile=$KNOWN_HOSTS" \
  "$STAGE/" "$REMOTE"

date --iso-8601=seconds >"$MARKER"
