# Aviso de Privacidade do StudyTrack

Versão 1.2 · Minuta de 19 de novembro de 2026

O StudyTrack ajuda você a organizar seus estudos. O responsável pelas decisões sobre o uso de dados pessoais é **[nome completo ou razão social do controlador]**. Para falar sobre privacidade ou exercer seus direitos, use **[canal oficial de privacidade]**.

## Dados usados no StudyTrack

| Dados | Como são usados |
|---|---|
| Nome, e-mail, identificador Firebase, identificador da conta no servidor, datas de cadastro e atualização, plano escolhido e método de pagamento simulado | Criar e administrar sua conta, identificar o perfil e guardar o plano demonstrativo escolhido. A seleção do plano nesta versão é gratuita. |
| Credenciais de acesso administradas pelo Firebase Authentication, dados do provedor de login, tokens de identidade e de sessão e registros de logout | Permitir o login por e-mail ou Google e proteger o acesso à aplicação. A API confere a identidade Firebase no servidor e emite uma sessão própria. Nas contas criadas diretamente na API por senha, o banco guarda o hash bcrypt. |
| Instituição, curso, semestre, meta acadêmica, meta semanal e foto de perfil opcional | Personalizar o perfil. A foto é uma miniatura compactada enviada à API e guardada com os dados do perfil no Supabase. |
| Matérias, descrições, nome de professor quando informado, horários de aula, tarefas, provas, sessões de estudo e preferências | Montar agenda e calendário, calcular progresso, acompanhar metas e guardar as alterações. |
| Coordenadas e raio dos locais que você salva como casa ou instituição | Permitir a consulta de proximidade. A API guarda os locais cadastrados e usa a coordenada pontual enviada na consulta para calcular a distância durante a requisição. |
| Códigos QR, títulos, endereços de materiais, referências a tarefas ou provas e histórico de leituras registradas | Localizar o conteúdo vinculado e, quando você registra uma leitura, guardar o código consultado, a conta e a data. Para consultar um QR Code, a API recebe o código já lido pelo aplicativo. |
| Identificador de notificações do dispositivo, preferências de avisos e registros de processamento | Vincular o dispositivo à conta, tentar entregar lembretes e controlar reenvios. O conteúdo enviado pode incluir nome de matéria, data de prazo e identificador do compromisso. |
| Nome, e-mail e informações de recuperação da conta | Quando o serviço de e-mail está configurado, enviar um link de redefinição a pedido do usuário. O banco guarda o hash do token e dados como validade e uso. |
| Identificador da operação de cadastro, resumo criptográfico do conteúdo e identificador do registro criado | Identificar um cadastro reenviado e evitar a criação de duplicatas na sincronização. |
| Histórico de avisos com título, mensagem, tipo, estado, data, leitura e cancelamento | Apresentar os avisos na conta e registrar suas interações com o histórico. |
| Identificador da conta, versões, textos e identificadores criptográficos dos documentos apresentados e data da confirmação | Registrar a aceitação dos Termos de Uso e a confirmação de leitura deste aviso. Uma nova confirmação é solicitada quando os documentos atuais ainda não têm registro para a conta. |

O cadastro por e-mail utiliza nome, e-mail e senha. O acesso Google fornece ao Firebase os dados de identificação autorizados para esse login. O perfil acadêmico e a foto são preenchidos por você. Permissões de câmera, localização e notificações são solicitadas nos fluxos correspondentes do dispositivo.

Na atualização da versão anterior, o servidor lê uma vez os dados da sua conta no Firestore e os importa para o Supabase. Isso inclui perfil, foto, plano, matérias, tarefas, provas, sessões de estudo e histórico de avisos. Uma importação interrompida pode ser retomada. Depois da conclusão registrada, a aplicação usa a API para consultar e alterar os dados no Supabase. Os dados de origem permanecem sujeitos ao plano de conservação da equipe. **[definir prazo e procedimento de remoção dos dados legados do Firestore após conferir a importação]**.

As preferências de idioma, aparência e acessibilidade ficam no dispositivo. Para reconhecer o reenvio de um cadastro cuja confirmação se perdeu, o aplicativo também guarda sua identificação e os campos usados nessa identificação até confirmar a operação ou até a limpeza dos dados do aplicativo. O mapa pode consultar serviços de mapas, busca de endereços e rotas que recebem as coordenadas ou os endereços usados nessa consulta. Os locais cadastrados na API ficam no servidor. Você pode solicitar sua remoção pelo canal de privacidade.

