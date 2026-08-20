# Deploy nach Vercel

Der Zielzustand ist die Vercel-Git-Integration mit
`GambitHeroAustria/python_code_explanation`, Produktionsbranch `main`. Die
Root-`vercel.json` baut über `deploy/build-from-checkout.sh` und veröffentlicht
ausschließlich die 16 Dateien aus `scripts/site-files.txt`. Tests,
Dokumentation und Deploy-Helfer werden dadurch nicht öffentlich ausgeliefert.

Solange die Git-Integration noch nicht einmalig im Vercel-Dashboard verbunden
ist, bleibt der Connector-Deploy unten als sicherer Fallback verfügbar.

Früher wurden dabei alle Dateien einzeln als Payload hochgeladen. Das ist
fehleranfällig: `app5.js` allein hat ~46 KB minifiziertes JavaScript, und ein
einziges falsches Zeichen macht die Seite weiß, während der Build weiterhin
`READY` meldet.

Stattdessen besteht die Payload jetzt nur noch aus den drei Dateien in diesem
Verzeichnis. Der Build holt den **auf einen Commit gepinnten** Repo-Stand von
GitHub und vergleicht jede Datei gegen `expected.sha256`. Weicht ein Byte ab,
bricht der Build ab – es kann nichts Kaputtes live gehen.

## Ablauf

```bash
bash deploy/prepare.sh      # validiert, schreibt expected.sha256, pinnt den Commit
git add deploy/ && git commit && git push   # der Build lädt den Commit von GitHub
```

Danach über den Vercel-Connector deployen (`deploy_to_vercel`, Projekt
`weinabend-blind-live`, Team `gambitheroaustrias-projects`):

1. `target: "preview"` → Build-Log prüfen, dann per Share-URL
   (`get_access_to_vercel_url`) alle Dateien ziehen und `sha256sum -c` laufen
   lassen.
2. `target: "production"` → anonym über `weinabend-blind-live.vercel.app`
   dieselbe Prüfung wiederholen.

## Fallstricke

- `scripts/validate.sh` ist absichtlich POSIX-nah und benoetigt kein `/dev/fd`.
  Es laeuft lokal, in GitHub Actions und im Vercel-Build.
- **Preview-Deployments bekommen von Vercel ein Feedback-Skript in
  `index.html` injiziert.** Auf der Preview weicht deshalb genau diese eine
  Prüfsumme ab – das ist normal. Production liefert `index.html` unverändert aus.

## Deployment Protection

`ssoProtection: all_except_custom_domains`. Nur der Production-Alias ist anonym
erreichbar; jede einzelne Deployment-URL leitet anonym auf Vercel-SSO um. Ein
~478 KB großes „text/html" ist die SSO-Seite, kein Artefakt. Preview-URLs
deshalb nur mit Share-URL und wiederverwendetem Cookie-Jar prüfen.

## APP_VERSION

`APP_VERSION` in `app1.js` **nicht** ändern, solange Sitzungen laufen: bei einer
Änderung räumt die App `localStorage` aller Teilnehmer auf und laufende
Verkostungen gehen verloren. Der Host-Token überlebt das Aufräumen (die Routine
überspringt `wt_host_`).
