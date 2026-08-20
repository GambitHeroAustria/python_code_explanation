#!/usr/bin/env bash
# Bereitet einen Deploy vor: prueft den Dateisatz, erzeugt deploy/expected.sha256
# aus dem aktuellen Stand und traegt den aktuellen Commit in deploy/build.sh ein.
#
# Vor jedem Deploy ausfuehren -- sonst deployt build.sh weiterhin den alten
# Commit, oder die Pruefsummen passen nicht zum Code und der Build bricht ab.
set -euo pipefail
cd "$(dirname "$0")/.."

SITE_FILES=(
  index.html
  app1.js app2.js app3.js app4.js app5.js app6.js
  style.css reveal.css event.css solo.css
  assets/postnasal-anleitung-animated.svg
  assets/postnasal-anleitung-static.svg
  assets/solo-prosecco-expert-club-brut.jpeg
  assets/solo-sancerre-enclos-maimbray-2022.jpeg
  assets/solo-tio-pepe-fino.jpeg
)

echo "-> Dateisatz validieren"
bash scripts/validate.sh

if [ -n "$(git status --porcelain "${SITE_FILES[@]}")" ]; then
  echo "ABBRUCH: Es gibt uncommittete Aenderungen an den Site-Dateien."
  echo "         Erst committen und pushen -- deployt wird immer ein Commit,"
  echo "         der auf GitHub liegt."
  exit 1
fi

SHA=$(git rev-parse HEAD)

echo "-> Pruefsummen schreiben (deploy/expected.sha256)"
sha256sum "${SITE_FILES[@]}" > deploy/expected.sha256

echo "-> Commit in deploy/build.sh eintragen: ${SHA}"
sed -i -E "s/^SHA=[0-9a-f]{40}$/SHA=${SHA}/" deploy/build.sh

cat <<EOF

Fertig. Naechste Schritte:
  1. deploy/build.sh und deploy/expected.sha256 committen und pushen
     (der Build laedt den Commit von GitHub -- ungepusht schlaegt er fehl).
  2. Ueber den Vercel-Connector deployen: die drei Dateien aus deploy/
     (vercel.json, build.sh, expected.sha256) als Payload, Projekt
     "weinabend-blind-live", erst target=preview, dann target=production.
  3. Anonym gegen den Production-Alias pruefen:
     for f in \$(cat deploy/expected.sha256 | awk '{print \$2}'); do
       curl -s -o "\$f" -w "%{http_code} \$f\n" "https://weinabend-blind-live.vercel.app/\$f"
     done
     danach: sha256sum -c deploy/expected.sha256
EOF
