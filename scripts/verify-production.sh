#!/usr/bin/env bash
# Anonymer Produktionscheck: Status, Content-Type und SHA-256 aller App-Dateien.
set -euo pipefail
cd "$(dirname "$0")/.."

base=${BASE:-https://weinabend-blind-live.vercel.app}
tmp_base=${TMPDIR:-.}
tmp_dir=$(mktemp -d "$tmp_base/wineabend-production.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

while read -r expected file; do
  [ -z "${file:-}" ] && continue
  mkdir -p "$tmp_dir/$(dirname "$file")"
  headers="$tmp_dir/headers"
  curl -fsS -D "$headers" -o "$tmp_dir/$file" "$base/$file"

  case "$file" in
    *.html) wanted='text/html' ;;
    *.js) wanted='javascript' ;;
    *.css) wanted='text/css' ;;
    *.svg) wanted='image/svg+xml' ;;
    *.jpeg) wanted='image/jpeg' ;;
    *) wanted='' ;;
  esac
  if [ -n "$wanted" ] && ! tr -d '\r' < "$headers" | grep -i '^content-type:' | grep -qi "$wanted"; then
    echo "FALSCHER CONTENT-TYPE: $file (erwartet $wanted)"
    exit 1
  fi
  actual=$(sha256sum "$tmp_dir/$file" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    echo "FALSCHE PRUEFSUMME: $file"
    exit 1
  fi
  echo "OK $file"
done < deploy/expected.sha256

echo "PRODUCTION OK: alle App-Dateien anonym, typkorrekt und byte-identisch."
