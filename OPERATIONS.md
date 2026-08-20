# Weinabend: Betriebs- und Aenderungsworkflow

## Verbindliche Quellen

- **App-Code und UI-Logik:** GitHub, Branch `main`.
- **Weine, Zielprofile, Raumtexte und Phasen:** Supabase-Projekt
  `ttympdkjbtuspmroasae`. Diese Inhalte wirken sofort und gehoeren wegen der
  Spoilergefahr nicht ins oeffentlich deployte Dateiset.
- **Production:** Vercel-Projekt `weinabend-blind-live`, immer aus `main` oder
  als gepinnter Connector-Fallback aus einem Git-Commit.

## Normaler Code-Ablauf

1. Aenderung auf einem Arbeitsbranch umsetzen.
2. `npm run validate` und `npm run test:frontend` gegen einen lokalen Server.
3. Pull Request nach `main`; der GitHub-Check wiederholt Validierung und
   Chromium-Test gegen die echte Supabase.
4. Nach dem Merge baut Vercel automatisch aus `main`. Der Build bricht ab,
   sobald Syntax, Referenzen, APP_VERSION, Dateimanifest oder Secret-Pruefung
   fehlschlagen.
5. `BASE=https://weinabend-blind-live.vercel.app bash scripts/verify-production.sh`
   prueft Production anonym und byte-genau.

## Inhaltsaenderungen

Inhalte werden ueber den Supabase-Connector in einer Transaktion geprueft und
danach gezielt geschrieben. Kein Vercel-Deploy. Vor einer Aufloesung werden
Teilnehmerzahl, abgeschlossene Bewertungen und Tipps geprueft. Zielprofile und
Aufloesungstexte duerfen weder ins Repo noch in ein Vercel-Artefakt gelangen.

## Host-Aufloesung eines Einzelweins

Die App zeigt die Schaltflaeche nur, wenn alle Teilnehmer Bewertung und Tipps
abgeschlossen haben. `host_set_room_phase(..., 'revealed')` prueft dieselbe
Bedingung nochmals serverseitig. Danach verwenden Einzelraum-Leaderboard,
Abend-Leaderboard und Punkteverlauf dieselbe Funktion
`private.event_round_scores`; ein abweichender zweiter Rechenweg existiert
nicht.

## Sicherheitsregeln

- Kein Host-Token in Client, Git, Logs, Handover oder Deployment.
- `APP_VERSION='stable-kiosk-20260818-1'` bleibt waehrend laufender Sessions
  unveraendert.
- Keine absoluten Vercel-Deployment-URLs im Client.
- Kein Editieren von Production-Artefakten.
- Der Host-PIN ist nur ein Bedienungsriegel; die echte Berechtigung bleibt der
  serverseitige Host-Token.
