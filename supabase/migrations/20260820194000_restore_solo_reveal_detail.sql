-- Keep solo quiz options, validation and reveal truth in one server-side source,
-- and restore the complete per-player reveal payload.

create or replace function private.solo_guess_options(p_code text)
returns jsonb
language sql
immutable
set search_path = ''
as $function$
  select case upper(btrim(p_code))
    when 'SOLOW2' then jsonb_build_object(
      'grape',  jsonb_build_array('Glera','Chardonnay','Sauvignon Blanc','Riesling'),
      'region', jsonb_build_array('Prosecco DOC','Franciacorta','Loire','Mosel'),
      'price',  jsonb_build_array('unter 10 €','10–20 €','20–30 €','über 30 €')
    )
    when 'SOLOW3' then jsonb_build_object(
      'grape',  jsonb_build_array('Palomino Fino','Pedro Ximénez','Moscatel','Glera'),
      'region', jsonb_build_array('Jerez','Montilla-Moriles','Madeira','Marsala'),
      'price',  jsonb_build_array('unter 10 €','10–20 €','20–30 €','über 30 €')
    )
    else jsonb_build_object(
      'grape',  jsonb_build_array('Sauvignon Blanc','Chardonnay','Riesling','Petit Courbu/Petit Manseng'),
      'region', jsonb_build_array('Loire','Burgund','Elsass','Südwestfrankreich'),
      'price',  jsonb_build_array('unter 10 €','10–20 €','20–30 €','über 30 €')
    )
  end;
$function$;

revoke all on function private.solo_guess_options(text)
  from public, anon, authenticated;

create or replace function private.solo_participant_detail(
  p_participant public.participants,
  p_answer public.answers,
  p_expected jsonb
)
returns jsonb
language sql
stable
set search_path = ''
as $function$
  with metric_rows(key, actual, target, max_score, sort_order) as (
    values
      ('nose_intensity', p_answer.nose_intensity, (p_expected->>'nose_intensity')::integer, 2::numeric, 1),
      ('oak', p_answer.oak, (p_expected->>'oak')::integer, 2::numeric, 2),
      ('body', p_answer.body, (p_expected->>'body')::integer, 3::numeric, 3),
      ('tannin', p_answer.tannin, (p_expected->>'tannin')::integer,
        case when p_expected ? 'freshness' then 2 else 3 end::numeric, 4),
      ('acidity', p_answer.acidity, (p_expected->>'acidity')::integer,
        case when p_expected ? 'freshness' then 2 else 3 end::numeric, 5),
      ('freshness', p_answer.freshness, (p_expected->>'freshness')::integer,
        case when p_expected ? 'freshness' then 1 else 0 end::numeric, 6),
      ('finish', p_answer.finish, (p_expected->>'finish')::integer,
        case when p_expected ? 'finish_intensity' then 2 else 3 end::numeric, 7),
      ('finish_intensity', p_answer.finish_intensity, (p_expected->>'finish_intensity')::integer,
        case when p_expected ? 'finish_intensity' then 2 else 0 end::numeric, 8)
  ),
  metrics as (
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'key', key,
        'value', actual,
        'target', target,
        'score', private.metric_score(actual, target, max_score),
        'max', max_score
      ) order by sort_order), '[]'::jsonb) as items,
      coalesce(sum(private.metric_score(actual, target, max_score)), 0) as score,
      coalesce(sum(max_score), 0) as max_score
    from metric_rows
    where max_score > 0
  ),
  selected_aromas as (
    select value, ordinality
    from unnest(coalesce(p_answer.aromas, '{}'::text[])) with ordinality a(value, ordinality)
  ),
  expected_aromas as (
    select value, ordinality
    from jsonb_array_elements_text(coalesce(p_expected->'aromas', '[]'::jsonb)) with ordinality a(value, ordinality)
  ),
  aromas as (
    select jsonb_build_object(
      'selected', coalesce((select jsonb_agg(value order by ordinality) from selected_aromas), '[]'::jsonb),
      'expected', coalesce((select jsonb_agg(value order by ordinality) from expected_aromas), '[]'::jsonb),
      'matched', coalesce((select jsonb_agg(e.value order by e.ordinality) from expected_aromas e where exists(select 1 from selected_aromas s where s.value=e.value)), '[]'::jsonb),
      'missed', coalesce((select jsonb_agg(e.value order by e.ordinality) from expected_aromas e where not exists(select 1 from selected_aromas s where s.value=e.value)), '[]'::jsonb),
      'extra', coalesce((select jsonb_agg(s.value order by s.ordinality) from selected_aromas s where not exists(select 1 from expected_aromas e where e.value=s.value)), '[]'::jsonb),
      'score', least(3, (select count(*) from expected_aromas e where exists(select 1 from selected_aromas s where s.value=e.value))),
      'max', 3
    ) as detail
  ),
  quiz_rows(key, selected, expected, max_score, sort_order) as (
    values
      ('grape', p_participant.grape_guess, p_expected->>'grape', 3::numeric, 1),
      ('region', p_participant.region_guess, p_expected->>'region', 3::numeric, 2),
      ('price', p_participant.price_guess, p_expected->>'price', 2::numeric, 3)
  ),
  quiz as (
    select
      jsonb_agg(jsonb_build_object(
        'key', key,
        'selected', selected,
        'expected', expected,
        'correct', selected is not distinct from expected,
        'score', case when selected is not distinct from expected then max_score else 0 end,
        'max', max_score
      ) order by sort_order) as items,
      sum(case when selected is not distinct from expected then max_score else 0 end) as score,
      sum(max_score) as max_score
    from quiz_rows
  )
  select jsonb_build_object(
    'name', p_participant.display_name,
    'score', round(metrics.score + (aromas.detail->>'score')::numeric + quiz.score, 1),
    'max_score', metrics.max_score + (aromas.detail->>'max')::numeric + quiz.max_score,
    'breakdown', jsonb_build_object(
      'metrics', metrics.score,
      'metrics_max', metrics.max_score,
      'aromas', (aromas.detail->>'score')::numeric,
      'aromas_max', (aromas.detail->>'max')::numeric,
      'quiz', quiz.score,
      'quiz_max', quiz.max_score
    ),
    'metrics', metrics.items,
    'aromas', aromas.detail,
    'guesses', quiz.items,
    'note', p_answer.note
  )
  from metrics, aromas, quiz;
