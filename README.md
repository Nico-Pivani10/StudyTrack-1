# StudyTrack

Esta versão mantém o login por e-mail e Google no Firebase Authentication e envia os dados do aplicativo à API Flask. Perfil, foto, matérias, tarefas, provas, sessões de estudo, plano e histórico de avisos são persistidos no Supabase. A interface usa português brasileiro e espanhol.

## Executar a versão integrada

Antes de iniciar o Flutter, publique a API com `008_integracao_firebase_mobile.sql` aplicada após as migrações anteriores e depois `009_aceite_documentos.sql`. Na Vercel, configure `FIREBASE_PROJECT_ID` com o projeto usado pelo aplicativo e `FIREBASE_CREDENTIALS` com uma conta de serviço do mesmo projeto que consiga verificar usuários e ler os dados legados do Firestore. O responsável pela API configura também `SUPABASE_URL`, `SUPABASE_KEY` com acesso de backend e `JWT_SECRET`.

No projeto Flutter, conserve a configuração Firebase cliente e habilite os provedores de login usados pela equipe. Execute os comandos a partir desta pasta.

```powershell
flutter pub get
flutter run --dart-define=STUDYTRACK_API_URL=https://studytrackk.vercel.app
```

`STUDYTRACK_API_URL` deve apontar para a API publicada com a integração. O endereço acima é o valor padrão do código. Em desenvolvimento local, a configuração permite HTTP para `localhost`, `127.0.0.1` e `10.0.2.2`. Para o emulador Android, `10.0.2.2` acessa o computador hospedeiro.

A compilação Android foi validada com Java 21. Se o Flutter selecionar outro Java incompatível com o Gradle do projeto, selecione um JDK 21 antes de compilar. No Windows, se `flutter pub get` solicitar suporte a links simbólicos para os plugins, ative o Modo de Desenvolvedor nas configurações do Windows e execute o comando novamente.

## Login e importação dos dados

O login Firebase entrega um ID token ao cliente. `ApiClient.connect()` troca esse token por um JWT em `/api/auth/firebase`, chama `/api/mobile/importar` e carrega `/api/mobile/estado` antes de abrir o dashboard. A API confere a identidade no servidor e vincula o UID Firebase à conta SQL. Se já existir uma conta independente da API com o mesmo e-mail, o servidor pede confirmação do vínculo por meio do erro `409 conta_nao_vinculada`.

Nesse caso, o login exibe um diálogo para informar a senha da conta anterior da API. `connectApi()` confirma a conta anterior e a identidade Firebase pela rota `/api/auth/firebase/vincular`, depois repete a conexão e a importação. Cancelar o diálogo mantém a pessoa na tela de acesso. Se uma conta Firebase tiver sido criada e a conexão com a API falhar, o cadastro oferece voltar ao login para retomar a conexão.

A importação consulta o documento `usuarios/{uid}` e as coleções próprias no Firestore pelo servidor. Os identificadores dos documentos são preservados no contrato mobile. A API retoma uma importação interrompida, preserva registros já importados ou alterados e, após concluir, grava a data de conclusão. Os próximos acessos usam os registros do Supabase. O aplicativo atualizado faz suas leituras e escritas acadêmicas pela API.

O JWT da API fica em memória e o cliente renova a sessão a partir da identidade Firebase quando necessário. As telas recebem o estado confirmado pelo servidor após uma alteração e consultam atualizações a cada 30 segundos enquanto houver assinantes. Essa integração depende de conexão para confirmar uma gravação. Os lembretes locais já agendados continuam sob controle do dispositivo.

## Arquivos da integração

| Arquivo | Responsabilidade |
|---|---|
| `lib/services/api_client.dart` | Autenticação da API, importação inicial, estado da conta, renovação e logout |
| `lib/services/api_login.dart` | Conexão antes da navegação e confirmação do vínculo com uma conta anterior |
| `lib/services/app_data.dart` | Registros, coleções e conversão de datas e foto para o contrato HTTP |
| `lib/services/studytrack_repository.dart` | Operações de matérias, tarefas, provas, sessões e perfil |
| `lib/services/notification_history.dart` | Histórico de avisos e marcação de leitura pela API |
| `lib/screens/login_screen.dart` e `register_screen.dart` | Login Firebase e conexão com a API antes da navegação |

## Aceite dos documentos

