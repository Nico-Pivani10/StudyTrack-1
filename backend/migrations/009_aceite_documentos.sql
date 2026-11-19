-- Execute após 008. Registra o texto e a versão efetivamente apresentados no app.
begin;

create table if not exists public.aceites_documentos (
  id bigint generated always as identity primary key,
  usuario_id integer not null references public.usuarios(id) on delete cascade,
  termos_versao text not null,
  termos_sha256 text not null check (termos_sha256 ~ '^[a-f0-9]{64}$'),
  privacidade_versao text not null,
  privacidade_sha256 text not null check (privacidade_sha256 ~ '^[a-f0-9]{64}$'),
  documentos jsonb not null,
  aceito_em timestamptz not null default clock_timestamp(),
  unique (usuario_id, termos_sha256, privacidade_sha256)
);
alter table public.aceites_documentos enable row level security;
revoke all on public.aceites_documentos from public, anon, authenticated;

-- Os documentos vêm apenas do servidor, que confere o aceite e seus hashes.
create or replace function public.mobile_possui_aceite(p_usuario_id integer, p_documentos jsonb)
returns boolean language sql stable set search_path = '' as $$
  select exists(select 1 from public.aceites_documentos
    where usuario_id = p_usuario_id
      and termos_sha256 = p_documentos#>>'{termos,sha256}'
      and termos_versao = p_documentos#>>'{termos,versao}'
      and privacidade_sha256 = p_documentos#>>'{privacidade,sha256}'
      and privacidade_versao = p_documentos#>>'{privacidade,versao}');
$$;

create or replace function public.mobile_registrar_aceite(p_usuario_id integer, p_documentos jsonb)
returns void language sql set search_path = '' as $$
  insert into public.aceites_documentos (usuario_id, termos_versao, termos_sha256,
    privacidade_versao, privacidade_sha256, documentos)
  values (p_usuario_id, p_documentos#>>'{termos,versao}', p_documentos#>>'{termos,sha256}',
    p_documentos#>>'{privacidade,versao}', p_documentos#>>'{privacidade,sha256}', p_documentos)
  on conflict (usuario_id, termos_sha256, privacidade_sha256) do nothing;
$$;

create or replace function public.autenticar_firebase_com_aceite(
  p_uid text, p_email text, p_nome text, p_documentos jsonb, p_aceitou boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_usuario integer; v_resposta jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('firebase:' || p_uid, 0));
  select id into v_usuario from public.usuarios where firebase_uid = p_uid;
  if not coalesce(p_aceitou, false) and not public.mobile_possui_aceite(v_usuario, p_documentos) then
    return jsonb_build_object('status', 428, 'codigo', 'aceite_necessario',
      'erro', 'leia os documentos e confirme o aceite para continuar');
  end if;
  v_resposta := public.vincular_usuario_firebase(p_uid, p_email, p_nome);
  if (v_resposta->>'status')::integer = 200 and p_aceitou then
    perform public.mobile_registrar_aceite((v_resposta#>>'{usuario,id}')::integer, p_documentos);
  end if;
  return v_resposta;
end;
$$;

create or replace function public.vincular_firebase_com_aceite(
  p_usuario_id integer, p_uid text, p_senha_hash text, p_documentos jsonb, p_aceitou boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_resposta jsonb;
begin
  if not coalesce(p_aceitou, false) and not public.mobile_possui_aceite(p_usuario_id, p_documentos) then
    return jsonb_build_object('status', 428, 'codigo', 'aceite_necessario',
      'erro', 'leia os documentos e confirme o aceite para continuar');
  end if;
  v_resposta := public.vincular_conta_firebase_existente(p_usuario_id, p_uid, p_senha_hash);
  if (v_resposta->>'status')::integer = 200 and p_aceitou then
    perform public.mobile_registrar_aceite(p_usuario_id, p_documentos);
  end if;
  return v_resposta;
end;
$$;

revoke all on function public.mobile_possui_aceite(integer,jsonb) from public, anon, authenticated;
revoke all on function public.mobile_registrar_aceite(integer,jsonb) from public, anon, authenticated;
revoke all on function public.autenticar_firebase_com_aceite(text,text,text,jsonb,boolean) from public, anon, authenticated;
revoke all on function public.vincular_firebase_com_aceite(integer,text,text,jsonb,boolean) from public, anon, authenticated;
grant execute on function public.autenticar_firebase_com_aceite(text,text,text,jsonb,boolean) to service_role;
grant execute on function public.vincular_firebase_com_aceite(integer,text,text,jsonb,boolean) to service_role;
notify pgrst, 'reload schema';
commit;
