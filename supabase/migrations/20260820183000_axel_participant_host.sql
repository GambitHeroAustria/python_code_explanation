-- Axel can operate the event host controls through one of his existing
-- participant sessions. The event host token stays server-side and is never
-- returned to the browser.
create table if not exists public.event_host_participants (
  event_id uuid not null references public.tasting_events(id) on delete cascade,
  participant_id uuid not null references public.participants(id) on delete cascade,
  granted_at timestamptz not null default now(),
  primary key (event_id, participant_id)
);

alter table public.event_host_participants enable row level security;
revoke all on table public.event_host_participants from public, anon, authenticated;
create index if not exists event_host_participants_participant_id_idx
  on public.event_host_participants(participant_id);

create or replace function private.require_participant_event_host(
  p_event_code text,
  p_participant_tokens text[]
)
returns public.tasting_events
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_event public.tasting_events%rowtype;
begin
  if coalesce(array_length(p_participant_tokens, 1), 0) = 0
     or array_length(p_participant_tokens, 1) > 20 then
    raise exception 'Keine gültige Host-Sitzung gefunden.';
  end if;

  select e.* into v_event
  from public.tasting_events e
  where upper(e.code) = upper(btrim(p_event_code))
    and exists (
      select 1
      from public.event_host_participants eh
      join public.participants p on p.id = eh.participant_id
      join public.rooms r on r.id = p.room_id
      where eh.event_id = e.id
        and r.event_id = e.id
        and p.participant_token = any(p_participant_tokens)
    )
  limit 1;

  if not found then
    raise exception 'Diese Teilnehmer-Sitzung hat keine Host-Berechtigung.';
  end if;

  return v_event;
end
$function$;

revoke all on function private.require_participant_event_host(text, text[])
  from public, anon, authenticated;

create or replace function public.participant_host_get_event_state(
  p_event_code text,
  p_participant_tokens text[]
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_event public.tasting_events%rowtype;
begin
  v_event := private.require_participant_event_host(p_event_code, p_participant_tokens);
  return public.host_get_event_state(v_event.code, v_event.host_token);
end
$function$;

create or replace function public.participant_host_set_room_phase(
  p_event_code text,
  p_participant_tokens text[],
  p_room_code text,
  p_phase text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_event public.tasting_events%rowtype;
begin
  v_event := private.require_participant_event_host(p_event_code, p_participant_tokens);
  return public.host_set_room_phase(v_event.code, v_event.host_token, p_room_code, p_phase);
end
$function$;

create or replace function public.participant_host_reveal_pair(
  p_event_code text,
  p_participant_tokens text[],
  p_room_code text,
  p_profile_a_glass integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_event public.tasting_events%rowtype;
begin
  v_event := private.require_participant_event_host(p_event_code, p_participant_tokens);
  return public.host_reveal_pair(
    v_event.code,
    v_event.host_token,
    p_room_code,
    p_profile_a_glass
  );
end
$function$;

revoke all on function public.participant_host_get_event_state(text, text[])
  from public, anon, authenticated;
revoke all on function public.participant_host_set_room_phase(text, text[], text, text)
  from public, anon, authenticated;
revoke all on function public.participant_host_reveal_pair(text, text[], text, integer)
  from public, anon, authenticated;

grant execute on function public.participant_host_get_event_state(text, text[])
  to anon, authenticated;
grant execute on function public.participant_host_set_room_phase(text, text[], text, text)
  to anon, authenticated;
grant execute on function public.participant_host_reveal_pair(text, text[], text, integer)
  to anon, authenticated;

insert into public.event_host_participants(event_id, participant_id)
select e.id, p.id
from public.tasting_events e
join public.rooms r on r.event_id = e.id
join public.participants p on p.room_id = r.id
where upper(e.code) = 'BURGUND'
  and lower(btrim(p.display_name)) = 'axel'
on conflict do nothing;
