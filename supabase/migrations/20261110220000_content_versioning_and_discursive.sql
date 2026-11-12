-- Prova Social: Content Versioning, Discursive Questions & Extended Question Model
-- Run after 20261109195305_exam_metadata_fields.sql

create extension if not exists pgcrypto;

-- 1. Extended questions table with new fields for discursive questions and versioning
alter table public.questions
  add column if not exists question_type text not null default 'objective'
    check (question_type in ('objective', 'discursive')),
  add column if not exists explanation text
    check (explanation is null or char_length(explanation) <= 10000),
  add column if not exists expected_answer text
    check (expected_answer is null or char_length(expected_answer) <= 5000),
  add column if not exists rubric text
    check (rubric is null or char_length(rubric) <= 5000),
  add column if not exists canonical_url text
    check (canonical_url is null or char_length(canonical_url) <= 500),
  add column if not exists source text
    check (source is null or char_length(source) <= 160),
  add column if not exists version integer not null default 1
    check (version > 0),
  add column if not exists content_hash text
    check (content_hash is null or content_hash ~ '^[a-f0-9]{64}$');

-- For discursive questions, correct_index is optional; make constraint conditional
-- The private.question_keys table will only store keys for objective questions
-- (discursive questions don't have a correct_index)

-- 2. Exam versions table for content versioning
create table if not exists public.exam_versions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams(id) on delete cascade,
  content_hash text not null check (content_hash ~ '^[a-f0-9]{64}$'),
  description text,
  created_at timestamptz not null default now(),
  unique (exam_id, content_hash)
);

create index if not exists exam_versions_exam_id_idx on public.exam_versions(exam_id);

-- 3. Add current_version_id to exams
alter table public.exams
  add column if not exists current_version_id uuid
    references public.exam_versions(id) on delete set null;

create index if not exists exams_current_version_id_idx on public.exams(current_version_id);

-- 4. Add exam_version_id to attempts for version tracking
alter table public.attempts
  add column if not exists exam_version_id uuid
    references public.exam_versions(id) on delete set null;

create index if not exists attempts_exam_version_id_idx on public.attempts(exam_version_id);

-- 5. RLS for exam_versions
alter table public.exam_versions enable row level security;

drop policy if exists exam_versions_public_read on public.exam_versions;
create policy exam_versions_public_read on public.exam_versions
  for select to anon, authenticated using (
    exists (
      select 1 from public.exams e
      where e.id = exam_id
        and ((e.status = 'published' and e.is_public)
          or e.author_id = (select auth.uid()))
    )
  );

drop policy if exists exam_versions_owner_insert on public.exam_versions;
create policy exam_versions_owner_insert on public.exam_versions
  for insert to authenticated with check (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  );

drop policy if exists exam_versions_owner_update on public.exam_versions;
create policy exam_versions_owner_update on public.exam_versions
  for update to authenticated using (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  ) with check (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  );

grant select on public.exam_versions to anon, authenticated;
grant insert, update on public.exam_versions to authenticated;

