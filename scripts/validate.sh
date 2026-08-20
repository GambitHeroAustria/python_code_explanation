#!/usr/bin/env bash
# Validiert den Weinabend-Dateisatz: Syntax, Referenz-Vollstaendigkeit,
# reproduzierbarer Output, keine Cross-Deployment-URLs und keine Host-Secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
tmp_base=${TMPDIR:-.}
tmp_dir=$(mktemp -d "$tmp_base/wineabend-validate.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

manifest=scripts/site-files.txt
if [ ! -f "$manifest" ]; then
  echo "FEHLT: $manifest"; exit 1
fi

while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || { echo "FEHLT: $file (Site-Manifest)"; fail=1; }
done < "$manifest"

if [ "$(sort "$manifest" | uniq -d | wc -l)" -ne 0 ]; then
  echo "FEHLER: doppelte Datei im Site-Manifest"; fail=1
fi

find . -maxdepth 1 -type f -name 'app*.js' -printf '%f\n' | sort > "$tmp_dir/javascript-files"
while IFS= read -r file; do
  node --check "$file" >/dev/null || { echo "SYNTAXFEHLER: $file"; fail=1; }
done < "$tmp_dir/javascript-files"

# index.html darf nur lokale App-Dateien referenzieren. Externe Fonts waeren
# erlaubt; Vercel-Deployment-URLs sind im gesamten Client verboten.
grep -oE '(src|href)="https?://[^"]*"' index.html > "$tmp_dir/absolute-refs" || true
if grep -v 'fonts.googleapis.com' "$tmp_dir/absolute-refs" | grep -q .; then
  grep -v 'fonts.googleapis.com' "$tmp_dir/absolute-refs"
  echo "VERBOTEN: absolute URL-Referenz in index.html"; fail=1
fi
if grep -nE 'https?://[^"'"'"'[:space:]]*vercel\.app' index.html app*.js ./*.css; then
  echo "VERBOTEN: Cross-Deployment-URL im Client"; fail=1
fi

# Jede Referenz aus index.html muss lokal existieren (Query-String entfernen).
grep -oE '(src|href)="[^"]+"' index.html \
  | sed -E 's/^(src|href)="//;s/"$//' \
  | grep -vE '^(data:|https?://)' > "$tmp_dir/index-refs" || true
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  file="${ref%%\?*}"
  [ -f "$file" ] || { echo "FEHLT: $file (index.html)"; fail=1; }
  grep -Fxq "$file" "$manifest" || { echo "FEHLT IM MANIFEST: $file"; fail=1; }
done < "$tmp_dir/index-refs"

# Bild-/Asset-Referenzen aus JS und CSS.
grep -ohE 'assets/[A-Za-z0-9._-]+' app*.js | sort -u > "$tmp_dir/js-assets" || true
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || { echo "FEHLT: $file (JS)"; fail=1; }
  grep -Fxq "$file" "$manifest" || { echo "FEHLT IM MANIFEST: $file"; fail=1; }
done < "$tmp_dir/js-assets"

grep -ohE "url\((['\"]?)[^)'\":]+\1\)" ./*.css 2>/dev/null \
  | sed -E "s/^url\(['\"]?//;s/['\"]?\)$//" \
  | grep -v '^data:' | sort -u > "$tmp_dir/css-assets" || true
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || { echo "FEHLT: $file (CSS)"; fail=1; }
done < "$tmp_dir/css-assets"

# Schutz fuer laufende Teilnehmer-Sessions und Host-Credentials.
grep -Fq "const APP_VERSION='stable-kiosk-20260818-1';" app1.js \
  || { echo "VERBOTEN: APP_VERSION wurde unerwartet geaendert"; fail=1; }
if grep -nE "EMBEDDED_HOST='[^']+'|EMBEDDED_HOST=\"[^\"]+\"" app*.js index.html; then
  echo "VERBOTEN: eingebettetes Host-Token"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "VALIDIERUNG OK: Dateisatz vollstaendig, autonom und secret-frei."
else
  echo "VALIDIERUNG FEHLGESCHLAGEN"
fi
exit "$fail"
