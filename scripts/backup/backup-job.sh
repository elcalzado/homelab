fail() {
  printf 'backup: %s\n' "$*" >&2
  exit 1
}

failures=0

soft() {
  printf 'backup: %s\n' "$*" >&2
  failures=$((failures + 1))
}

staged_names="|"

claim() {
  staged_names="$staged_names$1|"
}

stage_sqlite() {
  local src=$1
  local dest=$2
  local verdict
  local tables

  [ -f "$src" ] || {
    soft "sqlite database missing: $src"
    return 1
  }
  rm -f "$dest.new" "$dest.new-wal" "$dest.new-shm"
  sqlite3 "$src" ".backup '$dest.new'" || {
    soft "sqlite could not copy $src"
    rm -f "$dest.new"
    return 1
  }
  verdict=$(sqlite3 "$dest.new" 'PRAGMA quick_check' 2>&1) || verdict="unreadable"
  tables=$(sqlite3 "$dest.new" "SELECT count(*) FROM sqlite_schema WHERE type = 'table'" 2>&1) || tables=""
  rm -f "$dest.new-wal" "$dest.new-shm"
  [ "$verdict" = ok ] || {
    soft "quick_check on the copy of $src said: $verdict"
    rm -f "$dest.new"
    return 1
  }
  case "$tables" in
  '' | 0 | *[!0-9]*)
    soft "the copy of $src holds no tables"
    rm -f "$dest.new"
    return 1
    ;;
  esac
  mv "$dest.new" "$dest"
}

stage_postgres() {
  local database=$1
  local dest=$2
  local trailer

  runuser -u postgres -- pg_dump --clean --if-exists --dbname="$database" >"$dest.new" || {
    soft "pg_dump failed for database $database"
    rm -f "$dest.new"
    return 1
  }
  trailer=$(tail -c 4096 "$dest.new" 2>/dev/null) || trailer=""
  case "$trailer" in
  *"PostgreSQL database dump complete"*) ;;
  *)
    soft "pg_dump did not run to completion for database $database"
    rm -f "$dest.new"
    return 1
    ;;
  esac
  mv "$dest.new" "$dest"
}

stage_mongodb() {
  local port=$1
  local dest=$2

  rm -rf "${dest:?}.new"
  mongodump --host 127.0.0.1 --port "$port" --out "$dest.new" --quiet || {
    soft "mongodump failed against port $port"
    rm -rf "${dest:?}.new"
    return 1
  }
  if [ -z "$(find "$dest.new" -mindepth 2 -name '*.bson' \
    -not -path '*/admin/*' -not -path '*/config/*' -print -quit)" ]; then
    soft "mongodump from port $port holds no application collections"
    rm -rf "${dest:?}.new"
    return 1
  fi
  rm -rf "${dest:?}"
  mv "$dest.new" "$dest"
}

stage_database() {
  local engine=$1
  local arg=$2
  local out=$3

  claim "$out"
  case "$engine" in
  sqlite) stage_sqlite "$arg" "$STAGE/$out" ;;
  postgres) stage_postgres "$arg" "$STAGE/$out" ;;
  mongodb) stage_mongodb "$arg" "$STAGE/$out" ;;
  *)
    soft "unknown database engine: $engine"
    return 1
    ;;
  esac
}

stage_file() {
  local src=$1
  local name=${src##*/}

  claim "$name"
  [ -f "$src" ] || {
    soft "file missing: $src"
    return 1
  }
  cp -p "$src" "$STAGE/$name" || {
    soft "could not copy $src"
    return 1
  }
}

stage_tree() {
  local src=$1
  local name=${src##*/}
  local dest="$STAGE/$name"

  claim "$name"
  [ -d "$src" ] || {
    soft "tree missing: $src"
    return 1
  }
  rm -rf "${dest:?}.new"
  rsync --recursive --links --perms --times \
    "${exclude_args[@]}" "$src/" "$dest.new/" || {
    soft "could not mirror $src"
    rm -rf "${dest:?}.new"
    return 1
  }
  case "$empty_allowed" in
  *"|$src|"*) ;;
  *)
    if [ -z "$(find "$dest.new" -type f -print -quit)" ]; then
      soft "tree staged with no files: $src"
      rm -rf "${dest:?}.new"
      return 1
    fi
    ;;
  esac
  rm -rf "${dest:?}"
  mv "$dest.new" "$dest"
}

require_fresh() {
  local src
  while IFS= read -r src <&3; do
    [ -n "$src" ] || continue
    [ -n "$(find "$src" -type f -newermt "-$MAX_AGE_HOURS hours" -print -quit)" ] ||
      soft "nothing under $src is newer than $MAX_AGE_HOURS hours"
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

empty_allowed="|"
while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  empty_allowed="$empty_allowed$path|"
done 3<<<"$MAY_BE_EMPTY"

while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  stage_file "$path" || true
done 3<<<"$FILES"

while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  stage_tree "$path" || true
done 3<<<"$TREES"

while IFS=$'\t' read -r engine arg out <&3; do
  [ -n "$engine" ] || continue
  stage_database "$engine" "$arg" "$out" || true
done 3<<<"$DATABASES"

if [ -n "$MAX_AGE_HOURS" ]; then
  require_fresh
fi

drop_unstaged

if [ -z "$(find "$STAGE" -type f -print -quit)" ]; then
  fail "staging holds no files; refusing to ship"
fi

rsync \
  --recursive --links --perms --times \
  --inplace --block-size=32768 \
  --delete-after --max-delete="$MAX_DELETE" \
  --timeout=300 \
  --rsh="ssh -i $IDENTITY -o IdentitiesOnly=yes -o StrictHostKeyChecking=$STRICT_HOST_KEY -o UserKnownHostsFile=$KNOWN_HOSTS" \
  "$STAGE/" "$REMOTE"

if [ "$failures" -gt 0 ]; then
  fail "$failures artifact(s) failed; shipped the rest, marker withheld"
fi

date --iso-8601=seconds >"$MARKER"
