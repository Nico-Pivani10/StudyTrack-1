do $teste$
declare
  docs jsonb := jsonb_build_object(
    'termos', jsonb_build_object('versao','1.1','sha256',repeat('a',64),'texto','Termos apresentados'),
    'privacidade', jsonb_build_object('versao','1.1','sha256',repeat('b',64),'texto','Aviso apresentado'));
  resposta jsonb;
  usuario integer;
  legado integer;
  aceito timestamptz;
begin
  resposta := public.autenticar_firebase_com_aceite('uid-sem-aceite','sem@example.com','Sem',docs,false);
  if (resposta->>'status')::int <> 428 or exists(select 1 from public.usuarios where firebase_uid='uid-sem-aceite') then
    raise exception 'conta criada sem aceite';
  end if;
  resposta := public.autenticar_firebase_com_aceite('uid-com-aceite','com@example.com','Com',docs,true);
  usuario := (resposta#>>'{usuario,id}')::int;
  if (resposta->>'status')::int <> 200 or not public.mobile_possui_aceite(usuario,docs) then
    raise exception 'conta e aceite nao registrados juntos';
  end if;
  select aceito_em into aceito from public.aceites_documentos where usuario_id=usuario;
  if (select documentos#>>'{termos,texto}' from public.aceites_documentos where usuario_id=usuario) <> 'Termos apresentados' then
    raise exception 'texto apresentado nao preservado';
  end if;
  resposta := public.autenticar_firebase_com_aceite('uid-com-aceite','com@example.com','Com',docs,false);
  if (resposta->>'status')::int <> 200 then raise exception 'login repetiu exigencia sem mudanca'; end if;
  perform public.autenticar_firebase_com_aceite('uid-com-aceite','com@example.com','Com',docs,true);
  if (select count(*) from public.aceites_documentos where usuario_id=usuario) <> 1
      or (select aceito_em from public.aceites_documentos where usuario_id=usuario) <> aceito then
    raise exception 'aceite duplicado ou data original alterada';
  end if;
  docs := jsonb_set(docs,'{termos,sha256}',to_jsonb(repeat('c',64)));
  resposta := public.autenticar_firebase_com_aceite('uid-com-aceite','com@example.com','Com',docs,false);
  if (resposta->>'status')::int <> 428 then raise exception 'texto alterado aceito sem confirmacao'; end if;
  perform public.autenticar_firebase_com_aceite('uid-com-aceite','com@example.com','Com',docs,true);
  if (select count(*) from public.aceites_documentos where usuario_id=usuario) <> 2 then
    raise exception 'historico de versoes perdido';
  end if;
  insert into public.usuarios(nome,email,senha_hash) values('Legado II','legado2@example.com','hash-legado') returning id into legado;
  resposta := public.vincular_firebase_com_aceite(legado,'uid-legado2','hash-legado',docs,false);
  if (resposta->>'status')::int <> 428 or (select firebase_uid from public.usuarios where id=legado) is not null then
    raise exception 'vinculo realizado sem aceite';
  end if;
  resposta := public.vincular_firebase_com_aceite(legado,'uid-legado2','hash-legado',docs,true);
  if (resposta->>'status')::int <> 200 or not public.mobile_possui_aceite(legado,docs) then
    raise exception 'vinculo nao registrou aceite';
  end if;
  if has_table_privilege('anon','public.aceites_documentos','SELECT')
      or has_function_privilege('authenticated','public.autenticar_firebase_com_aceite(text,text,text,jsonb,boolean)','EXECUTE') then
    raise exception 'permissoes inadequadas';
  end if;
end;
$teste$;
select 'STUDYTRACK_LEGAL_SQL_OK';
