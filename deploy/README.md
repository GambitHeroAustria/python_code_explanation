# Deploy-Ordner – Weinabend Blind Tasting

`index.html` in diesem Ordner ist die verifizierte Fassung **`netlify-20260819-4`** (V4),
gesichert am 19.08.2026 direkt vom laufenden Netlify-Deploy.

## Kanonische Site

**https://hilarious-caramel-feef55.netlify.app** – nur diese Domain an Mitspieler geben.

Grund: localStorage (Teilnehmer-Tokens) ist pro Domain getrennt. Ein Domainwechsel
mitten im Abend wirft alle Teilnehmer aus ihrer Sitzung.

Andere Netlify-Projekte im selben Team (NICHT verwenden):

| Site | Version | Hinweis |
|---|---|---|
| poetic-clafoutis-b01ef4 | V3 | veraltet, 2–5-Aromenregel |
| serene-medovik-185f16   | V2 | veraltet |
| joyful-marigold-d5af4a  | –  | passwortgeschuetzt, liefert HTTP 401 |

## Deploy

Manueller Netlify-Drop-Upload dieses Ordners. Kein Build-Schritt.

## Achtung: Workflow ueberschreibt index.html im Repo-Root

`.github/workflows/deploy-wine-night.yml` zieht bei jedem Push auf `main` die
Datei `/index.html` frisch von der Supabase Edge Function `wine-night-gh` und
committet sie darueber. Diese Edge Function liefert Stand 19.08.2026 noch die
alte Fassung `github-preview-20260818-1` (ohne 2–4-Aromenregel, mit
localStorage-Wipe-Bug).

Deshalb liegt V4 hier unter `deploy/` und nicht im Repo-Root.

## Verifizierte V4-Merkmale

- `APP_VERSION='netlify-20260819-4'`
- kein localStorage-Wipe bei Versionswechsel
- Session-Wiederaufnahme in `roomBoot()` ueber gespeicherten Token
- eigene Meldung bei bereits vergebenem Namen
- 2–4-Aromenregel: Text, Zaehler `x/4`, Blockade der 5. Auswahl, Vollstaendigkeitspruefung
- die sieben Aroma-IDs stimmen mit der Backend-Validierung ueberein

## Sicherheitshinweis

Der Host-Zugang laesst sich aus dem ausgelieferten Frontend clientseitig ableiten.
Bewusst akzeptiert fuer diesen Abend (Details in der Arbeitssitzung vom 19.08.2026).
Relevant, weil `host_reset_room` Teilnehmer und Antworten unwiderruflich loescht.
Vor einer breiteren Nutzung: Host-Token rotieren und aus dem Frontend entfernen.
