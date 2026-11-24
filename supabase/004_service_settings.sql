-- YES WORD: official audio availability, administrator-controlled.
begin;
create table if not exists public.yw_service_settings (
 singleton boolean primary key default true check(singleton),
 official_audio_enabled boolean not null default false
);
insert into public.yw_service_settings(singleton) values(true) on conflict do nothing;
alter table public.yw_service_settings enable row level security;
revoke all on public.yw_service_settings from anon,authenticated;
grant select on public.yw_service_settings to authenticated;
grant update(official_audio_enabled) on public.yw_service_settings to authenticated;
drop policy if exists yw_settings_read on public.yw_service_settings;
create policy yw_settings_read on public.yw_service_settings for select to authenticated using(true);
drop policy if exists yw_settings_admin on public.yw_service_settings;
create policy yw_settings_admin on public.yw_service_settings for update to authenticated using(public.yw_is_admin()) with check(public.yw_is_admin());
create or replace function public.yw_official_enabled()
returns boolean language sql stable security invoker set search_path='' as $$
 select coalesce((select official_audio_enabled from public.yw_service_settings where singleton),false);
$$;
revoke all on function public.yw_official_enabled() from public,anon;
grant execute on function public.yw_official_enabled() to authenticated;
drop policy if exists official_audio_read on public.official_audio;
create policy official_audio_read on public.official_audio for select to authenticated
using(public.yw_is_admin() or (published and public.yw_official_enabled()));
drop policy if exists yw_official_object_read on storage.objects;
create policy yw_official_object_read on storage.objects for select to authenticated
using(bucket_id='yw-official-audio' and (public.yw_is_admin() or (public.yw_official_enabled() and exists(select 1 from public.official_audio a where a.object_path=name and a.published))));
commit;
