-- YES WORD v0.7-0.10. Run only in YES WORD. Existing private snapshots remain unchanged.
begin;
create table if not exists public.app_admins (
 singleton boolean primary key default true check(singleton),
 user_id uuid not null unique references auth.users(id) on delete restrict
);
alter table public.app_admins enable row level security;
revoke all on public.app_admins from anon, authenticated;
-- Bootstrap only the confirmed existing owner; never grant admin based on client metadata.
do $$
declare owner_id uuid;
begin
 select id into strict owner_id from auth.users where lower(email)='chungid1234@gmail.com' and email_confirmed_at is not null;
 insert into public.app_admins(singleton,user_id) values(true,owner_id) on conflict(singleton) do nothing;
 if not exists(select 1 from public.app_admins where user_id=owner_id) then raise exception 'Existing admin differs; review manually'; end if;
end $$;
create or replace function public.yw_is_admin()
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.app_admins where user_id=(select auth.uid()));
$$;
revoke all on function public.yw_is_admin() from public,anon;
grant execute on function public.yw_is_admin() to authenticated;
create or replace function public.yw_admin_users()
returns table(user_id uuid,display_name text,affiliation text,email text,joined_at timestamptz,last_login timestamptz,backup_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.yw_is_admin() then raise exception 'Access denied' using errcode='42501'; end if;
 return query select u.id,p.display_name,p.affiliation,u.email::text,u.created_at,u.last_sign_in_at,s.updated_at
 from auth.users u left join public.profiles p on p.id=u.id left join public.learning_snapshots s on s.user_id=u.id
 order by u.created_at desc;
end $$;
revoke all on function public.yw_admin_users() from public,anon;
grant execute on function public.yw_admin_users() to authenticated;

create table if not exists public.official_curriculum (
 item_key text primary key check(item_key ~ '^yes-([0-9]|1[0-4])$'),
 lesson integer not null check(lesson between 1 and 13),
 reference_ko text not null check(char_length(reference_ko) between 1 and 160),
 reference_en text not null check(char_length(reference_en) between 1 and 160),
 lesson_title text not null default '' check(char_length(lesson_title)<=100)
);
insert into public.official_curriculum(item_key,lesson,reference_ko,reference_en) values
('yes-0',1,'디모데후서 3:16–17','2 Timothy 3:16–17'),('yes-1',2,'여호수아 1:8','Joshua 1:8'),('yes-2',3,'요한복음 16:24','John 16:24'),('yes-3',4,'요한계시록 1:8','Revelation 1:8'),('yes-4',4,'주기도문','The Lord''s Prayer'),('yes-5',5,'마태복음 16:16','Matthew 16:16'),('yes-6',5,'사도신경','Apostles'' Creed'),('yes-7',6,'로마서 5:8','Romans 5:8'),('yes-8',7,'요한복음 7:37–38','John 7:37–38'),('yes-9',8,'에베소서 2:8','Ephesians 2:8'),('yes-10',9,'마태복음 22:37–38','Matthew 22:37–38'),('yes-11',10,'마태복음 22:39','Matthew 22:39'),('yes-12',11,'요한일서 2:17','1 John 2:17'),('yes-13',12,'고린도전서 15:57–58','1 Corinthians 15:57–58'),('yes-14',13,'에베소서 4:3–4','Ephesians 4:3–4')
on conflict(item_key) do nothing;
alter table public.official_curriculum enable row level security;
revoke all on public.official_curriculum from anon,authenticated;
grant select on public.official_curriculum to authenticated;
grant update(lesson_title) on public.official_curriculum to authenticated;
create policy curriculum_read on public.official_curriculum for select to authenticated using(true);
create policy curriculum_admin_edit on public.official_curriculum for update to authenticated using(public.yw_is_admin()) with check(public.yw_is_admin());

create table if not exists public.official_audio (
 id uuid primary key default gen_random_uuid(),
 item_key text not null references public.official_curriculum(item_key),
 language text not null check(language in ('ko-KR','en-US')),
 title text not null check(char_length(title) between 1 and 120),
 object_path text not null unique,
 published boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.official_audio enable row level security;
revoke all on public.official_audio from anon,authenticated;
grant select,insert,update,delete on public.official_audio to authenticated;
create policy official_audio_read on public.official_audio for select to authenticated using(published or public.yw_is_admin());
create policy official_audio_admin on public.official_audio for all to authenticated using(public.yw_is_admin()) with check(public.yw_is_admin());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
('yw-official-audio','yw-official-audio',false,15000000,array['audio/mpeg','audio/mp4','audio/x-m4a','audio/wav','audio/x-wav','audio/webm','audio/ogg','video/webm','video/mp4'])
on conflict(id) do nothing;
create policy yw_official_object_read on storage.objects for select to authenticated using(bucket_id='yw-official-audio' and (public.yw_is_admin() or exists(select 1 from public.official_audio a where a.object_path=name and a.published)));
create policy yw_official_object_insert on storage.objects for insert to authenticated with check(bucket_id='yw-official-audio' and public.yw_is_admin());
create policy yw_official_object_delete on storage.objects for delete to authenticated using(bucket_id='yw-official-audio' and public.yw_is_admin());

create table if not exists public.yw_groups (
 id uuid primary key default gen_random_uuid(),
 name text not null check(char_length(trim(name)) between 1 and 100),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.yw_members (
 group_id uuid references public.yw_groups(id) on delete cascade,
 user_id uuid references auth.users(id) on delete cascade,
 role text not null default 'student' check(role in ('student','leader')),
 primary key(group_id,user_id)
);
create table if not exists public.yw_invites (
 group_id uuid primary key references public.yw_groups(id) on delete cascade,
 code_hash bytea not null unique, expires_at timestamptz not null
);
alter table public.yw_groups enable row level security;
alter table public.yw_members enable row level security;
alter table public.yw_invites enable row level security;
revoke all on public.yw_groups,public.yw_members,public.yw_invites from anon,authenticated;
grant select on public.yw_groups,public.yw_members to authenticated;
grant insert,update on public.yw_groups to authenticated;
grant insert,update,delete on public.yw_members to authenticated;
create or replace function public.yw_is_member(g uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.yw_members m join public.yw_groups x on x.id=m.group_id where m.group_id=g and m.user_id=(select auth.uid()) and x.active);
$$;
create or replace function public.yw_is_leader(g uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.yw_members m join public.yw_groups x on x.id=m.group_id where m.group_id=g and m.user_id=(select auth.uid()) and m.role='leader' and x.active);
$$;
revoke all on function public.yw_is_member(uuid),public.yw_is_leader(uuid) from public,anon;
grant execute on function public.yw_is_member(uuid),public.yw_is_leader(uuid) to authenticated;
create policy yw_groups_read on public.yw_groups for select to authenticated using(public.yw_is_admin() or public.yw_is_member(id));
create policy yw_groups_admin on public.yw_groups for all to authenticated using(public.yw_is_admin()) with check(public.yw_is_admin());
create policy yw_members_read on public.yw_members for select to authenticated using(public.yw_is_admin() or user_id=(select auth.uid()) or public.yw_is_leader(group_id));
create policy yw_members_admin on public.yw_members for all to authenticated using(public.yw_is_admin()) with check(public.yw_is_admin());
create or replace function public.yw_set_invite(g uuid,code text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.yw_is_admin() then raise exception 'Access denied'; end if;
 if code is null or code !~ '^[0-9a-f]{32}$' then raise exception 'Invalid code'; end if;
 insert into public.yw_invites(group_id,code_hash,expires_at) values(g,pg_catalog.sha256(pg_catalog.convert_to(code,'UTF8')),now()+interval '7 days')
 on conflict(group_id) do update set code_hash=excluded.code_hash,expires_at=excluded.expires_at;
end $$;
create or replace function public.yw_join_group(code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 if auth.uid() is null or code is null or code !~ '^[0-9a-f]{32}$' then raise exception 'Invalid invitation'; end if;
 select i.group_id into g from public.yw_invites i join public.yw_groups x on x.id=i.group_id where i.code_hash=pg_catalog.sha256(pg_catalog.convert_to(code,'UTF8')) and i.expires_at>now() and x.active;
 if g is null then raise exception 'Invalid or expired invitation'; end if;
 insert into public.yw_members(group_id,user_id,role) values(g,auth.uid(),'student') on conflict do nothing;
 return g;
end $$;
revoke all on function public.yw_set_invite(uuid,text),public.yw_join_group(text) from public,anon;
grant execute on function public.yw_set_invite(uuid,text),public.yw_join_group(text) to authenticated;

create table if not exists public.yw_group_progress (
 group_id uuid not null, user_id uuid not null,
 completed integer not null check(completed between 0 and 15),
 entered integer not null check(entered between 0 and 15),
 attempts integer not null check(attempts>=0),
 updated_at timestamptz not null default now(),
 primary key(group_id,user_id),
 foreign key(group_id,user_id) references public.yw_members(group_id,user_id) on delete cascade,
 check(completed<=entered)
);
alter table public.yw_group_progress enable row level security;
revoke all on public.yw_group_progress from anon,authenticated;
grant select,insert,update,delete on public.yw_group_progress to authenticated;
create policy yw_progress_read on public.yw_group_progress for select to authenticated using(user_id=(select auth.uid()) or public.yw_is_leader(group_id) or public.yw_is_admin());
create policy yw_progress_own on public.yw_group_progress for all to authenticated using(user_id=(select auth.uid()) and public.yw_is_member(group_id)) with check(user_id=(select auth.uid()) and public.yw_is_member(group_id));
create or replace function public.yw_group_roster(g uuid)
returns table(user_id uuid,display_name text,role text,completed integer,entered integer,attempts integer,reported_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not (public.yw_is_admin() or public.yw_is_leader(g)) then raise exception 'Access denied' using errcode='42501'; end if;
 return query select m.user_id,p.display_name,m.role,s.completed,s.entered,s.attempts,s.updated_at from public.yw_members m left join public.profiles p on p.id=m.user_id left join public.yw_group_progress s on s.group_id=m.group_id and s.user_id=m.user_id where m.group_id=g order by p.display_name;
end $$;
revoke all on function public.yw_group_roster(uuid) from public,anon;
grant execute on function public.yw_group_roster(uuid) to authenticated;

create table if not exists public.yw_submissions (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null, user_id uuid not null,
 reference text not null check(char_length(reference) between 1 and 200),
 object_path text not null unique,
 created_at timestamptz not null default now(),
 foreign key(group_id,user_id) references public.yw_members(group_id,user_id) on delete cascade
);
alter table public.yw_submissions enable row level security;
revoke all on public.yw_submissions from anon,authenticated;
grant select,insert,delete on public.yw_submissions to authenticated;
create policy yw_submission_read on public.yw_submissions for select to authenticated using(user_id=(select auth.uid()) or public.yw_is_leader(group_id));
create policy yw_submission_insert on public.yw_submissions for insert to authenticated with check(user_id=(select auth.uid()) and public.yw_is_member(group_id) and object_path=(user_id::text||'/'||group_id::text||'/'||id::text));
create policy yw_submission_delete on public.yw_submissions for delete to authenticated using(user_id=(select auth.uid()));
create table if not exists public.yw_feedback (
 submission_id uuid primary key references public.yw_submissions(id) on delete cascade,
 reviewer_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 2000),
 updated_at timestamptz not null default now()
);
alter table public.yw_feedback enable row level security;
revoke all on public.yw_feedback from anon,authenticated;
grant select,insert,update on public.yw_feedback to authenticated;
create policy yw_feedback_read on public.yw_feedback for select to authenticated using(exists(select 1 from public.yw_submissions s where s.id=submission_id));
create policy yw_feedback_write on public.yw_feedback for all to authenticated using(exists(select 1 from public.yw_submissions s where s.id=submission_id and public.yw_is_leader(s.group_id))) with check(reviewer_id=(select auth.uid()) and exists(select 1 from public.yw_submissions s where s.id=submission_id and public.yw_is_leader(s.group_id)));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
('yw-submissions','yw-submissions',false,15000000,array['audio/mpeg','audio/mp4','audio/x-m4a','audio/wav','audio/x-wav','audio/webm','audio/ogg','video/webm','video/mp4'])
on conflict(id) do nothing;
create policy yw_submission_object_read on storage.objects for select to authenticated using(bucket_id='yw-submissions' and exists(select 1 from public.yw_submissions s where s.object_path=name));
create policy yw_submission_object_insert on storage.objects for insert to authenticated with check(bucket_id='yw-submissions' and exists(select 1 from public.yw_submissions s where s.object_path=name and s.user_id=(select auth.uid()) and public.yw_is_member(s.group_id)));
create policy yw_submission_object_delete on storage.objects for delete to authenticated using(bucket_id='yw-submissions' and (storage.foldername(name))[1]=(select auth.uid())::text);
commit;
