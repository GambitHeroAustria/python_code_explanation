-- Schreibfreier Regressionstest fuer die gemeinsame Optionsquelle und die
-- vollstaendige Solo-Detailaufloesung. Tokens und Zielprofile werden nicht
-- ausgegeben.
do $probe$
declare
  v_code text;
  v_token text;
  v_reveal jsonb;
  v_state jsonb;
  v_player jsonb;
  v_category record;
begin
  foreach v_code in array array['SOLOW1','SOLOW2'] loop
    select min(p.participant_token) into v_token
    from public.participants p
    join public.rooms r on r.id=p.room_id
    where r.code=v_code;

    v_reveal := public.solo_get_reveal_v2(v_code,v_token);
    v_state := public.solo_get_state(v_code,v_token);

    if jsonb_array_length(v_reveal->'players')=0 then
      raise exception '%: Detailspieler fehlen',v_code;
    end if;
    if v_reveal->'quiz_options' is distinct from v_state->'guess_options' then
      raise exception '%: Auswahl und Aufloesung verwenden verschiedene Optionen',v_code;
    end if;

    for v_category in
      select key,value from jsonb_each_text(v_reveal->'correct_guesses')
    loop
      if not exists(
        select 1 from jsonb_array_elements_text(v_reveal->'quiz_options'->v_category.key) x(value)
        where x.value=v_category.value
      ) then
        raise exception '%: richtige Antwort %/% war nicht auswaehlbar',v_code,v_category.key,v_category.value;
      end if;
    end loop;

    for v_player in select value from jsonb_array_elements(v_reveal->'players') loop
      if (v_player->>'score')::numeric is distinct from
         coalesce((v_player->'breakdown'->>'metrics')::numeric,0)
         +coalesce((v_player->'breakdown'->>'aromas')::numeric,0)
         +coalesce((v_player->'breakdown'->>'quiz')::numeric,0) then
        raise exception '%/%: Summe der Detailpunkte stimmt nicht',v_code,v_player->>'name';
      end if;
      if jsonb_array_length(v_player->'metrics')<>8
         or jsonb_array_length(v_player->'guesses')<>3 then
        raise exception '%/%: Detailkategorien unvollstaendig',v_code,v_player->>'name';
      end if;
    end loop;
  end loop;

  begin
    perform public.solo_get_reveal_v2('SOLOW3','ungueltig');
    raise exception 'LOCK_PROBE_FAILED';
  exception when others then
    if sqlerrm='LOCK_PROBE_FAILED' then raise; end if;
    if sqlerrm<>'Die Auflösung ist noch gesperrt.' then raise; end if;
  end;
end
$probe$;
