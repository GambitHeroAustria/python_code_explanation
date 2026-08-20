#!/usr/bin/env bash
# Validiert den Weinabend-Dateisatz: Syntax, Referenz-Vollständigkeit, keine Cross-Deployment-URLs.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

for f in app*.js; do
  node --check "$f" >/dev/null || { echo "SYNTAXFEHLER: $f"; fail=1; }
done

# index.html darf ausschließlich relative Referenzen enthalten
if grep -oE '(src|href)="https?://[^"]*"' index.html | grep -v fonts.googleapis; then
  echo "VERBOTEN: absolute URL-Referenz in index.html"; fail=1
fi

# Jede referenzierte Datei muss lokal existieren (Query-String abschneiden)
while read -r ref; do
  file="${ref%%\?*}"
  [ -f "$file" ] || { echo "FEHLT: $file (referenziert in index.html)"; fail=1; }
done < <(grep -oE '(src|href)="[^"]+"' index.html | sed -E 's/^(src|href)="//;s/"$//' | grep -v '^data:')

# Bild-/Asset-Referenzen aus JS und CSS
while read -r file; do
  [ -f "$file" ] || { echo "FEHLT: $file (referenziert in JS)"; fail=1; }
done < <(grep -ohE "assets/[A-Za-z0-9._-]+" app*.js | sort -u)
while read -r file; do
  [ -f "$file" ] || { echo "FEHLT: $file (referenziert in CSS)"; fail=1; }
done < <(grep -ohE "url\((['\"]?)[^)'\":]+\1\)" ./*.css 2>/dev/null | sed -E "s/^url\(['\"]?//;s/['\"]?\)$//" | grep -v '^data:' | sort -u)

# Keine Host-Tokens im Client
grep -nE "EMBEDDED_HOST='.+'|EMBEDDED_HOST=\"[^\"]+\"" app*.js index.html && { echo "VERBOTEN: eingebettetes Host-Token"; fail=1; }

[ $fail -eq 0 ] && echo "VALIDIERUNG OK: Dateisatz vollständig und autonom." || echo "VALIDIERUNG FEHLGESCHLAGEN"
exit $fail
