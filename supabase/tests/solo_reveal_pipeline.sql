-- Privilegierter, schreibfreier Regressionstest fuer den kompletten
-- Solo-Aufloesungspfad. Die innere Exception rollt die Testfreigabe sicher
-- zurueck; Host-Token und Zielwerte werden nie ausgegeben.
do $probe$
declare
  v_before text;
  v_ready integer;
  v_total integer;
  v_old_rounds integer;
  v_old_max numeric;
  v_result jsonb;
  v_overview jsonb;
  v_room jsonb;
begin
  select phase into v_before from public.rooms where code='SOLOW1';
  select count(*), count(*) filter(
    where submitted_at is not null and guess_submitted_at is not null
  ) into v_total,v_ready
  from public.participants
  where room_id=(select id from public.rooms where code='SOLOW1');

  if v_total=0 or v_ready<>v_total then
    raise exception 'SOLOW1 ist nicht vollstaendig: % von %',v_ready,v_total;
  end if;

  select (x->'timeline'->>'round_count')::int,
         (x->'timeline'->>'event_max')::numeric
  into v_old_rounds,v_old_max
  from (select public.get_event_overview('BURGUND') x) q;

  begin
    v_result := public.participant_host_set_room_phase(
      'BURGUND',
      array[(
        select p.participant_token
        from public.participants p
        join public.rooms r on r.id=p.room_id
        where r.code='SOLOW1' and lower(btrim(p.display_name))='axel'
        limit 1
      )],
      'SOLOW1',
      'revealed'
    );
    v_overview := public.get_event_overview('BURGUND');

    if (v_overview->'timeline'->>'round_count')::int<>v_old_rounds+1 then
      raise exception 'Runde fehlt im Punkteverlauf';
    end if;
    if (v_overview->'timeline'->>'event_max')::numeric<>v_old_max+27 then
      raise exception 'Falsches neues Abendmaximum';
    end if;

    select x into v_room
    from jsonb_array_elements(v_overview->'rooms') x
    where x->>'code'='SOLOW1';
    if v_room is null or jsonb_array_length(v_room->'leaderboard')<>v_total then
      raise exception 'Solo-Leaderboard unvollstaendig';
    end if;

    raise exception 'PROBE_ROLLBACK';
  exception when others then
    if sqlerrm<>'PROBE_ROLLBACK' then raise; end if;
  end;

  if (select phase from public.rooms where code='SOLOW1') is distinct from v_before then
    raise exception 'Testfreigabe wurde nicht zurueckgerollt';
  end if;
end
$probe$;
