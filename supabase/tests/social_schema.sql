-- Structural and RLS checks for the social schema and content metadata.
-- Runs in the disposable local database created by scripts/local_db_test.sh.
-- Never execute against production.

\set ON_ERROR_STOP on

do $$
declare
  v_table text;
  v_tables text[] := array[
    'topics',
    'exam_topics',
    'topic_follows',
    'collections',
    'collection_exams',
    'profile_follows',
    'question_comments',
    'comment_votes',
    'content_files'
  ];
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'exams'
      and column_name = 'board'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'exams'
      and column_name = 'institution'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'exams'
      and column_name = 'instance'
  ) then
    raise exception 'metadata identity columns are missing';
  end if;

  if has_function_privilege(
    'anon',
    'public.publish_exam_with_metadata(text,text,text,text,integer,integer,jsonb,text,text,text,text,jsonb)',
    'EXECUTE'
  ) then
    raise exception 'anonymous users can execute metadata publication';
  end if;

  foreach v_table in array v_tables loop
    if to_regclass('public.' || v_table) is null then
      raise exception 'tabela ausente: public.%', v_table;
    end if;
    if not (
      select relrowsecurity
      from pg_class
      where oid = to_regclass('public.' || v_table)
    ) then
      raise exception 'RLS desabilitada em public.%', v_table;
    end if;
  end loop;

  if (select count(*) from public.topics) < 6 then
    raise exception 'seed de topics incompleto';
  end if;
  if not exists (select 1 from public.topics where slug = 'enem') then
    raise exception 'tópico enem ausente do seed';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'content_files_provider_check'
  ) then
    raise exception 'constraint content_files_provider_check ausente';
  end if;
end
$$;

do $$
declare
  v_pair record;
begin
  for v_pair in
    select * from (values
      ('topics', 'topics_public_read'),
      ('exam_topics', 'exam_topics_public_read'),
      ('topic_follows', 'topic_follows_owner_read'),
      ('topic_follows', 'topic_follows_owner_insert'),
      ('topic_follows', 'topic_follows_owner_delete'),
      ('collections', 'collections_read'),
      ('collections', 'collections_owner_insert'),
      ('collections', 'collections_owner_update'),
      ('collections', 'collections_owner_delete'),
      ('collection_exams', 'collection_exams_read'),
      ('profile_follows', 'profile_follows_public_read'),
      ('profile_follows', 'profile_follows_owner_insert'),
      ('question_comments', 'question_comments_public_read'),
      ('question_comments', 'question_comments_owner_insert'),
      ('question_comments', 'question_comments_owner_update'),
      ('question_comments', 'question_comments_owner_delete'),
      ('comment_votes', 'comment_votes_public_read'),
      ('comment_votes', 'comment_votes_owner_insert'),
      ('content_files', 'content_files_read'),
      ('content_files', 'content_files_owner_insert'),
      ('content_files', 'content_files_owner_update'),
      ('content_files', 'content_files_owner_delete')
    ) as expected(tbl, pol)
  loop
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = v_pair.tbl
        and policyname = v_pair.pol
    ) then
      raise exception 'política ausente: public.%.%', v_pair.tbl, v_pair.pol;
    end if;
  end loop;

  if to_regclass('storage.objects') is not null then
    for v_pair in
      select * from (values
        ('exam_content_insert'),
        ('exam_content_read'),
        ('exam_content_delete')
      ) as expected(pol)
    loop
      if not exists (
        select 1 from pg_policies
        where schemaname = 'storage'
          and tablename = 'objects'
          and policyname = v_pair.pol
      ) then
        raise exception 'política de storage ausente: storage.objects.%',
          v_pair.pol;
      end if;
    end loop;
  end if;
end
$$;

insert into auth.users (id, raw_user_meta_data) values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '{"display_name":"Usuário A"}'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '{"display_name":"Usuário B"}')
on conflict (id) do nothing;

-- Author A creates a public exam, follows a topic, creates a private
-- collection, comments and registers a content package.
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  false
);

do $$
declare
  v_exam_id uuid;
  v_metadata_exam_id uuid;
  v_question_id uuid;
  v_collection_id uuid;
  v_comment_id uuid;