$function$;

revoke all on function private.solo_participant_detail(
  public.participants, public.answers, jsonb
) from public, anon, authenticated;

create or replace function public.solo_get_state(
  p_code text,
  p_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_participant public.participants%rowtype;
begin
  select * into v_room
  from public.rooms
  where upper(code)=upper(btrim(p_code)) and tasting_type='white_solo';
  if not found then raise exception 'Einzelquiz nicht gefunden.'; end if;

  if p_token is not null then
    select * into v_participant
    from public.participants
    where room_id=v_room.id and participant_token=p_token;
  end if;

  return jsonb_build_object(
    'room_code', v_room.code,
    'theme', coalesce(v_room.theme,v_room.title),
    'phase', v_room.phase,
    'guess_options', private.solo_guess_options(v_room.code),
    'me', case when v_participant.id is null then null else jsonb_build_object(
      'name',v_participant.display_name,
      'submitted',v_participant.submitted_at is not null,
      'guess_submitted',v_participant.guess_submitted_at is not null
    ) end
  );
end
$function$;

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
set search_path = ''
as $function$
declare
  v_participant_id uuid;
  v_code text := upper(btrim(p_code));
  v_options jsonb := private.solo_guess_options(p_code);
  v_grapes text[];
  v_regions text[];
  v_prices text[];
  v_legacy_grapes constant text[] := array['Sauvignon Blanc','Chardonnay','Glera','Palomino Fino','Riesling','Petit Courbu/Petit Manseng'];
  v_legacy_regions constant text[] := array['Loire','Burgund','Prosecco DOC','Jerez','Elsass','Südwestfrankreich'];
begin
  select array_agg(value) into v_grapes from jsonb_array_elements_text(v_options->'grape');
  select array_agg(value) into v_regions from jsonb_array_elements_text(v_options->'region');
  select array_agg(value) into v_prices from jsonb_array_elements_text(v_options->'price');
  v_grapes := v_grapes || v_legacy_grapes;
  v_regions := v_regions || v_legacy_regions;

  select p.id into v_participant_id
  from public.participants p
  join public.rooms r on r.id=p.room_id
  where upper(r.code)=v_code and p.participant_token=p_token
    and r.tasting_type='white_solo' and r.phase='tasting';
  if v_participant_id is null then raise exception 'Teilnehmer-Token ungültig.'; end if;

  if not exists(
    select 1 from public.answers
    where participant_id=v_participant_id and glass_no=1 and is_complete
  ) then
    raise exception 'Bitte zuerst den Wein vollständig bewerten.';
  end if;

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
  where id=v_participant_id;
  return jsonb_build_object('ok',true);
end
$function$;

create or replace function public.solo_get_reveal_v2(
  p_code text,
  p_token text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_participant_id uuid;
  v_expected jsonb;
  v_wine jsonb;
  v_players jsonb;
  v_leaderboard jsonb;
begin
  select * into v_room
  from public.rooms
  where upper(code)=upper(btrim(p_code)) and tasting_type='white_solo';
  if not found or v_room.phase<>'revealed' then
    raise exception 'Die Auflösung ist noch gesperrt.';
  end if;

  select id into v_participant_id
  from public.participants
  where room_id=v_room.id and participant_token=p_token;
  if v_participant_id is null then raise exception 'Teilnehmer-Token ungültig.'; end if;

  select w.expected,
         jsonb_build_object(
           'name',w.display_name,
           'vintage',w.vintage,
           'details',w.resolution_data
         )
  into v_expected, v_wine
  from public.wines w
  where w.slug=v_room.glass1_slug;

  select coalesce(jsonb_agg(detail order by (detail->>'score')::numeric desc, p.created_at), '[]'::jsonb)
  into v_players
  from public.participants p
  join public.answers a on a.participant_id=p.id and a.glass_no=1
  cross join lateral private.solo_participant_detail(p,a,v_expected) detail
  where p.room_id=v_room.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'name', player->>'name',
    'score', (player->>'score')::numeric,
    'max_score', (player->>'max_score')::numeric
  ) order by ordinality), '[]'::jsonb)
  into v_leaderboard
  from jsonb_array_elements(v_players) with ordinality x(player, ordinality);

  return jsonb_build_object(
    'room_code',v_room.code,
    'theme',coalesce(v_room.theme,v_room.title),
    'wine',v_wine,
    'quiz_options',private.solo_guess_options(v_room.code),
    'correct_guesses',jsonb_build_object(
      'grape',v_expected->>'grape',
      'region',v_expected->>'region',
      'price',v_expected->>'price'
    ),
    'players',v_players,
    'leaderboard',v_leaderboard
  );
end
$function$;

revoke all on function public.solo_get_reveal_v2(text,text)
  from public, anon, authenticated;
grant execute on function public.solo_get_reveal_v2(text,text)
  to anon, authenticated;

