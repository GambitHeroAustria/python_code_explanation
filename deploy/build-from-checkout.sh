#!/usr/bin/env bash
# Vercel Git Build: validiert den ausgecheckten Commit und veroeffentlicht nur
# den expliziten App-Dateisatz. Repo-Dokumentation, Tests und Deploy-Helfer
# landen niemals im oeffentlichen Output.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/validate.sh
rm -rf public
mkdir -p public

count=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  mkdir -p "public/$(dirname "$file")"
  cp "$file" "public/$file"
  count=$((count + 1))
done < scripts/site-files.txt

commit_sha=${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse HEAD)}
printf '{"commit_sha":"%s","app_version":"stable-kiosk-20260818-1"}\n' "$commit_sha" > public/deploy-meta.json

actual=$(find public -type f | wc -l)
expected=$((count + 1))
if [ "$actual" -ne "$expected" ]; then
  echo "Unerwartete Dateizahl im Output: $actual statt $expected"
  exit 1
fi

echo "BUILD OK: $count App-Dateien plus deploy-meta.json aus $commit_sha."
