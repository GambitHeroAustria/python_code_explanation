#!/usr/bin/env bash
# Baut das Weinabend-Deployment byte-exakt aus einem gepinnten Repo-Commit.
# Das Repo ist die Quelle (Handover, Regel 2) -- deployt wird nie ein von Hand
# hochgeladenes Artefakt, sondern genau der Stand, der lokal getestet wurde.
#
# scripts/validate.sh laeuft bewusst NICHT hier, sondern lokal vor dem Deploy:
# es nutzt Process Substitution, die im Vercel-Build-Container nicht verfuegbar
# ist (/dev/fd fehlt, "line 20: /dev/fd/63: No such file or directory"). Der
# sha256-Vergleich unten ist die strengere Pruefung -- er belegt jede einzelne
# Datei byte-genau gegen den lokal getesteten Stand. Weicht ein Byte ab, bricht
# der Build ab und es geht nichts live.
set -euo pipefail
SHA=495ba92abdf58ac76dc437b69f9582b71e2e1d2f
REPO=GambitHeroAustria/python_code_explanation

rm -rf src public
mkdir -p src public

echo "-> Hole Repo-Stand ${SHA}"
curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/${SHA}" | tar xz --strip-components=1 -C src

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

echo "-> Keine Fremddateien im Output"
test "$(cd public && find . -type f | wc -l)" -eq 16 || { echo "Unerwartete Dateizahl im Output"; exit 1; }

echo "BUILD OK: 16 Dateien, alle Pruefsummen identisch."
