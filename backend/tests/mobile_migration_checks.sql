do $teste$
declare
  conta jsonb;
  estado jsonb;
  resposta jsonb;
  usuario integer;
  outra integer;
begin
  if (select usuario_id from public.tarefas where titulo = 'Tarefa legada') is distinct from 1 then
    raise exception 'atividade legada perdeu dono';
  end if;
  conta := public.vincular_usuario_firebase('uid-a','a@example.com','Ana');
  usuario := (conta#>>'{usuario,id}')::integer;
  if usuario is null or (conta->>'status')::integer <> 200 then raise exception 'vinculo inicial'; end if;
  if (public.vincular_usuario_firebase('uid-a','a@example.com','Outro nome')#>>'{usuario,id}')::integer <> usuario then
    raise exception 'identidade duplicada';
  end if;
  if (public.vincular_usuario_firebase('uid-outro','legado@example.com','Outro')->>'status')::integer <> 409 then
    raise exception 'conta legada foi mesclada pelo email';
  end if;
  if (public.vincular_conta_firebase_existente(1,'uid-legado','hash-incorreto')->>'status')::integer <> 409 then
    raise exception 'vinculo sem prova da senha';
  end if;
  resposta := public.vincular_conta_firebase_existente(1,'uid-legado','hash-antigo');
  if (resposta->>'status')::integer <> 200
      or (select senha_hash from public.usuarios where id=1) is not null then
    raise exception 'vinculo de conta antiga nao encerrou senha legada';
  end if;
  outra := (public.vincular_usuario_firebase('uid-b','b@example.com','Bruno')#>>'{usuario,id}')::integer;
  perform public.mobile_perfil(usuario, '{"nombre":"Ana atualizada","plan":"pro","fotoPerfilBytes":"Zm90bw==","metaSemanalDias":5}', false);
  perform public.mobile_perfil(usuario, '{"fotoPerfilBytes":null}', false);
  estado := public.mobile_estado(usuario);
  if estado#>>'{perfil,nombre}' <> 'Ana atualizada' or estado#>>'{perfil,plan}' <> 'pro'
      or estado->'perfil' ? 'fotoPerfilBytes' then raise exception 'perfil e plano'; end if;

  perform public.mobile_gravar(usuario,'materias','materia-a','{"nombre":"Mobile II","docente":"Prof","descripcion":"Preservada"}',true);
  perform public.mobile_gravar(usuario,'tareas','tarefa-a',
    '{"titulo":"Lista","fechaEntrega":"2026-12-18T15:00:00Z","materiaId":"materia-a","minutosAntes":10,"prioridad":"ALTA"}',true);
  perform public.mobile_gravar(usuario,'tareas','sem-materia',
    '{"titulo":"Pessoal","fechaEntrega":"2026-12-18T15:00:00Z","materiaId":""}',true);
  perform public.mobile_gravar(usuario,'examenes','prova-a',
    '{"titulo":"Prova II","descripcion":"Capitulo 2","fecha":"2026-12-18T16:00:00Z","materiaId":"materia-a"}',true);
  perform public.mobile_gravar(usuario,'sesionesEstudio','sessao-a',
    '{"materiaId":"materia-a","minutos":50,"fecha":"2026-12-18T16:00:00Z"}',true);
  perform public.mobile_gravar(usuario,'notificaciones','doc-a','{"id":51,"titulo":"Lembrete","leida":false}',true);
  resposta := public.mobile_gravar(usuario,'tareas','tarefa-a','{"completada":true}',false);
  if (resposta#>>'{registro,dados,completada}')::boolean is distinct from true
      or resposta#>>'{registro,dados,titulo}' <> 'Lista'
      or resposta#>>'{registro,dados,materiaId}' <> 'materia-a' then raise exception 'merge parcial tarefa %', resposta; end if;
  perform public.mobile_gravar(usuario,'tareas','tarefa-a',
    '{"titulo":"Antiga","fechaEntrega":"2026-12-18T15:00:00Z","materiaId":"materia-a"}',true);
  if (select titulo from public.tarefas where usuario_id=usuario and mobile_id='tarefa-a') <> 'Lista'
      or (select status::text from public.tarefas where usuario_id=usuario and mobile_id='tarefa-a') <> 'concluida' then
    raise exception 'reimportacao sobrescreveu dado editado';
  end if;
  perform public.mobile_gravar(usuario,'notificaciones','doc-a','{"leida":true}',false);
  estado := public.mobile_estado(usuario);
  if jsonb_array_length(estado->'tareas') <> 2 or estado#>>'{notificaciones,0,id}' <> 'doc-a'
      or (estado#>>'{notificaciones,0,dados,id}')::integer <> 51
      or (estado#>>'{notificaciones,0,dados,leida}')::boolean is not true then
    raise exception 'estado/ID notificacao %', estado;
  end if;
  if jsonb_array_length(public.mobile_estado(outra)->'tareas') <> 0 then raise exception 'vazamento entre contas'; end if;
  perform public.mobile_excluir(outra,'tareas','tarefa-a');
  if not exists(select 1 from public.tarefas where usuario_id=usuario and mobile_id='tarefa-a') then
    raise exception 'exclusao fora da conta';
  end if;
  if (public.mobile_excluir(usuario,'materias','materia-a')->>'status')::integer <> 409 then
    raise exception 'exclusao de materia com dependentes';
  end if;
  perform public.mobile_excluir(usuario,'tareas','tarefa-a');
  if (public.mobile_gravar(usuario,'tareas','tarefa-a','{"completada":true}',false,true)->>'status')::integer <> 404 then
    raise exception 'edicao recriou registro excluido';
  end if;
  if (public.mobile_gravar(usuario,'tareas','tarefa-a',
      '{"titulo":"Antiga","fechaEntrega":"2026-12-18T15:00:00Z"}',false)->>'status')::integer <> 410 then
    raise exception 'reenvio recriou cadastro excluido';
  end if;
  perform public.mobile_gravar(usuario,'tareas','tarefa-a',
    '{"titulo":"Antiga","fechaEntrega":"2026-12-18T15:00:00Z"}',true);
  if exists(select 1 from public.tarefas where usuario_id=usuario and mobile_id='tarefa-a') then
    raise exception 'reimportacao recriou dado excluido';
  end if;
  if has_function_privilege('anon','public.mobile_estado(integer)','EXECUTE')
      or not has_function_privilege('service_role','public.mobile_estado(integer)','EXECUTE') then
    raise exception 'permissoes das funcoes';
  end if;
end;
$teste$;
select 'STUDYTRACK_MOBILE_SQL_OK';
