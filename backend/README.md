# studyTrack — Backend (Python + Flask + Vercel + Supabase)

API do StudyTrack para autenticação, agenda acadêmica, progresso, locais, QR Codes e lembretes.

## Documentação do StudyTrack

- [Termos de uso](TERMOS_DE_USO.md) e [Aviso de privacidade](AVISO_DE_PRIVACIDADE.md)
- [Documentação da API](DOCUMENTACAO_API.md)

### Integração do Flutter

O aplicativo usa Firebase Authentication para entrar com e-mail e Google. Antes de abrir o painel, troca o ID token por uma sessão da API e importa os registros antigos do Firestore para o Supabase. Os acessos seguintes aos dados acadêmicos, ao perfil, à foto e ao histórico de avisos passam pelas rotas `/api/mobile`.

Para instalar esta versão, aplique `migrations/008_integracao_firebase_mobile.sql` depois de `007_monetizacao.sql`, antes do deploy. Configure na Vercel `FIREBASE_PROJECT_ID` com o mesmo `projectId` do Flutter e `FIREBASE_CREDENTIALS` com uma conta de serviço desse projeto, autorizada a validar contas no Firebase Authentication e ler os dados legados no Cloud Firestore. A credencial permanece no ambiente do servidor.

A importação usa a identidade confirmada pelo Firebase. Ela avança em lotes e pode continuar após interrupções. Os documentos de origem permanecem no Firestore. Se já houver uma conta da API com o mesmo e-mail, o app solicita a senha dessa conta para confirmar o vínculo. Ao conectar uma conta antiga, verifique no painel se os registros e seus vínculos foram importados.

O app mantém os lembretes locais Android e os serviços de mapas. A tela de cadastro aguarda a conexão com a API após criar a identidade no Firebase. Para gerar a nova versão do app, execute `flutter pub get` e compile o projeto Flutter. O Gradle 8.14 do projeto é compatível com o Java 21 usado na validação.

### Publicação dos termos e do aviso

Complete os campos entre colchetes com a identidade e o contato oficial do responsável, as bases dos recursos opcionais, o provedor de e-mail, os dados sobre transferências internacionais e os prazos de conservação. Confira no Flutter como permissões, câmera e armazenamento local são usados. Se o público incluir menores de idade, valide o fluxo e o aviso de acordo com o melhor interesse desse público. [Orientação da ANPD](https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes)

O cadastro do Flutter apresenta links que abrem os dois documentos dentro do app e uma caixa inicialmente desmarcada com “Li e aceito os Termos de Uso e declaro que li o Aviso de Privacidade”. A caixa é obrigatória antes de criar a identidade por e-mail. O acesso com Google pede essa confirmação antes de continuar com o provedor. Contas antigas sem aceite recebem a solicitação ao entrar. A API exige o aceite atual antes de criar a conta do aplicativo ou emitir sua sessão; o banco registra versões, hashes, textos apresentados e data do servidor, junto com a vinculação da conta.

**Instalação:** execute `migrations/009_aceite_documentos.sql` após a `008`, publique a API e atualize o Flutter. O endpoint público `GET /api/legal/documentos` fornece os textos que o app apresenta. Depois de editar os arquivos de termos ou privacidade, atualize a versão e execute `python scripts/gerar_documentos_legais.py`; inclua o arquivo gerado `api/documentos_legais.py` na publicação. Ele garante que os textos estejam no pacote Python do servidor. Uma mudança de texto também altera o hash e exige nova confirmação. Permissões opcionais de GPS e notificações continuam nos fluxos correspondentes.

## Estrutura

```
studytrack-backend/
├── api/
│   ├── index.py
│   ├── recursos.py
│   ├── firebase_identity.py
│   ├── mobile.py
│   └── sincronizacao.py
├── migrations/
├── public/
│   ├── notificacoes.html
│   └── styles.css
├── requirements.txt
└── README.md
```

A Vercel detecta o Flask automaticamente pela dependência no `requirements.txt`
e pelo arquivo `api/index.py` (que expõe uma variável de nível superior
chamada `app`). Não precisa de `vercel.json` nem de rotas manuais — o Flask
cuida do roteamento (`@app.route(...)`) e a Vercel manda toda requisição pra
esse app único.

## 1. Configurar o Supabase

1. Use o esquema do StudyTrack já configurado no Supabase, com as migrações `001`, `002` e `004` aplicadas.
2. Aplique [005_recuperar_lembretes.sql](migrations/005_recuperar_lembretes.sql) e
   [006_escritas_offline.sql](migrations/006_escritas_offline.sql) no SQL Editor, nessa ordem, antes de publicar a API.
