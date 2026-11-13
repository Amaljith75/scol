-- Counts tutor-brain questions per phone per day, so one phone (or someone
-- who copied the app's public key) cannot run up the AI bill. Safe to run again.
create table if not exists public.brain_usage (
  device text not null,
  day date not null default current_date,
  count int not null default 0,
  primary key (device, day)
);
alter table public.brain_usage enable row level security;
-- No policies on purpose: only the server can read or write it.

create or replace function public.brain_hit(p_device text)
returns table(device_count int, total_count int)
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into brain_usage(device, day, count) values (p_device, current_date, 1)
  on conflict (device, day) do update set count = brain_usage.count + 1;
  delete from brain_usage where day < current_date - 7;
  return query
    select (select b.count from brain_usage b where b.device = p_device and b.day = current_date),
           (select coalesce(sum(b.count), 0)::int from brain_usage b where b.day = current_date);
end;
$$;
revoke all on function public.brain_hit(text) from public, anon, authenticated;

-- Lessons the brain has already written out in a tutor's own words, one row per
-- lesson, language, tutor and mood. Written once, then served to every phone, so
-- free AI limits are not spent on the same lesson again. Safe to run again.
create table if not exists public.brain_teach (
  key text primary key,
  body jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.brain_teach enable row level security;
-- No policies on purpose: only the server can read or write it.