Nesta versão do aplicativo, os lembretes são agendados no Android e o leitor de QR usa a câmera do dispositivo para consultar ou abrir o conteúdo lido. As funções de localização, registro de QR e envio de notificações do servidor estão disponíveis para as integrações que as utilizem.

## Finalidades e bases legais

- Cadastro, autenticação, agenda, sincronização, gerenciamento do plano e recuperação de conta são tratados para prestar o serviço solicitado, conforme o art. 7º, V, da LGPD.
- O cumprimento de deveres legais e regulatórios, quando aplicável, segue o art. 7º, II, da LGPD. **[confirmar a base das operações adicionais de segurança e prevenção de abuso, se houver]**.
- A localização e os avisos são recursos opcionais. **[confirmar a base legal de cada recurso e descrever como a escolha é apresentada no aplicativo]**.

A leitura deste aviso informa sobre o tratamento de dados. Permissões e escolhas sobre funcionalidades opcionais são tratadas nos respectivos fluxos. [Lei Geral de Proteção de Dados](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)

## Prestadores de serviço e transferências

- **Vercel** hospeda a API e processa as solicitações enviadas ao servidor.
- **Supabase** armazena os dados da aplicação e pode operar o agendamento de lembretes.
- **Google Firebase Authentication** administra o acesso por e-mail e Google, a recuperação de senha e a verificação de identidade utilizada pelo servidor. **Google Cloud Firestore** fornece a leitura dos dados da versão anterior para a importação por conta. [Privacidade no Firebase](https://firebase.google.com/support/privacy)
- **Google Firebase Cloud Messaging** recebe o identificador do dispositivo e o conteúdo necessário para entregar notificações.
- **OpenStreetMap e serviços de mapas e rotas utilizados pelo aplicativo** processam as consultas feitas ao mapa, como endereços e coordenadas. **[confirmar a lista de operadores e as regiões utilizadas na implantação]**.
- **[provedor de e-mail, quando habilitado]** processa o endereço do destinatário e a mensagem com o link de recuperação de senha.

Links externos, como materiais abertos a partir de um QR Code, estão sujeitos às práticas do serviço de destino. Quando houver transferência internacional de dados pelos prestadores, a equipe informará os destinos e o mecanismo aplicável, de acordo com a LGPD e as regras da ANPD. **[confirmar países/regiões e eventual mecanismo de transferência]**. [Regras da ANPD para transferências internacionais](https://www.gov.br/anpd/pt-br/assuntos/assuntos-internacionais/transferencia-internacional-de-dados)

## Conservação, segurança e exclusão

Os dados da conta e da agenda ficam no banco ativo enquanto forem necessários ao funcionamento da conta ou até a exclusão dos registros. A sessão emitida pela API é válida por 60 minutos. O aplicativo renova essa sessão a partir da identidade Firebase. O acesso por e-mail do Flutter usa o fluxo de recuperação de senha do Firebase. As contas criadas diretamente na API também têm um fluxo de link de redefinição com validade de 20 minutos e uso único, quando o servidor de e-mail está configurado. Registros técnicos e cópias de segurança seguem prazos próprios. **[informar os prazos efetivos ou critérios de retenção dos registros técnicos e backups]**.

A API limita o acesso aos registros à conta autenticada. O logout solicita a revogação da sessão do servidor, limpa a sessão do aplicativo e encerra o login Firebase no dispositivo. Você pode solicitar a exclusão da conta pelo canal de privacidade. A equipe precisa conferir a identidade e remover os dados vinculados do Supabase, do Firebase Authentication e do Firestore legado, quando ainda presentes. A remoção de dados do dispositivo e de cópias de segurança segue os respectivos ciclos de armazenamento. Dados cuja conservação seja autorizada por lei são tratados conforme essa finalidade.

## Seus direitos

Você pode pedir confirmação do tratamento, acesso e correção de dados, bem como informações sobre o compartilhamento. Também pode solicitar, conforme o caso, portabilidade, anonimização, bloqueio ou eliminação de dados, ou exercer oposição ao tratamento nos casos previstos na LGPD. Quando o consentimento for a base utilizada, você pode obter informações sobre suas escolhas e revogá-lo.

Envie o pedido pelo canal de privacidade no início deste aviso. Para proteger a conta, podemos solicitar confirmação de identidade. Você também pode apresentar petição à ANPD nas condições previstas pela autoridade. [Direitos dos titulares na ANPD](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados/direito-dos-titulares) · [Canal de petição à ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/cidadao-titular-de-dados/denuncia-peticao-de-titular-referente-lgpd)

## Atualizações

O StudyTrack disponibilizará no aplicativo a versão vigente deste aviso e comunicará mudanças relevantes no tratamento dos dados.
