-- ============================================================================
-- Raum "Olis Rote" (OLIRED) anlegen
-- Event: BURGUND · Typ: red_simple · Stand 19.08.2026
--
-- IN DIESER REIHENFOLGE AUSFUEHREN. Schritt 1 ist reine Discovery und aendert
-- nichts. Erst nach Schritt 1 wissen wir, wie Schritt 2 und 3 aussehen muessen.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- SCHRITT 1 — DISCOVERY (nur lesen, aendert nichts)
-- Ergebnisse zurueckgeben, dann werden Schritt 2/3 exakt darauf zugeschnitten.
-- ----------------------------------------------------------------------------

-- 1a) Wie sieht ein fertiger red_simple-Raum aus? REDSMP ist die Vorlage.
select to_jsonb(r) as room
from public.rooms r
where r.code = 'REDSMP';

-- 1b) Welche Spalten hat rooms wirklich, und welche haben Defaults?
--     Spalten ohne Default und ohne NULL-Erlaubnis muessen im INSERT stehen.
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'rooms'
order by ordinal_position;

-- 1c) Dasselbe fuer wines.
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'wines'
order by ordinal_position;

-- 1d) Die beiden REDSMP-Weine als Vorlage — zeigt Feldnamen UND Wertebereiche.
select to_jsonb(w) as wine
from public.wines w
join public.rooms r on r.id = w.room_id
where r.code = 'REDSMP'
order by w.glass_no;
-- Falls die Verknuepfung anders heisst, stattdessen:  select to_jsonb(w) from public.wines w;

-- 1e) WICHTIG: Wie viele erwartete Aromen haben die REDSMP-Weine?
--     Das Frontend erlaubt seit V4 nur noch 2-4 Aromen. Wenn hier 5er-Sets
--     stehen, kann niemand die vollen 3 Aromapunkte erreichen und das
--     Scoring ist gegen die Spieler verzerrt. Dann muessen die Sets auf
--     hoechstens 4 gekuerzt werden, BEVOR gespielt wird.
select r.code, w.glass_no, w.aromas, cardinality(w.aromas) as anzahl
from public.wines w
join public.rooms r on r.id = w.room_id
order by r.code, w.glass_no;

-- 1f) Aktueller Teilnehmerstand — sind das nur Testreste?
select r.code, p.name, p.created_at
from public.participants p
join public.rooms r on r.id = p.room_id
order by r.code, p.created_at;


-- ----------------------------------------------------------------------------
-- SCHRITT 2 — RAUM ANLEGEN
-- Entwurf. Spaltennamen gegen 1a/1b abgleichen, bevor ausgefuehrt wird.
-- ----------------------------------------------------------------------------

insert into public.rooms (event_id, code, title, theme, intro, phase, tasting_type)
select
  r.event_id,
  'OLIRED',
  'Olis Rote',
  'Olis Rote',
  'Zwei Rotweine aus Frankreich blind verkosten: Loire gegen Suedrhone. Sechs Regler plus 2-4 Aromarichtungen pro Glas.',
  'tasting',
  'red_simple'
from public.rooms r
where r.code = 'REDSMP'
on conflict (code) do nothing;
-- Uebernimmt event_id direkt von REDSMP, damit der Raum garantiert im
-- richtigen Event landet. Hat rooms weitere NOT-NULL-Spalten ohne Default
-- (etwa eine Sortierung), muessen die aus 1b ergaenzt werden.


-- ----------------------------------------------------------------------------
-- SCHRITT 3 — WEINE ANLEGEN
-- Die Regler-Sollwerte (1-5) sind ein begruendeter Vorschlag aus den
-- Datenblaettern, keine gemessenen Werte. Vor dem Abend gegenlesen:
-- sie bestimmen, wofuer es Punkte gibt.
-- ----------------------------------------------------------------------------

-- Glas 1 — Sancerre Rouge "Terres Blanches" 2022, M. & E. Roblin
--          Loire, 100 % Pinot Noir, 13 %
--          hell, frisch, seidig; lebendige Saeure, zarte Tannine, dezentes Holz
insert into public.wines
  (room_id, glass_no, name, blurb, nose_intensity, oak, body, tannin, acidity, finish, aromas)
