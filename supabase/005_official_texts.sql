-- YES WORD: administrator-managed scripture text. Run after 003 and 004.
begin;
create table if not exists public.official_texts (
 item_key text not null references public.official_curriculum(item_key),
 language text not null check(language in ('ko-KR','en-US')),
 translation text not null check(char_length(translation) between 1 and 100),
 body text not null check(char_length(body) between 1 and 12000),
 published boolean not null default false,
 updated_at timestamptz not null default now(),
 primary key(item_key,language)
);
alter table public.official_texts enable row level security;
revoke all on public.official_texts from anon,authenticated;
grant select,insert,update,delete on public.official_texts to authenticated;
drop policy if exists official_texts_read on public.official_texts;
create policy official_texts_read on public.official_texts for select to authenticated using(published or public.yw_is_admin());
drop policy if exists official_texts_admin on public.official_texts;
create policy official_texts_admin on public.official_texts for all to authenticated using(public.yw_is_admin()) with check(public.yw_is_admin());
commit;
