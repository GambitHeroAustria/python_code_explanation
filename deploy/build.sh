#!/usr/bin/env bash
# Baut das Weinabend-Deployment byte-exakt aus einem gepinnten Repo-Commit.
# Das Repo ist die Quelle (Handover, Regel 2) -- deployt wird nie ein von Hand
# hochgeladenes Artefakt, sondern genau der Stand, der lokal getestet wurde.
#
# Die portable Validierung und der SHA-256-Vergleich laufen beide im Build.
set -euo pipefail
SHA=974f270933e63b547bc14023b5c740535deed738
REPO=GambitHeroAustria/python_code_explanation

rm -rf src public
mkdir -p src public

echo "-> Hole Repo-Stand ${SHA}"
curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/${SHA}" | tar xz --strip-components=1 -C src

echo "-> Validiere Repo-Stand"
( cd src && bash scripts/validate.sh )

echo "-> Uebernehme ausschliesslich die Site-Dateien"
cp src/index.html src/app1.js src/app2.js src/app3.js src/app4.js src/app5.js src/app6.js public/
cp src/style.css src/reveal.css src/event.css src/solo.css public/
mkdir -p public/assets
cp src/assets/postnasal-anleitung-animated.svg src/assets/postnasal-anleitung-static.svg public/assets/
cp src/assets/solo-prosecco-expert-club-brut.jpeg src/assets/solo-sancerre-enclos-maimbray-2022.jpeg src/assets/solo-tio-pepe-fino.jpeg public/assets/

echo "-> Byte-Vergleich gegen die lokal getesteten Pruefsummen"
( cd public && sha256sum -c ../expected.sha256 )

echo "-> Kein Host-Token im Client"
! grep -qE "EMBEDDED_HOST='.+'|EMBEDDED_HOST=\"[^\"]+\"" public/app*.js public/index.html

printf '{"commit_sha":"%s","app_version":"stable-kiosk-20260818-1"}\n' "$SHA" > public/deploy-meta.json

echo "-> Keine Fremddateien im Output"
test "$(cd public && find . -type f | wc -l)" -eq 17 || { echo "Unerwartete Dateizahl im Output"; exit 1; }

echo "BUILD OK: 16 App-Dateien, alle Pruefsummen identisch, plus Deploy-Metadaten."
