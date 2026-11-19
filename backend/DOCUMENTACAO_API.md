# API do StudyTrack

O aplicativo Flutter usa esta API REST em JSON para gerenciar o perfil e a rotina acadêmica. A identidade por e-mail ou Google continua no Firebase Authentication. O servidor valida a identidade e emite um JWT para o acesso aos dados do Supabase. O contrato inclui o fluxo mobile e as rotas de cadastro direto da API.

| Ambiente | URL base |
|---|---|
| Publicação na Vercel | `https://studytrackk.vercel.app` |
| Desenvolvimento com Vercel CLI | `http://localhost:3000` |

As rotas nesta página são relativas à URL base. Envie `Content-Type: application/json` nas requisições com corpo JSON. Use o JWT da API no cabeçalho `Authorization`, salvo nas rotas indicadas como públicas ou internas. O contrato `/api/mobile` usa IDs textuais e campos compatíveis com o aplicativo. As rotas como `/api/materias` usam IDs numéricos do servidor.

## Preparar a integração Flutter

Aplique `migrations/008_integracao_firebase_mobile.sql` após as migrações anteriores e depois `009_aceite_documentos.sql`. Instale as dependências do backend e publique todos os módulos de `api/`, incluindo os documentos gerados. Configure `FIREBASE_PROJECT_ID` e `FIREBASE_CREDENTIALS` no servidor para o mesmo projeto Firebase usado pelo Flutter. A conta de serviço precisa verificar usuários e ler o Firestore legado. O backend usa `SUPABASE_URL`, `SUPABASE_KEY` com permissão de servidor e `JWT_SECRET`. Os detalhes de implantação ficam no README da API.

O Flutter aceita a URL por `--dart-define=STUDYTRACK_API_URL=https://studytrackk.vercel.app`. No login, `ApiClient.connect()` troca a identidade Firebase pelo JWT, chama a importação e busca o estado antes de abrir o dashboard. Uma falha nessa conexão é mostrada no login para permitir nova tentativa.

## Autenticar o aplicativo com Firebase

### Consultar os documentos e confirmar o aceite

`GET /api/legal/documentos` é público e retorna `200` com `documentos.termos` e `documentos.privacidade`. Cada documento contém `titulo`, `versao`, `sha256` e `texto`. O aplicativo abre esses textos em uma tela de leitura e mantém a caixa de confirmação desmarcada até a ação da pessoa. A migração `009_aceite_documentos.sql` deve estar aplicada após a `008` antes de publicar esta versão.

No primeiro acesso, envie junto ao ID token o campo `aceite`, com as versões e hashes recebidos:

```json
{
  "id_token": "ID_TOKEN_OBTIDO_NO_FIREBASE",
  "aceite": {
    "termos": {"aceito": true, "versao": "1.2", "sha256": "HASH_DOS_TERMOS_RECEBIDO_NA_CONSULTA"},
    "privacidade": {"aceito": true, "versao": "1.2", "sha256": "HASH_DO_AVISO_RECEBIDO_NA_CONSULTA"}
  }
}
```

Os mesmos campos são aceitos em `POST /api/auth/firebase/vincular`. A API confere os dois booleanos, as versões e os hashes. O servidor fornece os textos arquivados; conteúdos enviados pelo cliente não são usados como prova. A criação ou vinculação da conta e o registro do aceite são uma transação. A tabela `aceites_documentos` guarda o usuário, versões, hashes, textos e `aceito_em` do servidor. Não são coletados IP ou dados do dispositivo para este registro.

Sem registro do aceite atual, a autenticação retorna `428`, com `codigo: "aceite_necessario"`, e não emite JWT nem cria a conta SQL. Um texto ou versão desatualizada retorna `409`, com `codigo: "documentos_atualizados"`. Nas contas que já confirmaram os documentos atuais, o campo `aceite` pode ser omitido ao renovar ou iniciar a sessão. A renovação não altera a data original. Uma nova combinação de hashes preserva os aceites anteriores.

No cadastro por e-mail e no acesso com Google, a interface solicita a confirmação antes de chamar o Firebase para criar a identidade. Em contas antigas, a confirmação pode ser solicitada após identificar a conta, antes da entrada no painel. Os campos do formulário são preservados ao abrir os documentos. O aviso de privacidade informa sobre o tratamento; permissões opcionais continuam separadas.

### Trocar a identidade pela sessão da API

