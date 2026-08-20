-- Reproduzierbare Definition der raumspezifischen Solo-Quiz-Whitelist.
-- Keine Zielantworten oder Host-Secrets werden hier gespeichert.
create or replace function public.solo_save_guesses(
  p_code text,
  p_token text,
  p_grape text,
  p_region text,
  p_price text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  pid uuid;
  v_code text := upper(trim(p_code));
  v_grapes text[];
  v_regions text[];
  v_prices constant text[] := array['unter 10 €','10–20 €','20–30 €','über 30 €'];
  v_legacy_grapes constant text[] := array['Sauvignon Blanc','Chardonnay','Glera','Palomino Fino','Riesling','Petit Courbu/Petit Manseng'];
  v_legacy_regions constant text[] := array['Loire','Burgund','Prosecco DOC','Jerez','Elsass','Südwestfrankreich'];
begin
  select p.id into pid
  from public.participants p
  join public.rooms r on r.id=p.room_id
  where upper(r.code)=v_code
    and p.participant_token=p_token
    and r.tasting_type='white_solo'
    and r.phase='tasting';

  if pid is null then raise exception 'Teilnehmer-Token ungültig.'; end if;
  if not exists(
    select 1 from public.answers
    where participant_id=pid and glass_no=1 and is_complete
  ) then
    raise exception 'Bitte zuerst den Wein vollständig bewerten.';
  end if;

  if v_code='SOLOW2' then
    v_grapes := array['Glera','Chardonnay','Sauvignon Blanc','Riesling'];
    v_regions := array['Prosecco DOC','Franciacorta','Loire','Mosel'];
  elsif v_code='SOLOW3' then
    v_grapes := array['Palomino Fino','Pedro Ximénez','Moscatel','Glera'];
    v_regions := array['Jerez','Montilla-Moriles','Madeira','Marsala'];
  else
    v_grapes := array['Sauvignon Blanc','Chardonnay','Riesling','Petit Courbu/Petit Manseng'];
    v_regions := array['Loire','Burgund','Elsass','Südwestfrankreich'];
  end if;

  v_grapes := v_grapes || v_legacy_grapes;
  v_regions := v_regions || v_legacy_regions;

  if not (p_grape=any(v_grapes))
     or not (p_region=any(v_regions))
     or not (p_price=any(v_prices)) then
    raise exception 'Ungültige Schätzantwort.';
  end if;

  update public.participants
  set grape_guess=p_grape,
      region_guess=p_region,
      price_guess=p_price,
      guess_submitted_at=now()
  where id=pid;

  return jsonb_build_object('ok',true);
end
$function$;
