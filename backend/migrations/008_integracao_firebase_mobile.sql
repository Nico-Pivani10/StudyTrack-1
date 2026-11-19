-- Execute depois de 007. Esta migração conserva as tabelas e os IDs da API.
begin;

alter table public.usuarios
  add column if not exists firebase_uid text unique,
  add column if not exists perfil_mobile jsonb not null default '{}'::jsonb,
  add column if not exists mobile_importacao jsonb not null default '{}'::jsonb,
  add column if not exists mobile_importado_em timestamptz;
alter table public.usuarios alter column senha_hash drop not null;
alter table public.usuarios drop constraint if exists usuarios_plano_chk;
alter table public.usuarios add constraint usuarios_plano_chk check (plano in ('free', 'pro', 'premium'));

alter table public.materias
  add column if not exists mobile_id text,
  add column if not exists mobile_dados jsonb not null default '{}'::jsonb;
alter table public.tarefas
  add column if not exists usuario_id integer references public.usuarios(id) on delete cascade,
  add column if not exists mobile_id text,
  add column if not exists mobile_dados jsonb not null default '{}'::jsonb;
alter table public.exames
  add column if not exists usuario_id integer references public.usuarios(id) on delete cascade,
  add column if not exists mobile_id text,
  add column if not exists mobile_dados jsonb not null default '{}'::jsonb;
alter table public.tarefas alter column materia_id drop not null;
alter table public.exames alter column materia_id drop not null;
update public.tarefas t set usuario_id = m.usuario_id from public.materias m
  where t.materia_id = m.id and t.usuario_id is null;
update public.exames e set usuario_id = m.usuario_id from public.materias m
  where e.materia_id = m.id and e.usuario_id is null;
alter table public.tarefas alter column usuario_id set not null;
alter table public.exames alter column usuario_id set not null;

create unique index if not exists materias_mobile_uid on public.materias(usuario_id, mobile_id);
create unique index if not exists tarefas_mobile_uid on public.tarefas(usuario_id, mobile_id);
create unique index if not exists exames_mobile_uid on public.exames(usuario_id, mobile_id);

-- O trigger também atende às rotas antigas, que só enviam materia_id.
create or replace function public.definir_dono_atividade()
returns trigger language plpgsql set search_path = '' as $$
declare v_dono integer;
begin
  if new.materia_id is not null then
    select usuario_id into v_dono from public.materias where id = new.materia_id;
    if v_dono is null then raise exception 'matéria não encontrada' using errcode = '23503'; end if;
    if new.usuario_id is not null and new.usuario_id <> v_dono then
      raise exception 'matéria não pertence à conta' using errcode = '23503';
    end if;
    new.usuario_id := v_dono;
  end if;
  if new.usuario_id is null then raise exception 'usuário obrigatório' using errcode = '23502'; end if;
  return new;
end;
$$;
create or replace trigger tarefas_dono before insert or update on public.tarefas
  for each row execute function public.definir_dono_atividade();
create or replace trigger exames_dono before insert or update on public.exames
  for each row execute function public.definir_dono_atividade();

create table if not exists public.mobile_registros (
  usuario_id integer not null references public.usuarios(id) on delete cascade,
  tipo text not null check (tipo in ('sesionesEstudio', 'notificaciones')),
  id text not null,
  dados jsonb not null,
  primary key (usuario_id, tipo, id)
);
-- A marca persiste mesmo se o registro for excluído durante uma importação parcial.
create table if not exists public.mobile_importados (
  usuario_id integer not null references public.usuarios(id) on delete cascade,
  tipo text not null,
  id text not null,
  primary key (usuario_id, tipo, id)
);
alter table public.mobile_registros enable row level security;
alter table public.mobile_importados enable row level security;
revoke all on public.mobile_registros, public.mobile_importados from public, anon, authenticated;