`POST /api/auth/firebase` recebe um ID token obtido no Firebase Authentication. O servidor valida a assinatura, o projeto, a validade e o estado da identidade com o Firebase Admin. O UID confirmado vincula a identidade à conta SQL.

```http
POST /api/auth/firebase
Content-Type: application/json

{"id_token":"ID_TOKEN_OBTIDO_NO_FIREBASE"}
```

Uma resposta `200` devolve `token`, `tipo` igual a `Bearer`, `expira_em_segundos` igual a `3600` e `usuario`. O JWT da API tem identidade Firebase vinculada. O middleware confere também revogação ou desativação da conta Firebase. No app, o JWT fica em memória e uma resposta `401` provoca uma nova troca com a identidade Firebase antes de repetir a chamada uma vez. A API exige a confirmação de vínculo se o e-mail já estiver em uma conta independente, retornando `409` e `codigo` igual a `conta_nao_vinculada`.

Para confirmar esse vínculo, autentique a conta anterior por `POST /api/auth/login` com seu e-mail e senha. Envie o JWT dessa conta no cabeçalho de `POST /api/auth/firebase/vincular` e o ID token Firebase atual no corpo. A API confirma as duas identidades antes de associar o UID. O app pede a senha anterior em um diálogo, realiza essa confirmação e repete `connect()` para carregar os dados. Cancelar o diálogo interrompe a entrada no dashboard.

```http
POST /api/auth/firebase/vincular
Authorization: Bearer JWT_DA_CONTA_ANTERIOR
Content-Type: application/json

{"id_token":"ID_TOKEN_FIREBASE_ATUAL"}
```

O Flutter continua usando Firebase Authentication para criar contas, entrar com Google, verificar e-mail e recuperar senha. O nome editado no perfil é atualizado no backend e no nome de exibição Firebase. O logout solicita `POST /api/auth/logout` e encerra a sessão local e a sessão Firebase mesmo quando a chamada remota falha.

O vínculo exige autenticações recentes das duas contas. Depois de confirmado, o acesso dessa conta usa a identidade Firebase, e as sessões legadas por senha são encerradas.

## Contrato de dados mobile

Todas as rotas abaixo exigem JWT. O backend deriva a conta do token.

| Método | Rota | Entrada e resposta |
|---|---|---|
| GET | `/api/mobile/estado` | Retorna `200` com `perfil` e listas de `materias`, `tareas`, `examenes`, `sesionesEstudio` e `notificaciones` |
| PATCH | `/api/mobile/perfil` | Mescla os campos informados e retorna `200` com `perfil` |
| PUT | `/api/mobile/{tipo}/{id}` | Cria ou atualiza um registro do tipo permitido, preservando o ID textual. Retorna `201` ou `200` com `registro` |
| PATCH | `/api/mobile/{tipo}/{id}` | Atualiza parcialmente um registro existente. Retorna `200` com `registro`, ou `404` se ele foi removido |
| DELETE | `/api/mobile/{tipo}/{id}` | Exclui o registro da conta. Retorna `200` também quando ele já foi excluído |
| POST | `/api/mobile/importar` | Importa os dados do UID autenticado no Firestore e retorna `200` com `importado` e `contagens` |

Os valores de `{tipo}` são `materias`, `tareas`, `examenes`, `sesionesEstudio` e `notificaciones`. O `{id}` é uma string de 1 a 200 caracteres sem barra. O cliente cria um ID e usa a mesma URL para consultar o estado e editar esse registro. Cada item de lista retorna `{"id":"identificador","dados":{...}}`. O perfil é um objeto direto.

```json
{
  "perfil": {"nombre":"Estudante","email":"aluno@example.com","plan":"gratis","metaSemanalDias":5},
  "materias": [{"id":"mobile-01","dados":{"nombre":"Mobile II","docente":"Professora","descripcion":"Projeto semestral","cor":"#670810"}}],
  "tareas": [],
  "examenes": [],
  "sesionesEstudio": [],
  "notificaciones": []
}
```

