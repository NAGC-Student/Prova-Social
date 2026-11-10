-- Minimal moderation for question comments: moderator role, reports and
-- auditable hiding. Depends on 202611070001_social_graph.sql.
--
-- The moderation role is granted out of band (service role/SQL); no policy
-- lets a user grant it to themselves.

create table if not exists public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('moderator')),
  granted_by uuid references public.profiles(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

alter table public.user_roles enable row level security;

drop policy if exists user_roles_self_read on public.user_roles;
create policy user_roles_self_read on public.user_roles
  for select to authenticated using (user_id = (select auth.uid()));

-- A definer helper avoids recursive RLS: policies on other tables can ask
-- whether the current user moderates without granting read on user_roles.
create or replace function public.is_moderator(p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user
      and ur.role = 'moderator'
  )
$$;

revoke all on function public.is_moderator(uuid) from public, anon;
grant execute on function public.is_moderator(uuid) to authenticated;

drop policy if exists user_roles_moderator_read on public.user_roles;
create policy user_roles_moderator_read on public.user_roles
  for select to authenticated using (public.is_moderator());

-- Comment author and parent are nullable so deleting a profile or a parent
-- comment preserves the discussion instead of cascading it away.
alter table public.question_comments
  alter column author_id drop not null,
  add column if not exists moderated_by uuid
    references public.profiles(id) on delete set null,
  add column if not exists moderated_at timestamptz;

alter table public.question_comments
  drop constraint if exists question_comments_author_id_fkey;
alter table public.question_comments
  add constraint question_comments_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete set null;

alter table public.question_comments
  drop constraint if exists question_comments_parent_id_fkey;
alter table public.question_comments
  add constraint question_comments_parent_id_fkey
  foreign key (parent_id) references public.question_comments(id) on delete set null;

create table if not exists public.question_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid references public.question_comments(id) on delete set null,
  reporter_id uuid references public.profiles(id) on delete set null,
  reason text not null
    check (reason in ('spam', 'abuse', 'off_topic', 'misinformation', 'other')),
  details text check (details is null or char_length(details) <= 2000),
  status text not null default 'open'
    check (status in ('open', 'reviewed', 'dismissed', 'actioned')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);

create index if not exists question_reports_comment_created_idx
  on public.question_reports(comment_id, created_at desc);
create index if not exists question_reports_status_created_idx
  on public.question_reports(status, created_at);
create unique index if not exists question_reports_one_open_per_user
  on public.question_reports(comment_id, reporter_id)
  where status = 'open';

alter table public.question_reports enable row level security;

drop policy if exists question_comments_public_read on public.question_comments;
create policy question_comments_public_read on public.question_comments
  for select to anon, authenticated using (
    status = 'visible' and exists (
      select 1 from public.questions q
      join public.exams e on e.id = q.exam_id
      where q.id = question_id and e.status = 'published' and e.is_public
    )
  );

drop policy if exists question_comments_author_read on public.question_comments;
create policy question_comments_author_read on public.question_comments
  for select to authenticated using (author_id = (select auth.uid()));

drop policy if exists question_comments_moderator_read on public.question_comments;
create policy question_comments_moderator_read on public.question_comments
  for select to authenticated using (public.is_moderator());

drop policy if exists question_comments_owner_insert on public.question_comments;
create policy question_comments_owner_insert on public.question_comments
  for insert to authenticated with check (
    author_id = (select auth.uid())
    and status = 'visible'
    and moderated_by is null
    and moderated_at is null
  );

drop policy if exists question_comments_owner_update on public.question_comments;
create policy question_comments_owner_update on public.question_comments
  for update to authenticated using (
    author_id = (select auth.uid())
  ) with check (
    author_id = (select auth.uid())
    and status in ('visible', 'deleted')
    and moderated_by is null
    and moderated_at is null
  );

drop policy if exists question_comments_moderator_update on public.question_comments;
create policy question_comments_moderator_update on public.question_comments
  for update to authenticated using (
    public.is_moderator()
  ) with check (
    public.is_moderator()
    and status in ('hidden', 'deleted')
    and moderated_by = (select auth.uid())
    and moderated_at is not null
  );

drop policy if exists question_reports_reporter_insert on public.question_reports;
create policy question_reports_reporter_insert on public.question_reports
  for insert to authenticated with check (
    reporter_id = (select auth.uid())
    and status = 'open'
    and reviewed_at is null
    and reviewed_by is null
    and comment_id is not null
    and exists (
      select 1
      from public.question_comments c
      join public.questions q on q.id = c.question_id
      join public.exams e on e.id = q.exam_id
      where c.id = comment_id
        and c.status = 'visible'
        and e.status = 'published'
        and e.is_public
    )
  );

drop policy if exists question_reports_reporter_read on public.question_reports;
create policy question_reports_reporter_read on public.question_reports
  for select to authenticated using (reporter_id = (select auth.uid()));

drop policy if exists question_reports_moderator_read on public.question_reports;
create policy question_reports_moderator_read on public.question_reports
  for select to authenticated using (public.is_moderator());

drop policy if exists question_reports_moderator_update on public.question_reports;
create policy question_reports_moderator_update on public.question_reports
  for update to authenticated using (
    public.is_moderator()
  ) with check (
    public.is_moderator()
    and status in ('reviewed', 'dismissed', 'actioned')
    and reviewed_by = (select auth.uid())
    and reviewed_at is not null
  );

revoke insert, update, delete on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;

revoke all on public.question_reports from anon;
grant select, insert, update on public.question_reports to authenticated;