O cadastro apresenta links para leitura dos Termos de Uso e do Aviso de Privacidade dentro do app. A caixa de confirmação começa desmarcada e o botão de criar conta fica desabilitado até a seleção. O envio pelo teclado também verifica a confirmação. Abrir um documento preserva os campos preenchidos.

O acesso com Google apresenta a mesma confirmação antes de abrir o provedor. Contas existentes que ainda não têm os documentos atuais registrados recebem a solicitação antes do dashboard. Cancelar interrompe a entrada. A interface do fluxo usa português e espanhol; os textos legais publicados atualmente estão em português.

Os textos e suas versões vêm de `GET /api/legal/documentos`. `LegalConsentField`, em `lib/widgets/legal_consent.dart`, devolve uma confirmação com as versões e hashes efetivamente apresentados. O cliente envia esse campo em `/api/auth/firebase` e, quando necessário, `/api/auth/firebase/vincular`. Respostas `428 aceite_necessario` ou `409 documentos_atualizados` pedem nova leitura. Se não conseguir carregar os textos, a tela permite tentar novamente e mantém a criação bloqueada.

Antes de publicar esta versão, execute `009_aceite_documentos.sql` após `008` no Supabase e publique a API atualizada. O servidor armazena versões, hashes, textos e data da confirmação. Os documentos ainda contêm campos da minuta a preencher pela equipe antes da publicação definitiva.

---

## Requisitos funcionales

### Registro e inicio de sesión

* El usuario podrá crear una cuenta.
* Podrá iniciar y cerrar sesión.
* Podrá recuperar su contraseña.

### Gestión de materias

* Crear, editar y eliminar materias.
* Asignar color, profesor y horario a cada materia.
* Visualizar todas las materias registradas.

### Gestión de tareas y trabajos

* Crear tareas.
* Definir fecha de entrega.
* Asociar una tarea a una materia.
* Marcar una tarea como completada.
* Editar o eliminar tareas.
* Mostrar tareas pendientes y vencidas.

### Gestión de exámenes

* Registrar exámenes.
* Indicar materia, fecha, hora y descripción.
* Mostrar próximos exámenes.
* Avisar cuando un examen esté próximo.

### Calendario

* Mostrar tareas, exámenes y clases en un calendario.
* Permitir consultar actividades por día.
* Diferenciar eventos por tipo.

### Progreso académico

* Mostrar cantidad de tareas realizadas.
* Mostrar tareas pendientes.
* Mostrar porcentaje de cumplimiento.
* Permitir consultar estadísticas por materia.

### Notificaciones

* Recordar tareas próximas a vencer.
* Recordar exámenes.
* Enviar recordatorios de estudio.
* Permitir activar o desactivar notificaciones.

### GPS

* Solicitar permiso de ubicación.
* Detectar cuándo el estudiante se encuentra cerca de la institución.
* Mostrar los compromisos del día al llegar.
* Permitir desactivar el uso de ubicación.

### Cámara y códigos QR

* Solicitar permiso para utilizar la cámara.
* Escanear códigos QR.
* Abrir material asociado a un código.
* Registrar información de una actividad o evaluación.

### Funcionamiento en segundo plano

* Verificar fechas y horarios aunque la aplicación no esté abierta.
* Generar notificaciones programadas.

### Perfil

* Modificar nombre y datos básicos.
* Configurar preferencias.
* Administrar permisos.

### Privacidad

* Informar qué datos utiliza la aplicación.
* Permitir gestionar permisos de cámara, GPS y notificaciones.
* Permitir cerrar sesión.
* Podrías incluir también eliminación de cuenta.

---

## NO FUNCIONAL

* La aplicación debe ser desarrollada en Flutter.
* Debe funcionar en dispositivos Android.
* La interfaz debe ser responsiva y adaptarse a diferentes tamaños de pantalla.
* Debe utilizar una navegación sencilla e intuitiva.
* Los datos del usuario deben almacenarse de forma segura.
* La aplicación debe solicitar permisos únicamente cuando sean necesarios.
* La información principal debe cargar rápidamente.
* Debe manejar errores sin cerrarse inesperadamente.
* Debe utilizar botones y textos legibles.
* Debe tener buen contraste entre texto y fondo.
* La aplicación debe mantener los datos aunque el usuario cierre la app.
* Las contraseñas no deben guardarse en texto plano si utilizan autenticación real.