| Tipo | Campos utilizados pelo Flutter |
|---|---|
| Perfil | `nombre`, `institucion`, `carrera`, `semestre`, `metaAcademica`, `metaSemanalDias`, `fotoPerfilBytes`, `fotoPerfilActualizada`, `plan`, `metodoPagoSimulado`, `planActualizadoEn` |
| `materias` | `nombre`, `descripcion`, `docente`, `cor`, `creadaEn`, `actualizadoEn` |
| `tareas` | `titulo`, `descripcion`, `materiaId`, `fechaEntrega`, `completada`, `prioridad`, `minutosAntes`, `notificacionId`, `creadaEn`, `actualizadoEn` |
| `examenes` | `titulo`, `descripcion`, `materiaId`, `fecha`, `creadaEn`, `actualizadoEn` |
| `sesionesEstudio` | `materiaId`, `minutos`, `fecha`, `creadaEn` |
| `notificaciones` | `id`, `titulo`, `mensaje`, `tipo`, `estado`, `fecha`, `creadaEn`, `leida`, `canceladaEn` |

`materiaId` usa o identificador textual de uma matéria da conta ou string vazia para atividades sem matéria. `completada` e `leida` são booleanos. `minutos` de uma sessão deve ficar entre 1 e 1.440 e `metaSemanalDias` entre 1 e 7. `minutosAntes` permite de 0 a 43.200. Envie datas em ISO 8601, preferencialmente com o instante UTC em `Z`. A foto usa base64 e tem limite de 150 KiB decodificados. Enviar `fotoPerfilBytes` como `null` remove a foto do perfil. O nome e o plano do perfil correspondem aos campos canônicos da conta.

O plano mobile é `gratis`, `pro` ou `premium`. `gratis` corresponde a `free` na coluna SQL. Os planos são demonstrativos. O limite de cinco matérias aplica-se a novos cadastros Free. A importação conserva as matérias já existentes mesmo acima desse limite. A exclusão de uma matéria com tarefas ou provas vinculadas retorna `409`, preservando o comportamento do Flutter.

```http
PUT /api/mobile/tareas/mobile-tarefa-01
Authorization: Bearer JWT_DA_API
Content-Type: application/json

{"titulo":"Revisar aula","materiaId":"mobile-01","fechaEntrega":"2026-11-25T22:00:00Z","completada":false,"minutosAntes":10}
```

Para alterar só o estado dessa tarefa, o app envia `PATCH` com `{"completada":true}` para a mesma rota. Os dados de edição são mesclados com o registro existente. Um `PUT` reenviado após a exclusão confirmada do cadastro retorna `410`. Após uma escrita bem-sucedida, o cliente atualiza o registro confirmado e recarrega `/api/mobile/estado`. Enquanto há telas assinando os dados, ele consulta atualizações a cada 30 segundos. Esta versão confirma alterações pela rede e mantém o estado de leitura em memória. A identificação de um cadastro sem confirmação fica em Shared Preferences para permitir o reenvio com o mesmo ID. A fila SQLite e os cabeçalhos de sincronização apresentados adiante pertencem às rotas de cadastro direto.

### Importação da versão anterior

Após autenticar, `POST /api/mobile/importar` lê pelo servidor o documento `usuarios/{uid}` e suas coleções `materias`, `tareas`, `examenes`, `sesionesEstudio` e `notificaciones`. O corpo da chamada é dispensável. A fonte usa o UID validado pelo token. A foto binária e os timestamps são convertidos para base64 e ISO 8601 para a persistência no Supabase.

A importação avança em lotes de até 20 registros. Enquanto houver dados restantes, retorna `importado=false` e `continuar=true`, e o cliente repete a chamada. Ela preserva IDs e referências, retoma registros restantes após uma interrupção e mantém marcadores que impedem a recriação de registros já importados ou excluídos. Ao concluir, grava `mobile_importado_em`. Chamadas seguintes retornam `ja_importado=true` sem buscar novamente a origem. Dados de origem continuam existentes até a equipe realizar sua política de remoção. Um registro legado inválido retorna `422` com `importado=false` e exige correção antes de retomar. Credenciais ou permissões indisponíveis retornam `503`.

## Contas criadas diretamente na API

`POST /api/usuarios` recebe `nome`, `email` e `senha`. Envie uma senha com pelo menos 8 caracteres e até 72 bytes em UTF-8. O servidor normaliza o e-mail para minúsculas. A resposta `201` contém `usuario` e o ID criado. E-mail duplicado retorna `409`. O cadastro atualmente recebe esses três campos. O aceite dos termos será adicionado em uma etapa posterior.

```http
POST /api/usuarios
Content-Type: application/json

{"nome":"Aluno Teste","email":"aluno@example.com","senha":"SenhaDeTeste123!"}
```

