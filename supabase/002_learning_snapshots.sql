-- YES WORD v0.6: run in the yes-word project only.
begin;
create table if not exists public.learning_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object' and payload->>'schema' = '1'
    and octet_length(payload::text) <= 2000000
  ),
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now()
);
alter table public.learning_snapshots enable row level security;
revoke all on public.learning_snapshots from anon, authenticated;
grant select, insert on public.learning_snapshots to authenticated;
grant update (payload, revision, updated_at) on public.learning_snapshots to authenticated;
drop policy if exists learning_read_self on public.learning_snapshots;
create policy learning_read_self on public.learning_snapshots for select to authenticated
using (user_id = (select auth.uid()));
drop policy if exists learning_insert_self on public.learning_snapshots;
create policy learning_insert_self on public.learning_snapshots for insert to authenticated
with check (user_id = (select auth.uid()) and revision = 1);
drop policy if exists learning_update_self on public.learning_snapshots;
create policy learning_update_self on public.learning_snapshots for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- Enforce sequential revisions, including when a stale client attempts a write.
create or replace function public.yes_word_snapshot_revision()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.revision <> old.revision + 1 then
    raise exception 'Snapshot revision conflict' using errcode = '40001';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists learning_snapshot_revision on public.learning_snapshots;
create trigger learning_snapshot_revision before update on public.learning_snapshots
for each row execute function public.yes_word_snapshot_revision();
commit;