create or replace function public.mobile_avancar_importacao(p_usuario_id integer, p_tipo text, p_id text)
returns void language plpgsql set search_path = '' as $$
begin
  insert into public.mobile_importados values(p_usuario_id, p_tipo, p_id) on conflict do nothing;
  update public.usuarios set mobile_importacao = mobile_importacao || jsonb_build_object(p_tipo,
    coalesce(mobile_importacao->p_tipo, '{}'::jsonb) || jsonb_build_object('ultimo',
      greatest((mobile_importacao#>>array[p_tipo, 'ultimo']) collate "C", p_id collate "C")))
    where id = p_usuario_id;
end;
$$;

create or replace function public.mobile_finalizar_tipo(p_usuario_id integer, p_tipo text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if p_tipo not in ('materias', 'tareas', 'examenes', 'sesionesEstudio', 'notificaciones') then
    raise exception 'tipo inválido';
  end if;
  update public.usuarios set mobile_importacao = mobile_importacao || jsonb_build_object(p_tipo,
    coalesce(mobile_importacao->p_tipo, '{}'::jsonb) || '{"concluido":true}'::jsonb)
    where id = p_usuario_id;
  return found;
end;
$$;

create or replace function public.vincular_usuario_firebase(p_uid text, p_email text, p_nome text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_usuario public.usuarios%rowtype;
begin
  if coalesce(p_uid, '') = '' or length(p_uid) > 128 or coalesce(p_email, '') = '' then
    return jsonb_build_object('status', 400, 'erro', 'identidade inválida');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('firebase:' || p_uid, 0));
  select * into v_usuario from public.usuarios where firebase_uid = p_uid;
  if not found then
    if exists(select 1 from public.usuarios where lower(email) = lower(p_email)) then
      return jsonb_build_object('status', 409, 'codigo', 'conta_nao_vinculada',
        'erro', 'já existe uma conta da API com esse e-mail; o vínculo exige confirmar as duas contas');
    end if;
    insert into public.usuarios (nome, email, senha_hash, firebase_uid)
      values (p_nome, lower(p_email), null, p_uid) returning * into v_usuario;
  elsif lower(v_usuario.email) <> lower(p_email) then
    update public.usuarios set email = lower(p_email), atualizado_em = clock_timestamp() at time zone 'UTC'
      where id = v_usuario.id returning * into v_usuario;
  end if;
  return jsonb_build_object('status', 200, 'usuario', to_jsonb(v_usuario));
exception when unique_violation then
  return jsonb_build_object('status', 409, 'codigo', 'conta_nao_vinculada', 'erro', 'confirme o vínculo com a conta existente');
end;
$$;

create or replace function public.mobile_estado(p_usuario_id integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_usuario public.usuarios%rowtype;
  v_fuso text;
  v_estado jsonb;
begin
  select * into strict v_usuario from public.usuarios where id = p_usuario_id;
  select fuso_horario into v_fuso from public.preferencias_notificacao where usuario_id = p_usuario_id;
  v_fuso := coalesce(v_fuso, 'America/Sao_Paulo');
  v_estado := jsonb_build_object(
    'perfil', v_usuario.perfil_mobile || jsonb_build_object(
      'nombre', v_usuario.nome, 'email', v_usuario.email,
      'plan', case when v_usuario.plano = 'free' then 'gratis' else v_usuario.plano end),
    'materias', coalesce((select jsonb_agg(jsonb_build_object(
      'id', coalesce(m.mobile_id, 'api:' || m.id),
      'dados', m.mobile_dados || jsonb_build_object('nombre', m.nome, 'docente', coalesce(m.professor, ''),
        'cor', m.cor, 'actualizadoEn', m.atualizado_em at time zone 'UTC')) order by m.id)
      from public.materias m where m.usuario_id = p_usuario_id), '[]'::jsonb),
    'tareas', coalesce((select jsonb_agg(jsonb_build_object(
      'id', coalesce(t.mobile_id, 'api:' || t.id),
      'dados', t.mobile_dados || jsonb_build_object(
        'titulo', t.titulo, 'descripcion', coalesce(t.descricao, ''),
        'materiaId', coalesce(m.mobile_id, 'api:' || m.id, t.mobile_dados->>'materiaId', ''),
        'fechaEntrega', t.data_entrega at time zone v_fuso,
        'completada', t.status::text in ('concluida', 'concluido'),
        'actualizadoEn', t.atualizado_em at time zone 'UTC')) order by t.id)
      from public.tarefas t left join public.materias m on m.id = t.materia_id
      where t.usuario_id = p_usuario_id), '[]'::jsonb),
    'examenes', coalesce((select jsonb_agg(jsonb_build_object(
      'id', coalesce(e.mobile_id, 'api:' || e.id),
      'dados', e.mobile_dados || jsonb_build_object(
        'titulo', coalesce(e.mobile_dados->>'titulo', 'Exame'), 'descripcion', coalesce(e.descricao, ''),
        'materiaId', coalesce(m.mobile_id, 'api:' || m.id, e.mobile_dados->>'materiaId', ''),
        'fecha', e.data_hora at time zone v_fuso,
        'actualizadoEn', e.atualizado_em at time zone 'UTC')) order by e.id)
      from public.exames e left join public.materias m on m.id = e.materia_id
      where e.usuario_id = p_usuario_id), '[]'::jsonb),
    'sesionesEstudio', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'dados', r.dados) order by r.id)
      from public.mobile_registros r where r.usuario_id = p_usuario_id and r.tipo = 'sesionesEstudio'), '[]'::jsonb),
    'notificaciones', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'dados', r.dados) order by r.id)
      from public.mobile_registros r where r.usuario_id = p_usuario_id and r.tipo = 'notificaciones'), '[]'::jsonb));
  return v_estado;