`POST /api/auth/login` recebe `email` e `senha`. Exemplo de resposta `200` com valores ilustrativos.

```json
{
  "token": "JWT_RECEBIDO_NO_LOGIN",
  "tipo": "Bearer",
  "expira_em_segundos": 3600,
  "usuario": {"id": 12, "nome": "Aluno Teste", "email": "aluno@example.com", "plano": "free"}
}
```

```http
GET /api/materias
Authorization: Bearer JWT_RECEBIDO_NO_LOGIN
```

O JWT dessas contas expira em 60 minutos. A mudança de senha encerra as sessões anteriores desse fluxo. O identificador da conta vem do JWT. Nas rotas que também aceitam `usuario_id`, omita esse campo ou envie o ID da própria conta. Contas Firebase alteram e-mail e senha pelo provedor de identidade. A operação de exclusão por senha da API é destinada às contas criadas diretamente nela.

## Conta e sessão

| Método | Rota | Acesso | Entrada e resposta de sucesso |
|---|---|---|---|
| GET | `/` | Público | `200` com `projeto`, `status` e `mensagem` |
| POST | `/api/usuarios` | Público | `nome`, `email`, `senha`. Retorna `201` com `usuario` |
| POST | `/api/auth/login` | Público | `email`, `senha`. Retorna `200` com JWT e `usuario` |
| GET | `/api/auth/me` | JWT | `200` com `usuario`, incluindo `plano` |
| POST | `/api/auth/logout` | JWT | Revoga o JWT da requisição e retorna `200` com `mensagem` |
| GET | `/api/usuarios` | JWT | `200` com `usuarios`, uma lista que contém a própria conta |
| PUT | `/api/usuarios/{id}` | JWT | Altera `nome`, `email` ou `senha`. Exige `senha_atual` para alterar e-mail ou senha. Retorna `200` com `usuario` |
| DELETE | `/api/usuarios/{id}` | JWT | Exige `senha_atual` no JSON. Exclui a própria conta e seus registros associados. Retorna `200` com `mensagem` |
| POST | `/api/auth/recuperar-senha` | Público | `email`. Retorna `200` com `mensagem` genérica quando a configuração está disponível |
| POST | `/api/auth/redefinir-senha` | Público | `token` do link e `nova_senha`. Retorna `200` com `mensagem` |

O link enviado por e-mail contém o token de recuperação. O token expira após 20 minutos e vale para um uso. A solicitação evita novos envios para a mesma conta durante os 10 minutos seguintes ao registro de um token recente. A resposta genérica preserva a privacidade da conta e por si só não confirma entrega. A operação exige SMTP e `PASSWORD_RESET_URL` com HTTPS. O novo login usa a senha redefinida.

## Planos Free e Premium

| Método | Rota | Entrada e resposta de sucesso |
|---|---|---|
| GET | `/api/assinatura` | `200` com `plano`, `premium_desde`, `limite_materias` e `recursos_premium` |
| POST | `/api/assinatura/upgrade` | Sem corpo obrigatório. Ativa Premium e devolve `200` com `mensagem` e `usuario` |
| POST | `/api/assinatura/cancelar` | Sem corpo obrigatório. Volta ao Free e devolve `200` com `mensagem` e `usuario` |

As três rotas exigem JWT. O Free permite cadastrar até cinco matérias. O Premium libera novas matérias sem esse limite, locais e chegada por GPS, QR Codes, configuração de horário de estudo e antecedência personalizada de avisos. `limite_materias` vem como `null` para Premium. Use `plano` para determinar o acesso. O contrato mobile também conserva a seleção `pro` da tela de planos.

O upgrade e o cancelamento simulam a troca do plano para a disciplina, sem movimentação financeira. O cancelamento mantém os registros existentes. A API restringe o acesso aos recursos Premium por rota e pode retornar `402` com `erro`, `plano_atual` e `plano_necessario`.

## Matérias e horários

