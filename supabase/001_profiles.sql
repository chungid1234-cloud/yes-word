-- YES WORD: phase 1 authentication profiles. Run only in the yes-word project.
begin;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 40),
  affiliation text not null check (affiliation in ('YES 청년부 · 새일꾼반','YES 청년부','개인 / 기타')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, insert on public.profiles to authenticated;
grant update (display_name, affiliation) on public.profiles to authenticated;
drop policy if exists profile_read_self on public.profiles;
create policy profile_read_self on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists profile_insert_self on public.profiles;
create policy profile_insert_self on public.profiles for insert to authenticated with check (id = (select auth.uid()));
drop policy if exists profile_update_self on public.profiles;
create policy profile_update_self on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
commit;