3. Aplique `007_monetizacao.sql` depois da `006`. A API atual consulta as colunas de plano criadas por essa migração.
4. Aplique `008_integracao_firebase_mobile.sql` para receber as identidades e os dados do Flutter.
5. Aplique `009_aceite_documentos.sql` para registrar o aceite dos documentos no cadastro e login do aplicativo.
6. Configure a URL do projeto e a chave `service_role` apenas no ambiente da API.

## 2. Rodar localmente

```bash
cd studytrack-backend
npm i -g vercel        # se ainda não tiver a CLI da Vercel

python -m venv .venv
source .venv/bin/activate    # no Windows: .venv\Scripts\activate
pip install -r requirements.txt

vercel link             # conecta essa pasta a um projeto Vercel
vercel env pull         # baixa as env vars configuradas no painel para .env.local
```

Se preferir configurar na mão, crie um `.env.local`:
```
SUPABASE_URL=https://SEU-PROJETO.supabase.co
SUPABASE_KEY=sua-chave
JWT_SECRET=segredo-aleatorio-com-pelo-menos-32-bytes
```

Depois:
```bash
vercel dev
```

O endpoint sobe em algo como `http://localhost:3000/api/usuarios`. Use sempre
`vercel dev` (não o servidor embutido do Flask) — ele roda seu app do mesmo
jeito que a produção, com o mesmo entrypoint WSGI.

## 3. Testar

Para criar uma conta de teste, use `POST /api/usuarios`.

```bash
curl -X POST http://localhost:3000/api/usuarios \
  -H "Content-Type: application/json" \
  -d '{"nome": "Estudante Teste", "email": "estudante@example.com", "senha": "SenhaDeTeste123!"}'
```

Envie `email` e `senha` a `POST /api/auth/login`. Use o `token` retornado nas rotas protegidas.

```bash
curl http://localhost:3000/api/auth/me -H "Authorization: Bearer SEU_TOKEN"
```

## 4. Deploy

```bash
vercel
```

No painel da Vercel, configure as variáveis da API em **Settings > Environment Variables**.

- Para autenticação e banco, configure `JWT_SECRET`, `SUPABASE_URL` e `SUPABASE_KEY`.
- Para lembretes, configure `FIREBASE_CREDENTIALS` e `CRON_SECRET`. Use um segredo aleatório de pelo menos 32 caracteres.
- Para recuperar senha, configure `SMTP_HOST`, `SMTP_FROM` e `PASSWORD_RESET_URL` com o endereço HTTPS da tela de redefinição. Se o servidor pedir autenticação, configure `SMTP_USER` e `SMTP_PASSWORD`. A porta padrão é `587` com STARTTLS e pode ser definida em `SMTP_PORT`.

Publique com `vercel --prod`. No Supabase Cron, agende uma requisição HTTP `POST` a
`/api/interno/processar-lembretes` na URL publicada, com `*/15 * * * *` e o cabeçalho
`X-Cron-Secret` correspondente ao segredo da Vercel. Confira uma entrega de teste no celular.
O processamento reconsidera lembretes por até uma hora de atraso e permite retomar reservas interrompidas após 10 minutos.
Lembretes de tarefa ou prova são processados até o horário do compromisso.

## 5. Enviar alterações do SQLite

O Flutter pode usar as rotas existentes de matérias, horários, tarefas, exames e locais com estes cabeçalhos opcionais.

- No `POST`, gere e guarde um UUID por cadastro em `Idempotency-Key`. Reenvie a mesma chave e o mesmo conteúdo após uma falha. `201` indica criação e `200` devolve o registro já criado. `409` indica conflito e `410` indica que o registro criado já foi excluído.
- No `PUT` e no `DELETE`, envie em `X-Registro-Versao` o valor de `atualizado_em` recebido na última leitura ou escrita. Em `409`, leia a versão atual e resolva o conflito antes de tentar de novo. Em um reenvio de `DELETE`, `404` confirma que o registro já não está acessível à conta. A versão é por registro. Excluir uma matéria remove seus horários, tarefas, provas e códigos QR associados.
- Depois de uma criação ou edição confirmada, guarde o `id` do servidor como `server_id` e o `atualizado_em` retornado. Sincronize matérias antes dos horários, tarefas e provas vinculados a elas.