| Método | Rota | Entrada e resposta de sucesso |
|---|---|---|
| GET | `/api/materias` | `200` com `materias`, incluindo `horarios_aula` por matéria |
| POST | `/api/materias` | `nome` e `cor` obrigatórios. `professor` e `horarios` opcionais. Retorna `201` com `materia` |
| PUT | `/api/materias/{id}` | Atualiza `nome`, `professor` ou `cor`. Retorna `200` com `materia` |
| DELETE | `/api/materias/{id}` | Remove a matéria, seus horários, tarefas, provas e QR Codes associados. Retorna `200` com `mensagem` |
| POST | `/api/materias/{id}/horarios` | `dia_semana`, `hora_inicio`, `hora_fim`. Retorna `201` com `horario` |
| PUT | `/api/horarios/{id}` | Atualiza um ou mais campos do horário. Retorna `200` com `horario` |
| DELETE | `/api/horarios/{id}` | `200` com `mensagem` |

`dia_semana` segue o padrão ISO. Segunda-feira é `1` e domingo é `7`. Use `HH:MM` ou `HH:MM:SS`. O fim precisa ser posterior ao início. Exemplo de criação de matéria com horário.

```json
{
  "nome": "Mobile II",
  "professor": "Prof. Exemplo",
  "cor": "#4C6EF5",
  "horarios": [{"dia_semana": 1, "hora_inicio": "19:00", "hora_fim": "22:00"}]
}
```

## Tarefas, provas e agenda

Envie `data_entrega` e `data_hora` no formato ISO local, por exemplo `2026-11-20T19:30:00`, sem sufixo de fuso. Use o fuso configurado pelo estudante. O padrão da API é `America/Sao_Paulo`.

| Método | Rota | Entrada e resposta de sucesso |
|---|---|---|
| GET | `/api/tarefas` | `200` com `tarefas`, ordenadas pelo prazo. Aceita `materia_id`, `status` e `vencidas=true` |
| POST | `/api/tarefas` | `materia_id`, `titulo`, `data_entrega`. `descricao` e `status` são opcionais. Retorna `201` com `tarefa` |
| PUT | `/api/tarefas/{id}` | Atualiza `materia_id`, `titulo`, `descricao`, `data_entrega` ou `status`. Retorna `200` com `tarefa` |
| DELETE | `/api/tarefas/{id}` | `200` com `mensagem` |
| GET | `/api/exames` | `200` com `exames`, ordenados por data. Aceita `materia_id` e `proximos=true` |
| POST | `/api/exames` | `materia_id` e `data_hora`. `descricao` é opcional. Retorna `201` com `exame` |
| PUT | `/api/exames/{id}` | Atualiza `materia_id`, `descricao` ou `data_hora`. Retorna `200` com `exame` |
| DELETE | `/api/exames/{id}` | `200` com `mensagem` |
| GET | `/api/calendario` | Exige `inicio` e `fim` em `AAAA-MM-DD`, num intervalo de até 93 dias inclusivos. Retorna `200` com o período, `eventos` e `aulas_semanais` |
| GET | `/api/progresso` | `200` com `total`, `concluidas`, `pendentes`, `vencidas`, `percentual` e `por_materia` |
| GET | `/api/compromissos-hoje` | `200` com `data` e `compromissos`, que reúne `tarefas`, `exames` e `aulas` do dia |

Use `pendente` ou `concluida` para `status`. Omitir `status` na criação usa o padrão do banco, `pendente`. O filtro `vencidas=true` busca tarefas pendentes cujo prazo passou. No progresso, `vencidas` é um subconjunto de `pendentes`, e `percentual` é a proporção de tarefas concluídas.

```json
{"materia_id":3,"titulo":"Entregar relatório","data_entrega":"2026-11-20T19:00:00"}
```

```json
{"materia_id":3,"descricao":"Prova 1","data_hora":"2026-11-24T19:30:00"}
```

`eventos` contém tarefas e provas com data concreta, ordenadas pelo horário. Cada item inclui `tipo`, `id`, `materia_id`, `materia_nome`, `cor`, `titulo`, `descricao` e `data_hora`. Tarefas também incluem `status`. Os horários recorrentes vêm em `aulas_semanais` com o dia da semana e as horas. O Flutter distribui essas aulas no calendário. Para uma edição offline de horário, obtenha `atualizado_em` pela criação ou edição do horário ou pela listagem de matérias.

## Preferências, locais e GPS