begin
  v_exam_id := public.publish_exam(
    'Prova social', 'Teste', 'Fonte', 'community', 2026, 30,
    '[{"statement":"Questão social?","topic":"Geral","options":["A","B"],"correct_index":0}]'
  );
  perform set_config('test.social_exam', v_exam_id::text, false);

  v_metadata_exam_id := public.publish_exam_with_metadata(
    'Prova com metadados', 'Concurso público', 'Fonte', 'community',
    2024, 30,
    '[{"statement":"Questão de metadados?","topic":"Geral","options":["A","B"],"correct_index":0}]',
    null, 'VUNESP', 'Polícia Militar do Estado de São Paulo',
    'Prova objetiva — Parte I', '[]'::jsonb
  );
  if not exists (
    select 1 from public.exams
    where id = v_metadata_exam_id
      and board = 'VUNESP'
      and institution = 'Polícia Militar do Estado de São Paulo'
      and instance = 'Prova objetiva — Parte I'
  ) then
    raise exception 'RPC não persistiu metadados de identidade distintos';
  end if;

  begin
    perform public.publish_exam_with_metadata(
      'Prova com metadados inválidos', 'Concurso público', 'Fonte', 'community',
      2024, 30,
      '[{"statement":"Questão?","topic":"Geral","options":["A","B"],"correct_index":0}]',
      null, repeat('x', 121), null, null, '[]'::jsonb
    );
    raise exception 'RPC aceitou banca acima do limite';
  exception when sqlstate '22023' then
    null;
  end;

  select id into v_question_id
  from public.questions
  where exam_id = v_exam_id and position = 1;
  perform set_config('test.social_question', v_question_id::text, false);

  insert into public.topic_follows (user_id, topic_id)
  select auth.uid(), id from public.topics where slug = 'enem';
  if not exists (
    select 1 from public.topic_follows
    where user_id = auth.uid()
      and topic_id = (select id from public.topics where slug = 'enem')
  ) then
    raise exception 'autor não conseguiu seguir o próprio tópico';
  end if;

  insert into public.collections (owner_id, title, is_public)
  values (auth.uid(), 'Coleção privada A', false)
  returning id into v_collection_id;
  perform set_config('test.social_collection', v_collection_id::text, false);

  insert into public.question_comments (question_id, author_id, body)
  values (v_question_id, auth.uid(), 'Comentário visível')
  returning id into v_comment_id;
  perform set_config('test.social_comment', v_comment_id::text, false);

  insert into public.content_files (
    owner_id, exam_id, object_key, original_name, mime_type, sha256,
    uncompressed_bytes, compressed_bytes
  ) values (
    auth.uid(), v_exam_id,
    auth.uid()::text || '/exams/' || v_exam_id::text || '/pacote.json.gz',
    'pacote.json.gz', 'application/gzip', repeat('a', 64), 100, 50
  );
end
$$;

-- Author B cannot act on A's rows.
reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  false
);

do $$
declare
  v_rejected boolean;
begin
  v_rejected := false;
  begin
    insert into public.topic_follows (user_id, topic_id)
    select 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', id
    from public.topics where slug = 'enem';
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'RLS aceitou seguir tópico em nome de outro usuário';
  end if;

  if exists (
    select 1 from public.collections
    where id = current_setting('test.social_collection')::uuid
  ) then
    raise exception 'RLS expôs coleção privada de outro usuário';
  end if;

  v_rejected := false;
  begin
    update public.collections
    set title = 'sequestrada'
    where id = current_setting('test.social_collection')::uuid;
    if found then
      raise exception 'RLS aceitou alterar coleção de outro usuário';
    end if;
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if v_rejected then
    raise exception 'RLS barrou a atualização com erro em vez de filtrar a linha';
  end if;
end
$$;

-- Anonymous reads only the public surface.
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);

do $$
declare
  v_rejected boolean;
begin
  if not exists (select 1 from public.topics where slug = 'enem') then
    raise exception 'visitante não lê tópicos públicos';
  end if;
  if exists (
    select 1 from public.collections
    where id = current_setting('test.social_collection')::uuid
  ) then
    raise exception 'visitante leu coleção privada';
  end if;
  if not exists (
    select 1 from public.question_comments
    where id = current_setting('test.social_comment')::uuid
  ) then
    raise exception 'visitante não lê comentário visível em prova pública';
  end if;
  if exists (
    select 1 from public.content_files
    where exam_id = current_setting('test.social_exam')::uuid
  ) then
    raise exception 'visitante leu pacote ainda pendente';
  end if;

  v_rejected := false;
  begin
    insert into public.collections (owner_id, title)
    values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'Sem conta');
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'visitante conseguiu inserir coleção';
  end if;
end
$$;

-- A package only becomes publicly readable after the owner marks it ready.
reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  false
);
update public.content_files
set status = 'ready'
where exam_id = current_setting('test.social_exam')::uuid;

reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  if not exists (
    select 1 from public.content_files
    where exam_id = current_setting('test.social_exam')::uuid
      and status = 'ready'
  ) then
    raise exception 'visitante não lê pacote pronto de prova pública';
  end if;
end
$$;

-- The author cannot hide a comment without the moderation policy (added by
-- the moderation migration); hiding is not an author-level operation.
reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  false
);
do $$
declare
  v_rejected boolean := false;
begin
  begin
    update public.question_comments
    set status = 'hidden'
    where id = current_setting('test.social_comment')::uuid;
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'autor ocultou comentário sem moderação';
  end if;
end
$$;

reset role;