end;
$$;

create or replace function public.vincular_conta_firebase_existente(
  p_usuario_id integer, p_uid text, p_senha_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_usuario public.usuarios%rowtype;
begin
  if coalesce(p_uid, '') = '' or length(p_uid) > 128 then
    return jsonb_build_object('status', 400, 'erro', 'identidade inválida');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('firebase:' || p_uid, 0));
  select * into v_usuario from public.usuarios where id = p_usuario_id for update;
  if not found or v_usuario.senha_hash is null or v_usuario.senha_hash is distinct from p_senha_hash then
    return jsonb_build_object('status', 409, 'erro', 'a conta mudou; entre novamente antes de vincular');
  end if;
  if (v_usuario.firebase_uid is not null and v_usuario.firebase_uid <> p_uid)
      or exists(select 1 from public.usuarios where firebase_uid = p_uid and id <> p_usuario_id) then
    return jsonb_build_object('status', 409, 'erro', 'esta identidade já está vinculada a outra conta');
  end if;
  update public.usuarios set firebase_uid = p_uid, senha_hash = null
    where id = p_usuario_id returning * into v_usuario;
  return jsonb_build_object('status', 200, 'usuario', to_jsonb(v_usuario));
exception when unique_violation then
  return jsonb_build_object('status', 409, 'erro', 'esta identidade já está vinculada a outra conta');
end;
$$;