| Método | Rota | Entrada e resposta de sucesso |
|---|---|---|
| GET | `/api/preferencias` | `200` com `preferencias`, combinando valores salvos e padrão |
| PUT | `/api/preferencias` | Aceita atualização parcial. Retorna `200` com `preferencias` |
| GET | `/api/locais` | Premium. Retorna `200` com `locais` |
| POST | `/api/locais` | Premium. Exige `tipo`, `latitude` e `longitude`. `raio_metros` é opcional. Retorna `201` com `local` |
| PUT | `/api/locais/{id}` | Premium. Atualiza um ou mais campos do local. Retorna `200` com `local` |
| DELETE | `/api/locais/{id}` | Premium. Retorna `200` com `mensagem` |
| POST | `/api/gps/chegada` | Premium. Recebe `local_id`, `latitude` e `longitude`. Retorna `200` com `proximo` e `distancia_metros`. Inclui `data` e `compromissos` quando estiver no raio |

| Preferência | Tipo e valor padrão |
|---|---|
| `notif_tarefas`, `notif_exames`, `notif_lembrete_estudo`, `gps_ativo` | Booleanos, `true` por padrão |
| `antecedencia_tarefas_minutos`, `antecedencia_exames_minutos` | Inteiros de 0 a 43.200. O padrão é 1.440 minutos. A alteração exige Premium |
| `hora_lembrete_estudo` | `HH:MM`, `HH:MM:SS` ou `null`. O padrão é `null`. A alteração exige Premium |
| `fuso_horario` | Nome IANA, como `America/Sao_Paulo`, que é o padrão |

```json
{"tipo":"instituicao","latitude":-29.69,"longitude":-53.80,"raio_metros":200}
```

`tipo` aceita `casa` ou `instituicao`. A latitude vai de −90 a 90, a longitude de −180 a 180 e o raio de 25 a 2.000 metros. Para verificar a chegada, o celular coleta a localização com a permissão do sistema e envia os campos abaixo. A API calcula a distância e retorna `403` se `gps_ativo` estiver desativado. A rota de chegada usa as coordenadas enviadas para o cálculo, sem gravá-las como localização atual.

```json
{"local_id":5,"latitude":-29.691,"longitude":-53.801}
```

## QR Codes

| Método | Rota | Entrada e resposta de sucesso |
|---|---|---|
| GET | `/api/qrcodes` | `200` com `codigos` da própria conta |
| POST | `/api/qrcodes` | `materia_id`, `tipo`, `titulo` e `url` ou `referencia_id`. Retorna `201` com `codigo` |
| GET | `/api/qrcodes/{codigo}` | Resolve o texto lido e retorna `200` com `codigo` |
| POST | `/api/qrcodes/{codigo}/registrar` | Registra a leitura e retorna `201` com `leitura` e `codigo` |
| DELETE | `/api/qrcodes/{id}` | Exclui pelo ID numérico e retorna `200` com `mensagem` |

Todas as rotas exigem Premium. Para `tipo: "material"`, informe uma URL HTTPS sem credenciais embutidas. Para `tipo: "tarefa"` ou `tipo: "exame"`, informe o `referencia_id` de uma tarefa ou prova da mesma matéria. O `titulo` tem limite de 150 caracteres. O Flutter lê o código pela câmera e envia a string `codigo` retornada no objeto da API.

```json
{"materia_id":3,"tipo":"material","titulo":"Apostila","url":"https://example.com/apostila.pdf"}
```

## Notificações e agendamento

O JWT autentica chamadas da API. O token FCM identifica a instalação do Flutter para entrega de notificações pelo Firebase. Registre o token FCM depois do login e desvincule a instalação antes de revogar o JWT no logout.

| Método | Rota | Acesso | Entrada e resposta de sucesso |
|---|---|---|---|
| POST | `/api/dispositivos` | JWT | `fcm_token` no corpo. Registra ou atualiza o vínculo. Retorna `201` com `dispositivo` |
| DELETE | `/api/dispositivos` | JWT | `fcm_token` na query string, codificado para URL. Retorna `200` com `mensagem` |
| GET | `/api/notificacoes/status` | JWT | `200` com `firebase: "ok"` e `project_id` quando as credenciais são reconhecidas |
| POST | `/api/notificacoes/enviar` | JWT | `titulo` e `corpo`, com objeto `dados` opcional. Testa os aparelhos da conta e devolve `enviadas` e `falhas` |
| POST | `/api/interno/processar-lembretes` | `X-Cron-Secret` | Rota do agendador. Retorna `200` com `candidatos`, `enviados`, `falhas` e `ignorados` |

