create or replace function private.event_expert_awards(p_event_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $function$
with scored_answers as (
  select
    p.display_name as name,
    r.tasting_type,
    a.id as answer_id,
    case
      when r.tasting_type = 'white_solo' then
        (private.solo_breakdown(a, w.expected)->>'aromas')::numeric
      when r.tasting_type in ('red_simple', 'white_simple') then
        greatest(
          0::numeric,
          (private.answer_breakdown_v2(
            r.tasting_type, a.nose_intensity, a.swirl_open, a.aromas,
            a.acidity, a.freshness, a.tannin, a.body, a.texture, a.oak,
            a.mineral, a.retronasal, a.finish, a.finish_intensity, w.expected
          )->>'aromas')::numeric
          - private.metric_score(a.oak, nullif(w.expected->>'simple_oak', '')::integer, 2)
        )
      else null
    end as aroma_points,
    case when r.tasting_type in ('white_solo', 'red_simple', 'white_simple') then 3::numeric end as aroma_max,
    case when r.tasting_type = 'red_simple' and w.expected ? 'simple_tannin'
      then private.metric_score(a.tannin, nullif(w.expected->>'simple_tannin', '')::integer, 1)
    end as tannin_points,
    case when r.tasting_type = 'red_simple' and w.expected ? 'simple_tannin' then 1::numeric end as tannin_max,
    case
      when r.tasting_type = 'white_solo' then
        private.metric_score(a.nose_intensity, nullif(w.expected->>'nose_intensity', '')::integer, 2)
      when r.tasting_type in ('red_simple', 'white_simple') then
        private.metric_score(a.nose_intensity, nullif(w.expected->>'simple_nose', '')::integer, 2)
        + case when w.expected ? 'simple_retronasal'
            then private.metric_score(a.retronasal, nullif(w.expected->>'simple_retronasal', '')::integer, 2)
            else 0::numeric
          end
      else null
    end as nasal_points,
    case
      when r.tasting_type = 'white_solo' then 2::numeric
      when r.tasting_type in ('red_simple', 'white_simple') then
        2::numeric + case when w.expected ? 'simple_retronasal' then 2::numeric else 0::numeric end
    end as nasal_max
  from public.rooms r
  join public.participants p on p.room_id = r.id
  join public.answers a on a.participant_id = p.id and a.is_complete
  join public.wines w on w.slug = case a.glass_no when 1 then r.glass1_slug else r.glass2_slug end
  where r.event_id = p_event_id
    and r.phase = 'revealed'
), category_rows as (
  select s.name, v.kind, v.label, v.icon, v.points, v.max_points, s.answer_id
  from scored_answers s
  cross join lateral (values
    ('aroma', 'Aroma-Experte', '🍇', s.aroma_points, s.aroma_max),
    ('tannin', 'Tannin-Experte', '🍷', s.tannin_points, s.tannin_max),
    ('nasal', 'Nasal-Experte', '👃', s.nasal_points, s.nasal_max)
  ) v(kind, label, icon, points, max_points)
  where v.points is not null and v.max_points > 0
), totals as (
  select kind, label, icon, name,
         sum(points) as points, sum(max_points) as max_points,
         count(distinct answer_id) as samples
  from category_rows
  group by kind, label, icon, name
), ranked as (
  select *, row_number() over (
    partition by kind
    order by points / nullif(max_points, 0) desc, samples desc, lower(name), name
  ) as place
  from totals
), winners as (
  select *, case kind when 'aroma' then 1 when 'tannin' then 2 else 3 end as sort_order
  from ranked where place = 1
)
select coalesce(jsonb_agg(jsonb_build_object(
  'kind', kind,
  'label', label,
  'icon', icon,
  'name', name,
  'points', round(points, 1),
  'max_points', round(max_points, 1),
  'accuracy', round(100 * points / nullif(max_points, 0)),
  'samples', samples
) order by sort_order), '[]'::jsonb)
from winners;
$function$;

revoke all on function private.event_expert_awards(uuid) from public, anon, authenticated;

create or replace function public.get_event_overview(p_event_code text)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public', 'private', 'pg_temp'
as $function$
declare
  ev public.tasting_events%rowtype;
  items jsonb;
  timeline jsonb;
begin
  select * into ev from public.tasting_events where upper(code)=upper(trim(p_event_code));
  if not found then raise exception 'Event nicht gefunden.'; end if;
  timeline := private.event_timeline(ev.id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'code',r.code,'theme',coalesce(r.theme,r.title),'tasting_type',r.tasting_type,'sort_order',r.sort_order,
    'leaderboard',coalesce((select jsonb_agg(jsonb_build_object('name',s.display_name,'score',s.score,'max_score',s.max_score) order by s.score desc,s.display_name) from private.event_round_scores(ev.id) s where s.room_id=r.id),'[]'::jsonb),
    'wines',case when r.tasting_type='white_solo' then jsonb_build_array(
      (select jsonb_build_object('name',w.display_name,'vintage',w.vintage,'profile',w.profile_data,'details',w.resolution_data) from public.wines w where w.slug=r.glass1_slug)
    ) else jsonb_build_array(
      (select jsonb_build_object('name',w.display_name,'vintage',w.vintage,'profile',w.profile_data,'details',w.resolution_data) from public.wines w where w.slug=r.glass1_slug),
      (select jsonb_build_object('name',w.display_name,'vintage',w.vintage,'profile',w.profile_data,'details',w.resolution_data) from public.wines w where w.slug=r.glass2_slug)
    ) end
  ) order by r.sort_order,r.created_at),'[]'::jsonb)
  into items from public.rooms r where r.event_id=ev.id and r.phase='revealed';

  return jsonb_build_object(
    'code',ev.code,'title',ev.title,'description',ev.description,
    'rooms',items,'timeline',timeline,
    'expert_awards',private.event_expert_awards(ev.id)
  );
end;
$function$;

revoke all on function public.get_event_overview(text) from public;
grant execute on function public.get_event_overview(text) to anon, authenticated;
