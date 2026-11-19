-- OPCIONAL. Confirme que Flutter e painel consomem os dados somente pela API
-- e que SUPABASE_KEY na Vercel é service_role (nunca incluída no Flutter).
-- Se o aplicativo acessa as tabelas diretamente com anon key, isto muda esse acesso.
-- A migração não apaga nenhuma tabela nem registro.

alter table public.usuarios enable row level security;
alter table public.materias enable row level security;
alter table public.horarios_aula enable row level security;
alter table public.tarefas enable row level security;
alter table public.exames enable row level security;
alter table public.locais enable row level security;
alter table public.preferencias_notificacao enable row level security;
alter table public.dispositivos enable row level security;

-- Consulte o painel Policies do Supabase e revise eventuais políticas
-- já criadas para anon/authenticated. Enable RLS não remove permissões antigas.