O teste manual retorna `200` quando o Firebase aceita ao menos um envio, `404` se a conta não tiver aparelhos cadastrados e `502` se nenhum envio for aceito ou a chamada ao Firebase falhar. A consulta de configuração verifica as credenciais do servidor. A entrega no aparelho também depende do token, do aplicativo e das permissões.

O agendamento requer uma chamada do Supabase Cron à rota interna a cada 15 minutos. O Flask considera as preferências, seleciona lembretes de tarefas pendentes, provas e estudo e usa uma reserva no banco para evitar reenvio de lembretes já marcados como enviados. `X-Cron-Secret` fica na integração do servidor. O Flutter usa o JWT para autenticação e o SDK Firebase para obter o token da instalação. As variáveis do servidor constam na seção de publicação. [Configuração de produção](README.md#4-deploy)

## Sincronização offline

As escritas de matérias, horários, tarefas, provas e locais aceitam cabeçalhos opcionais para sincronizar a fila mantida pelo aplicativo. A API deriva o usuário do JWT e aplica as regras do plano antes de gravar.

1. Para um cadastro, gere um UUID e guarde-o na fila. Envie-o em `Idempotency-Key` no `POST`. Se a resposta se perder, reenvie a mesma chave com os mesmos dados. A primeira gravação retorna `201`. Um reenvio reconhecido retorna `200` com o registro existente. Uma chave reaproveitada com outros dados retorna `409`. Se o registro desse cadastro já foi excluído, o reenvio retorna `410`.
2. Após sincronizar, guarde o `id` e o `atualizado_em` recebidos. Envie primeiro as matérias, pois horários, tarefas e provas precisam do `materia_id` do servidor.
3. Para editar ou excluir, envie o `atualizado_em` original em `X-Registro-Versao`. `409` indica conflito de versão. Busque o estado atual antes de decidir se reaplica a alteração. Em um reenvio de exclusão, `404` também pode indicar que o registro já não está disponível para a conta.

O cadastro de matéria no Free compara o limite antes de analisar a chave. Um reenvio pode receber `402` se a conta já tiver atingido cinco matérias. Esse caso exige consultar a listagem antes de concluir se o cadastro foi gravado.

```http
POST /api/tarefas
Authorization: Bearer JWT_RECEBIDO_NO_LOGIN
Content-Type: application/json
Idempotency-Key: 121b24d6-6e43-466d-840d-0646b7f9b564

{"materia_id":3,"titulo":"Revisar aula","data_entrega":"2026-11-20T19:00:00"}
```

```http
PUT /api/tarefas/18
Authorization: Bearer JWT_RECEBIDO_NO_LOGIN
Content-Type: application/json
X-Registro-Versao: 2026-11-17T14:22:07.123456

{"status":"concluida"}
```

## Respostas e erros

As rotas de recursos costumam retornar `{"erro":"descrição"}`. Os diagnósticos do Firebase e as falhas HTTP da infraestrutura podem ter outro formato. Trate o status HTTP antes de ler os campos da resposta.

| HTTP | Aplicação |
|---|---|
| `200` | Consulta, edição, exclusão, ação concluída ou cadastro offline já processado |
| `201` | Cadastro ou registro criado |
| `400` | Corpo, campos, período, cabeçalho ou token de redefinição inválidos |
| `401` | Login inválido, sessão ausente, expirada ou encerrada, ou segredo interno incorreto |
| `402` | Recurso do Premium ou limite de cadastro de matérias do Free |
| `403` | Operação fora da própria conta, senha atual inválida ou GPS desativado |
| `404` | Registro indisponível para a conta, referência removida ou ausência de aparelhos registrados |
| `409` | Vínculo de conta pendente, e-mail duplicado, versão desatualizada ou chave de criação offline reutilizada com outro conteúdo |
| `410` | Registro de uma criação offline reconhecida já foi excluído |
| `422` | Registro legado inválido encontrado durante a importação mobile |
| `500` | Falha interna, incluindo alguns erros de banco ou de configuração |
| `502` | Falha de envio pelo Firebase |
| `503` | Serviço indisponível ou configuração de recuperação de senha ou agendamento incompleta |

O Flask responde às requisições `OPTIONS` para integração web. As listas podem estar vazias. Antes de enviar comandos por uma fila offline, confirme a sessão e guarde o estado confirmado pelo servidor. Os testes produtivos registrados e as pendências de entrega de e-mail e lembretes constam no relatório de testes local.
