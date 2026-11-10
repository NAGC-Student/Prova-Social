alter table public.exams
  add column if not exists board text
    check (board is null or char_length(btrim(board)) between 1 and 120),
  add column if not exists institution text
    check (institution is null or char_length(btrim(institution)) between 1 and 180),
  add column if not exists instance text
    check (instance is null or char_length(btrim(instance)) between 1 and 120);

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

  v_exam_id := public.publish_exam_with_media(
    p_title,
    p_category,
    p_source,
    p_source_type,
    p_year,
    p_duration_minutes,
    p_questions,
    p_source_url,
    p_media
  );

  update public.exams
  set board = v_board,
      institution = v_institution,
      instance = v_instance
  where id = v_exam_id
    and author_id = auth.uid()
    and is_public;

  if not found then
    raise exception 'published exam unavailable' using errcode = '22023';
  end if;

  return v_exam_id;
end;
$$;

alter function public.publish_exam_with_metadata(
  text, text, text, text, integer, integer, jsonb, text, text, text, text, jsonb
) owner to postgres;
revoke all on function public.publish_exam_with_metadata(
  text, text, text, text, integer, integer, jsonb, text, text, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.publish_exam_with_metadata(
  text, text, text, text, integer, integer, jsonb, text, text, text, text, jsonb
) to authenticated;

notify pgrst, 'reload schema';