select
  r.id, 1,
  'Sancerre Rouge "Terres Blanches" 2022, M. & E. Roblin',
  'Hell, frisch und seidig, mit klarer Kirsch- und roter Beerenfrucht, feiner Kraeuterwuerze, lebendiger Saeure und zartem, geschliffenem Tannin.',
  3,  -- nose_intensity: klar, aber nicht laut
  2,  -- oak / Wuerze-Roestung: 10-12 Monate, teils Demi-Muids, sehr zurueckhaltend
  2,  -- body: leicht bis mittel
  2,  -- tannin: zart, geschliffen
  4,  -- acidity: lebendig, das Erkennungsmerkmal
  3,  -- finish: mittellang, fein
  array['kirsche_pflaume','gewuerze_kraeuter','holz_roestung']
from public.rooms r
where r.code = 'OLIRED';

-- Glas 2 — Vacqueyras "La Cour de Montmirail" 2024, Terranea
--          Suedrhone, ca. 50 % Grenache / 40 % Syrah / 10 % Mourvedre, 14,5 %
--          warm, dicht, wuerzig; kraeftiger Tanningriff
insert into public.wines
  (room_id, glass_no, name, blurb, nose_intensity, oak, body, tannin, acidity, finish, aromas)
select
  r.id, 2,
  'Vacqueyras "La Cour de Montmirail" 2024, Terranea',
  'Warm, dicht und wuerzig, mit reifer dunkler Beerenfrucht, mediterranen Kraeutern und Pfeffer sowie Anklaengen von Lakritz und Kakao und kraeftigem Tanningriff.',
  4,  -- nose_intensity: ausladend
  4,  -- oak / Wuerze-Roestung: Pfeffer, Kraeuter, Kakao-Hauch
  5,  -- body: dicht, 14,5 %
  4,  -- tannin: kraeftiger Griff
  2,  -- acidity: warm-suedlich, niedrig
  4,  -- finish: lang
  array['dunkle_beeren','gewuerze_kraeuter','kakao_kaffee','lakritz_erdig']
from public.rooms r
where r.code = 'OLIRED';

-- Beide Aroma-Sets liegen bei 3 bzw. 4 Eintraegen und damit innerhalb der
-- 2-4-Regel. Volle Aromapunkte sind erreichbar.
--
-- ACHTUNG Einschenk-Reihenfolge: Glas 1 = Sancerre, Glas 2 = Vacqueyras.
-- Am Abend muss physisch genauso eingeschenkt werden, sonst ist die Aufloesung
-- vertauscht. Soll es umgekehrt sein, hier die beiden glass_no tauschen.


-- ----------------------------------------------------------------------------
-- SCHRITT 4 — VERIFIKATION (nur lesen)
-- ----------------------------------------------------------------------------

select r.code, r.title, r.tasting_type, r.phase,
       w.glass_no, w.name, cardinality(w.aromas) as aromen_anzahl, w.aromas
from public.rooms r
left join public.wines w on w.room_id = r.id
where r.code = 'OLIRED'
order by w.glass_no;
-- Erwartet: zwei Zeilen, tasting_type = red_simple, phase = tasting,
-- Glas 1 mit 3 Aromen, Glas 2 mit 4 Aromen.


-- ----------------------------------------------------------------------------
-- SCHRITT 5 — TESTRESTE ENTFERNEN
-- REDSMP und VTHOI0 haben Stand 19.08.2026 je einen Teilnehmer.
-- Erst 1f pruefen, ob das wirklich Testdaten sind. Loeschen ist endgueltig.
-- Danach: FREEZE.
-- ----------------------------------------------------------------------------

-- Bevorzugt ueber die App: Host-Screen -> Paar zuruecksetzen.
-- Direkt per SQL nur, wenn das nicht geht — auskommentiert, damit nichts
-- versehentlich ausgefuehrt wird:
--
-- delete from public.answers a
--  using public.participants p, public.rooms r
--  where a.participant_id = p.id and p.room_id = r.id and r.code in ('REDSMP','VTHOI0');
--
-- delete from public.participants p
--  using public.rooms r
--  where p.room_id = r.id and r.code in ('REDSMP','VTHOI0');
