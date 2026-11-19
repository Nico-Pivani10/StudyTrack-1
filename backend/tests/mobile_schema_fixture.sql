-- Esquema mínimo exclusivamente para validar as migrações num banco descartável.
create role anon;
create role authenticated;
create role service_role;
set time zone 'UTC';
create type public.tipo_local as enum ('casa', 'instituicao');
create type public.status_tarefa as enum ('pendente', 'concluida');
create table public.usuarios (
  id integer generated always as identity primary key, nome text not null, email text not null unique,
  senha_hash text not null, criado_em timestamp default now(), atualizado_em timestamp default now());
create table public.materias (
  id integer generated always as identity primary key, usuario_id integer not null references public.usuarios(id),
  nome text not null, professor text, cor text not null, atualizado_em timestamp not null default now());
create table public.horarios_aula (
  id integer generated always as identity primary key, materia_id integer not null references public.materias(id),
  dia_semana smallint not null, hora_inicio time not null, hora_fim time not null);
create table public.tarefas (
  id integer generated always as identity primary key, materia_id integer not null references public.materias(id),
  titulo text not null, descricao text, data_entrega timestamp not null,
  status public.status_tarefa default 'pendente', atualizado_em timestamp not null default now());
create table public.exames (
  id integer generated always as identity primary key, materia_id integer not null references public.materias(id),
  descricao text, data_hora timestamp not null, atualizado_em timestamp not null default now());
create table public.dispositivos (
  id integer generated always as identity primary key, usuario_id integer not null references public.usuarios(id),
  fcm_token text unique not null);
create table public.locais (
  id integer generated always as identity primary key, usuario_id integer not null references public.usuarios(id),
  tipo public.tipo_local not null, latitude numeric not null, longitude numeric not null,
  raio_metros integer not null default 200, atualizado_em timestamp not null default now(), unique (usuario_id, tipo));
create table public.preferencias_notificacao (
  usuario_id integer primary key references public.usuarios(id), notif_tarefas boolean default true,
  notif_exames boolean default true, notif_lembrete_estudo boolean default true, gps_ativo boolean default true);
insert into public.usuarios (nome,email,senha_hash) values ('Legado','legado@example.com','hash-antigo');
insert into public.materias (usuario_id,nome,cor) values (1,'Legada','#AABBCC');
insert into public.tarefas (materia_id,titulo,data_entrega) values (1,'Tarefa legada','2026-12-18T12:00:00');