create or replace function public.mobile_perfil(p_usuario_id integer, p_dados jsonb, p_importar boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_usuario public.usuarios%rowtype; v_patch jsonb; v_plano text;
begin
  select * into strict v_usuario from public.usuarios where id = p_usuario_id for update;
  if p_importar and exists(select 1 from public.mobile_importados
      where usuario_id = p_usuario_id and tipo = 'perfil' and id = 'perfil') then
    return jsonb_build_object('status', 200, 'perfil', public.mobile_estado(p_usuario_id)->'perfil');
  end if;
  if jsonb_typeof(p_dados) is distinct from 'object' then
    return jsonb_build_object('status', 400, 'erro', 'perfil inválido');
  end if;
  v_patch := p_dados - array['firebase_uid', 'senha_hash', 'usuario_id', 'id', 'email', 'plano'];
  -- Nulos removem campos como a foto, em equivalência ao FieldValue.delete.
  if p_importar then
    v_patch := v_patch - array(select jsonb_object_keys(v_usuario.perfil_mobile));
  end if;
  v_plano := coalesce(v_patch->>'plan', v_usuario.plano);
  if v_plano = 'gratis' then v_plano := 'free'; end if;
  if v_plano not in ('free', 'pro', 'premium') then v_plano := v_usuario.plano; end if;
  if p_importar and v_usuario.perfil_mobile ? 'plan' then v_plano := v_usuario.plano; end if;
  update public.usuarios set
    perfil_mobile = jsonb_strip_nulls(v_usuario.perfil_mobile || v_patch),
    nome = coalesce(nullif(trim(v_patch->>'nombre'), ''), nome),
    plano = v_plano, atualizado_em = clock_timestamp() at time zone 'UTC'
    where id = p_usuario_id;
  if p_importar then
    insert into public.mobile_importados values(p_usuario_id, 'perfil', 'perfil') on conflict do nothing;
  end if;
  return jsonb_build_object('status', 200, 'perfil', public.mobile_estado(p_usuario_id)->'perfil');
end;
$$;

drop function if exists public.mobile_gravar(integer,text,text,jsonb,boolean);
create or replace function public.mobile_gravar(
  p_usuario_id integer, p_tipo text, p_id text, p_dados jsonb,
  p_importar boolean default false, p_atualizar boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_tabela text;
  v_id bigint;
  v_materia integer;
  v_fuso text;
  v_existe boolean;
  v_estado jsonb;
  v_registro jsonb;
  v_agora timestamptz := clock_timestamp();
begin
  if p_tipo not in ('materias', 'tareas', 'examenes', 'sesionesEstudio', 'notificaciones')
      or coalesce(p_id, '') = '' or length(p_id) > 200 or jsonb_typeof(p_dados) is distinct from 'object' then
    return jsonb_build_object('status', 400, 'erro', 'registro inválido');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('mobile:' || p_usuario_id || ':' || p_tipo || ':' || p_id, 0));
  if p_tipo in ('materias', 'tareas', 'examenes') then
    v_tabela := case p_tipo when 'materias' then 'materias' when 'tareas' then 'tarefas' else 'exames' end;
    execute format('select id from public.%I where usuario_id = $1 and coalesce(mobile_id, ''api:'' || id) = $2 for update', v_tabela)
      into v_id using p_usuario_id, p_id;
    v_existe := v_id is not null;
  else
    select exists(select 1 from public.mobile_registros
      where usuario_id = p_usuario_id and tipo = p_tipo and id = p_id) into v_existe;
  end if;
  if p_atualizar and not v_existe then
    return jsonb_build_object('status', 404, 'erro', 'registro não encontrado');
  end if;
  if not p_importar and not v_existe and exists(select 1 from public.mobile_importados
      where usuario_id = p_usuario_id and tipo = p_tipo and id = p_id) then
    return jsonb_build_object('status', 410, 'erro', 'este cadastro já foi excluído');
  end if;
  if p_importar and exists(select 1 from public.mobile_importados
      where usuario_id = p_usuario_id and tipo = p_tipo and id = p_id) then
    perform public.mobile_avancar_importacao(p_usuario_id, p_tipo, p_id);
    return jsonb_build_object('status', 200, 'ignorado', true);
  end if;
  if not p_importar then
    v_estado := public.mobile_estado(p_usuario_id);
    select item->'dados' into v_registro from jsonb_array_elements(v_estado->p_tipo) item where item->>'id' = p_id;
    p_dados := coalesce(v_registro, '{}'::jsonb) || p_dados;
  end if;
  if (p_tipo = 'materias' and coalesce(trim(p_dados->>'nombre'), '') = '')
      or (p_tipo in ('tareas', 'examenes') and coalesce(trim(p_dados->>'titulo'), '') = '')
      or (p_tipo = 'tareas' and coalesce(p_dados->>'fechaEntrega', '') = '')
      or (p_tipo in ('examenes', 'sesionesEstudio') and coalesce(p_dados->>'fecha', '') = '') then
    return jsonb_build_object('status', 400, 'erro', 'campos obrigatórios ausentes');
  end if;
  if p_tipo = 'sesionesEstudio' and (coalesce((p_dados->>'minutos')::integer, 0) not between 1 and 1440) then
    return jsonb_build_object('status', 400, 'erro', 'duração inválida');
  end if;
  select fuso_horario into v_fuso from public.preferencias_notificacao where usuario_id = p_usuario_id;
  v_fuso := coalesce(v_fuso, 'America/Sao_Paulo');
  p_dados := p_dados || jsonb_build_object('actualizadoEn', v_agora);
  if p_tipo in ('tareas', 'examenes') and coalesce(p_dados->>'materiaId', '') <> '' then
    select id into v_materia from public.materias
      where usuario_id = p_usuario_id and coalesce(mobile_id, 'api:' || id) = p_dados->>'materiaId';
    if not found and not p_importar then
      return jsonb_build_object('status', 404, 'erro', 'matéria não encontrada');
    end if;
  end if;

  if p_tipo in ('sesionesEstudio', 'notificaciones') then
    if p_importar and v_existe then
      perform public.mobile_avancar_importacao(p_usuario_id, p_tipo, p_id);
      return jsonb_build_object('status', 200, 'ignorado', true);
    end if;
    insert into public.mobile_registros(usuario_id, tipo, id, dados)
      values (p_usuario_id, p_tipo, p_id, p_dados)
      on conflict (usuario_id, tipo, id) do update set dados = mobile_registros.dados || excluded.dados;
  else
    if p_importar and v_existe then
      perform public.mobile_avancar_importacao(p_usuario_id, p_tipo, p_id);
      return jsonb_build_object('status', 200, 'ignorado', true);
    end if;
    if p_tipo = 'materias' then
      if not v_existe and not p_importar then
        perform 1 from public.usuarios where id = p_usuario_id for update;
        if (select plano from public.usuarios where id = p_usuario_id) = 'free'
            and (select count(*) from public.materias where usuario_id = p_usuario_id) >= 5 then
          return jsonb_build_object('status', 402, 'erro', 'o plano Free permite até cinco matérias');
        end if;
      end if;
      if v_existe then
        update public.materias set nome = p_dados->>'nombre', professor = coalesce(p_dados->>'docente', ''),
          mobile_dados = mobile_dados || p_dados, atualizado_em = v_agora at time zone 'UTC'
          where id = v_id and usuario_id = p_usuario_id;
      else
        insert into public.materias(usuario_id, nome, professor, cor, mobile_id, mobile_dados)
          values (p_usuario_id, p_dados->>'nombre', coalesce(p_dados->>'docente', ''),
            coalesce(nullif(p_dados->>'cor', ''), '#670810'), p_id, p_dados) returning id into v_id;
      end if;
    elsif p_tipo = 'tareas' then
      if v_existe then
        update public.tarefas set titulo = p_dados->>'titulo', descricao = coalesce(p_dados->>'descripcion', ''),
          materia_id = v_materia,
          data_entrega = (p_dados->>'fechaEntrega')::timestamptz at time zone v_fuso,
          status = (jsonb_populate_record(null::public.tarefas, jsonb_build_object('status',
            case when coalesce((p_dados->>'completada')::boolean, false) then 'concluida' else 'pendente' end))).status,
          mobile_dados = mobile_dados || p_dados, atualizado_em = v_agora at time zone 'UTC'
          where id = v_id and usuario_id = p_usuario_id;
      else
        insert into public.tarefas(usuario_id, materia_id, titulo, descricao, data_entrega, status, mobile_id, mobile_dados)
          values (p_usuario_id, v_materia, p_dados->>'titulo', coalesce(p_dados->>'descripcion', ''),
            (p_dados->>'fechaEntrega')::timestamptz at time zone v_fuso,
            (jsonb_populate_record(null::public.tarefas, jsonb_build_object('status',
              case when coalesce((p_dados->>'completada')::boolean, false) then 'concluida' else 'pendente' end))).status,
            p_id, p_dados) returning id into v_id;
      end if;
    else
      if v_existe then
        update public.exames set descricao = coalesce(p_dados->>'descripcion', ''), materia_id = v_materia,
          data_hora = (p_dados->>'fecha')::timestamptz at time zone v_fuso,
          mobile_dados = mobile_dados || p_dados, atualizado_em = v_agora at time zone 'UTC'
          where id = v_id and usuario_id = p_usuario_id;
      else
        insert into public.exames(usuario_id, materia_id, descricao, data_hora, mobile_id, mobile_dados)
          values (p_usuario_id, v_materia, coalesce(p_dados->>'descripcion', ''),
            (p_dados->>'fecha')::timestamptz at time zone v_fuso, p_id, p_dados) returning id into v_id;
      end if;
    end if;
  end if;
  insert into public.mobile_importados values(p_usuario_id, p_tipo, p_id) on conflict do nothing;
  if p_importar then
    perform public.mobile_avancar_importacao(p_usuario_id, p_tipo, p_id);
    return jsonb_build_object('status', case when v_existe then 200 else 201 end);
  end if;
  v_estado := public.mobile_estado(p_usuario_id);
  select item into v_registro from jsonb_array_elements(v_estado->p_tipo) item where item->>'id' = p_id;
  return jsonb_build_object('status', case when v_existe then 200 else 201 end, 'registro', v_registro);
end;
$$;

create or replace function public.mobile_excluir(p_usuario_id integer, p_tipo text, p_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_id integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('mobile:' || p_usuario_id || ':' || p_tipo || ':' || p_id, 0));
  if p_tipo = 'materias' then
    select id into v_id from public.materias where usuario_id = p_usuario_id
      and coalesce(mobile_id, 'api:' || id) = p_id for update;
    if v_id is not null then
      if exists(select 1 from public.tarefas where materia_id = v_id)
          or exists(select 1 from public.exames where materia_id = v_id) then
        return jsonb_build_object('status', 409, 'erro', 'esta matéria possui tarefas ou provas associadas');
      end if;
      delete from public.horarios_aula where materia_id = v_id;
      delete from public.materias where id = v_id and usuario_id = p_usuario_id;
    end if;
  elsif p_tipo = 'tareas' then
    delete from public.tarefas where usuario_id = p_usuario_id and coalesce(mobile_id, 'api:' || id) = p_id;
  elsif p_tipo = 'examenes' then
    delete from public.exames where usuario_id = p_usuario_id and coalesce(mobile_id, 'api:' || id) = p_id;
  elsif p_tipo in ('sesionesEstudio', 'notificaciones') then
    delete from public.mobile_registros where usuario_id = p_usuario_id and tipo = p_tipo and id = p_id;
  else
    return jsonb_build_object('status', 400, 'erro', 'recurso inválido');
  end if;
  insert into public.mobile_importados values (p_usuario_id, p_tipo, p_id) on conflict do nothing;
  return jsonb_build_object('status', 200, 'mensagem', 'registro removido');
end;
$$;

revoke all on function public.vincular_usuario_firebase(text,text,text) from public, anon, authenticated;
revoke all on function public.mobile_estado(integer) from public, anon, authenticated;
revoke all on function public.mobile_perfil(integer,jsonb,boolean) from public, anon, authenticated;
revoke all on function public.mobile_gravar(integer,text,text,jsonb,boolean,boolean) from public, anon, authenticated;
revoke all on function public.mobile_excluir(integer,text,text) from public, anon, authenticated;
revoke all on function public.mobile_avancar_importacao(integer,text,text) from public, anon, authenticated;
revoke all on function public.mobile_finalizar_tipo(integer,text) from public, anon, authenticated;
revoke all on function public.vincular_conta_firebase_existente(integer,text,text) from public, anon, authenticated;
grant execute on function public.vincular_usuario_firebase(text,text,text) to service_role;
grant execute on function public.mobile_estado(integer) to service_role;
grant execute on function public.mobile_perfil(integer,jsonb,boolean) to service_role;
grant execute on function public.mobile_gravar(integer,text,text,jsonb,boolean,boolean) to service_role;
grant execute on function public.mobile_excluir(integer,text,text) to service_role;
grant execute on function public.mobile_finalizar_tipo(integer,text) to service_role;
grant execute on function public.vincular_conta_firebase_existente(integer,text,text) to service_role;
notify pgrst, 'reload schema';
commit;