-- 6. Update publish_exam to support discursive questions (no correct_index required)
-- and create exam version on publish
create or replace function public.publish_exam(
  p_title text,
  p_category text,
  p_source text,
  p_source_type text,
  p_year integer,
  p_duration_minutes integer,
  p_questions jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user uuid := auth.uid();
  v_exam_id uuid;
  v_item jsonb;
  v_question_id uuid;
  v_position integer := 0;
  v_question_type text;
  v_correct integer;
  v_content_hash text;
  v_version_id uuid;
begin
  if v_user is null then
    raise exception 'authentication required';
  end if;
  if jsonb_typeof(p_questions) <> 'array'
     or jsonb_array_length(p_questions) = 0
     or jsonb_array_length(p_questions) > 300 then
    raise exception 'invalid question list';
  end if;

  insert into public.exams (
    author_id, title, description, category, source_name, source_type,
    year, duration_minutes, status, is_public, question_count
  ) values (
    v_user, trim(p_title), 'Prova revisada e publicada pela comunidade.',
    trim(p_category), trim(p_source), p_source_type, p_year,
    p_duration_minutes, 'draft', false, jsonb_array_length(p_questions)
  ) returning id into v_exam_id;

  for v_item in select value from jsonb_array_elements(p_questions)
  loop
    v_position := v_position + 1;
    v_question_type := coalesce(nullif(trim(v_item ->> 'question_type'), ''), 'objective');

    -- For objective questions, correct_index is required
    -- For discursive questions, correct_index is optional (no automatic correction)
    if v_question_type = 'objective' then
      v_correct := (v_item ->> 'correct_index')::integer;
      if v_correct is null then
        raise exception 'objective question at position % requires correct_index', v_position;
      end if;
      if jsonb_typeof(v_item -> 'options') <> 'array'
         or jsonb_array_length(v_item -> 'options') < 2
         or v_correct < 0
         or v_correct >= jsonb_array_length(v_item -> 'options') then
        raise exception 'invalid objective question at position %', v_position;
      end if;
    else
      -- Discursive question: correct_index is ignored, options can be empty or minimal
      v_correct := null;
      if jsonb_typeof(v_item -> 'options') <> 'array' then
        raise exception 'discursive question at position % must have options array', v_position;
      end if;
    end if;

    insert into public.questions (
      exam_id, position, topic, statement, options,
      question_type, explanation, expected_answer, rubric,
      canonical_url, source, version
    ) values (
      v_exam_id,
      v_position,
      coalesce(nullif(trim(v_item ->> 'topic'), ''), 'Geral'),
      trim(v_item ->> 'statement'),
      v_item -> 'options',
      v_question_type,
      nullif(trim(v_item ->> 'explanation'), ''),
      nullif(trim(v_item ->> 'expected_answer'), ''),
      nullif(trim(v_item ->> 'rubric'), ''),
      nullif(trim(v_item ->> 'canonical_url'), ''),
      nullif(trim(v_item ->> 'source'), ''),
      1
    ) returning id into v_question_id;

    -- Only store correct_index for objective questions
    if v_question_type = 'objective' and v_correct is not null then
      insert into private.question_keys (question_id, correct_index)
        values (v_question_id, v_correct);
    end if;
  end loop;

  -- Compute content hash of all questions for versioning
  select encode(
    digest(
      string_agg(q.content_hash, '' order by q.position), 'sha256'
    ), 'hex'
  ) into v_content_hash
  from (
    select position,
      encode(
        digest(
          statement || coalesce(options::text, '') || coalesce(correct_index::text, '') || question_type, 'sha256'
        ), 'hex'
      ) as content_hash
    from public.questions
    where exam_id = v_exam_id
  ) q;

  -- Create exam version
  insert into public.exam_versions (exam_id, content_hash, description)
    values (v_exam_id, v_content_hash, 'Versão inicial publicada')
    returning id into v_version_id;

  -- Update exam with version and publish
  update public.exams
  set status = 'published', is_public = true, updated_at = now(),
      current_version_id = v_version_id
  where id = v_exam_id;

  return v_exam_id;
end;
$$;

-- 7. Update publish_exam_with_metadata to work with new publish_exam signature
create or replace function public.publish_exam_with_metadata(
  p_title text,
  p_category text,
  p_source text,
  p_source_type text,
  p_year integer,
  p_duration_minutes integer,
  p_questions jsonb,
  p_source_url text,
  p_board text,
  p_institution text,
  p_instance text,
  p_media jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, auth
as $$
declare
  v_exam_id uuid;
  v_board text := nullif(btrim(p_board), '');
  v_institution text := nullif(btrim(p_institution), '');
  v_instance text := nullif(btrim(p_instance), '');
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if char_length(v_board) > 120
     or char_length(v_institution) > 180
     or char_length(v_instance) > 120 then
    raise exception 'invalid exam identity metadata' using errcode = '22023';
  end if;

  v_exam_id := public.publish_exam(
    p_title, p_category, p_source, p_source_type,
    p_year, p_duration_minutes, p_questions
  );

  update public.exams
  set board = v_board,
      institution = v_institution,
      instance = v_instance,
      source_url = nullif(btrim(p_source_url), '')
  where id = v_exam_id
    and author_id = auth.uid()
    and is_public;

  if not found then
    raise exception 'published exam unavailable' using errcode = '22023';
  end if;

  return v_exam_id;
end;
$$;

-- 8. Update submit_exam_attempt to handle discursive questions
-- Discursive questions are not auto-scored; they're excluded from correct_count/total_count
create or replace function public.submit_exam_attempt(
  p_exam_id uuid,
  p_answers jsonb,
  p_review_question_ids uuid[] default '{}',
  p_duration_seconds integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user uuid := auth.uid();
  v_attempt_id uuid;
  v_total integer;
  v_correct integer;
  v_review jsonb;
  v_exam_version_id uuid;
begin
  if not exists (
    select 1 from public.exams
    where id = p_exam_id and status = 'published' and is_public
  ) then
    raise exception 'exam unavailable';
  end if;
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object' then
    raise exception 'invalid answers';
  end if;

  -- Get current exam version
  select current_version_id into v_exam_version_id
  from public.exams where id = p_exam_id;

  -- Only score objective questions with correct_index
  select count(*), count(*) filter (
    where q.question_type = 'objective'
      and (p_answers ->> q.id::text) is not null
      and (p_answers ->> q.id::text)::integer = k.correct_index
  )
  into v_total, v_correct
  from public.questions q
  left join private.question_keys k on k.question_id = q.id
  where q.exam_id = p_exam_id;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', q.id,
      'position', q.position,
      'selected_index', case when (p_answers ->> q.id::text) is null
        then null else (p_answers ->> q.id::text)::integer end,
      'correct_index', k.correct_index,
      'is_correct',
        case
          when q.question_type = 'discursive' then null
          when (p_answers ->> q.id::text) is null then false
          else (p_answers ->> q.id::text)::integer = k.correct_index
        end,
      'question_type', q.question_type
    ) order by q.position
  ) into v_review
  from public.questions q
  left join private.question_keys k on k.question_id = q.id
  where q.exam_id = p_exam_id;

  if v_user is not null then
    insert into public.attempts (
      user_id, exam_id, exam_version_id, duration_seconds, correct_count, total_count,
      score_percent, completed_at
    ) values (
      v_user, p_exam_id, v_exam_version_id, greatest(p_duration_seconds, 0),
      v_correct, v_total,
      round(v_correct::numeric * 100 / greatest(v_total, 1))::integer, now()
    ) returning id into v_attempt_id;

    insert into public.attempt_answers (
      attempt_id, question_id, selected_index, is_correct, marked_for_review
    )
    select
      v_attempt_id,
      q.id,
      case when (p_answers ->> q.id::text) is null
        then null else (p_answers ->> q.id::text)::integer end,
      case
        when q.question_type = 'discursive' then null
        when (p_answers ->> q.id::text) is null then false
        else (p_answers ->> q.id::text)::integer = k.correct_index
      end,
      q.id = any(coalesce(p_review_question_ids, '{}'::uuid[]))
    from public.questions q
    left join private.question_keys k on k.question_id = q.id
    where q.exam_id = p_exam_id;

    update public.exams set attempts_count = attempts_count + 1
      where id = p_exam_id;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'total', v_total,
    'correct', v_correct,
    'score_percent', round(v_correct::numeric * 100 / greatest(v_total, 1)),
    'review', coalesce(v_review, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  from public, anon;
grant execute on function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  to authenticated;

revoke all on function public.publish_exam_with_metadata(
  text, text, text, text, integer, integer, jsonb, text, text, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.publish_exam_with_metadata(
  text, text, text, text, integer, integer, jsonb, text, text, text, text, jsonb
) to authenticated;

revoke all on function public.submit_exam_attempt(uuid, jsonb, uuid[], integer)
  from public;
grant execute on function public.submit_exam_attempt(uuid, jsonb, uuid[], integer)
  to anon, authenticated;

notify pgrst, 'reload schema';