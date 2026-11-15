// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'StudyTrack';

  @override
  String get appSlogan => 'Seu companheiro de estudos';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonError => 'Erro';

  @override
  String get commonSuccess => 'Operação realizada com sucesso';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonAdd => 'Adicionar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get authLogin => 'Entrar';

  @override
  String get authRegister => 'Criar conta';

  @override
  String get authLogout => 'Sair';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Senha';

  @override
  String get authConfirmPassword => 'Confirmar senha';

  @override
  String get authFullName => 'Nome completo';

  @override
  String get authForgotPassword => 'Esqueceu sua senha?';

  @override
  String get authResetPassword => 'Redefinir senha';

  @override
  String get authSendReset => 'Enviar e-mail de recuperação';

  @override
  String get authSignInGoogle => 'Continuar com o Google';

  @override
  String get authNoAccount => 'Ainda não tem uma conta?';

  @override
  String get authHaveAccount => 'Já tem uma conta?';

  @override
  String get authVerifyEmail => 'Verificar e-mail';

  @override
  String get authEmailVerified => 'E-mail verificado';

  @override
  String get authEmailNotVerified => 'E-mail não verificado';

  @override
  String get authInvalidEmail => 'Informe um e-mail válido';

  @override
  String get authRequiredField => 'Este campo é obrigatório';

  @override
  String get authLoginFailed => 'Não foi possível entrar na sua conta';

  @override
  String get authRegisterSuccess => 'Conta criada com sucesso';

  @override
  String get navHome => 'Início';

  @override
  String get navSubjects => 'Disciplinas';

  @override
  String get navTasks => 'Tarefas';

  @override
  String get navCalendar => 'Calendário';

  @override
  String get navProfile => 'Perfil';

  @override
  String dashboardWelcome(String name) {
    return 'Olá, $name!';
  }

  @override
  String get dashboardSubtitle =>
      'Organize seu dia de estudos e alcance suas metas.';

  @override
  String get dashboardQuickAccess => 'Acessos rápidos';

  @override
  String get dashboardAcademicSummary => 'Resumo acadêmico';

  @override
  String get dashboardTaskProgress => 'Progresso das tarefas';

  @override
  String get dashboardUpcomingActivities => 'Próximas atividades';

  @override
  String get dashboardWeeklyGoal => 'Meta semanal';

  @override
  String get dashboardDaysStudied => 'Dias de estudo';

  @override
  String get dashboardStudyMinutes => 'Tempo de estudo registrado';

  @override
  String get dashboardNoTasks => 'Ainda não há tarefas cadastradas.';

  @override
  String get dashboardNoEvents => 'Não há próximas atividades.';

  @override
  String get dashboardViewAll => 'Ver todas';

  @override
  String get dashboardViewCalendar => 'Ver calendário';

  @override
  String get subjectsTitle => 'Minhas disciplinas';

  @override
  String get subjectsOrganize => 'Organize suas disciplinas';

  @override
  String get subjectsAdd => 'Adicionar disciplina';

  @override
  String get subjectsEdit => 'Editar disciplina';

  @override
  String get subjectsDelete => 'Excluir disciplina';

  @override
  String get subjectsName => 'Nome da disciplina';

  @override
  String get subjectsTeacher => 'Professor(a)';

  @override
  String get subjectsDescription => 'Descrição';

  @override
  String get subjectsNone => 'Você ainda não tem disciplinas cadastradas.';

  @override
  String get subjectsNoTasks => 'Nenhuma tarefa cadastrada';

  @override
  String get subjectsSaveSuccess => 'Disciplina salva com sucesso.';

  @override
  String get subjectsDeleteSuccess => 'Disciplina excluída.';

  @override
  String get subjectsCannotDelete =>
      'Esta disciplina tem tarefas ou provas vinculadas.';

  @override
  String get tasksTitle => 'Minhas tarefas';

  @override
  String get tasksCompleted => 'Concluídas';

  @override
  String get tasksPending => 'Pendentes';

  @override
  String get calendarTitle => 'Calendário acadêmico';

  @override
  String get calendarSubtitle => 'Consulte suas tarefas e provas por data.';

  @override
  String get calendarMonth => 'Mês';

  @override
  String get calendarWeek => 'Semana';

  @override
  String get calendarToday => 'Hoje';

  @override
  String get calendarAddExam => 'Cadastrar prova';

  @override
  String get calendarNewExam => 'Nova prova';

  @override
  String get calendarEditExam => 'Editar prova';

  @override
  String get calendarDeleteExam => 'Excluir prova';

  @override
  String get calendarExamName => 'Nome da prova';

  @override
  String get calendarSelectDate => 'Selecionar data';

  @override
  String get calendarSelectTime => 'Selecionar horário';

  @override
  String get calendarNoEvents => 'Não há atividades para este dia.';

  @override
  String get calendarNoUpcoming => 'Não há próximas atividades cadastradas.';

  @override
  String get calendarUpcoming => 'Próximas provas';

  @override
  String get calendarExamSaved => 'Prova salva com sucesso.';

  @override
  String get calendarExamDeleted => 'Prova excluída.';

  @override
  String get calendarNoSubjectAssigned => 'Sem disciplina vinculada';

  @override
  String get calendarTask => 'Tarefa';

  @override
  String get calendarExam => 'Prova';

  @override
  String get profileTitle => 'Meu perfil';

  @override
  String get profileEditName => 'Editar nome';

  @override
  String get profileAcademicData => 'Informações acadêmicas';

  @override
  String get profileInstitution => 'Instituição de ensino';

  @override
  String get profileDegree => 'Curso';

  @override
  String get profileSemester => 'Semestre';

  @override
  String get profileAcademicGoal => 'Meta acadêmica';

  @override
  String get profilePreferences => 'Preferências';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String get profileLanguageHint => 'Idioma do aplicativo';

  @override
  String get profileTheme => 'Tema do aplicativo';

  @override
  String get profileDarkMode => 'Modo escuro';

  @override
  String get profileLightMode => 'Modo claro';

  @override
  String get profileFontSize => 'Tamanho do texto';

  @override
  String get profileSaveSuccess => 'Perfil atualizado com sucesso.';

  @override
  String get quickQrScanner => 'Ler código QR';

  @override
  String get quickGps => 'GPS e mapa';

  @override
  String get quickNotifications => 'Notificações';

  @override
  String get modulesPending => 'Integração pendente';

  @override
  String get modulesResponsible => 'Responsável';

  @override
  String get modulesBackHome => 'Voltar ao início';

  @override
  String get modulesTasksTitle => 'Gerenciamento de tarefas';

  @override
  String get modulesGpsTitle => 'GPS e geolocalização';

  @override
  String get modulesNotificationsTitle => 'Notificações';

  @override
  String get modulesTasksDescription =>
      'Este módulo já foi desenvolvido e aguarda integração com o StudyTrack.';

  @override
  String get modulesGpsDescription =>
      'O módulo de localização e mapas já foi desenvolvido e aguarda integração com o StudyTrack.';

  @override
  String get modulesNotificationsDescription =>
      'A integração das notificações e dos lembretes ainda está pendente.';

  @override
  String get qrTitle => 'Leitor de códigos QR';

  @override
  String get qrCameraPermission => 'É necessário permitir o acesso à câmera.';

  @override
  String get errorsConnection => 'Verifique sua conexão com a internet.';

  @override
  String get errorsPermission =>
      'Você não tem permissão para realizar esta ação.';

  @override
  String get errorsCouldNotSave => 'Não foi possível salvar as informações.';

  @override
  String get errorsCouldNotDelete => 'Não foi possível excluir o registro.';

  @override
  String get errorsNotSignedIn => 'Entre na sua conta para continuar.';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'StudyTrack';

  @override
  String get appSlogan => 'Seu companheiro de estudos';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonError => 'Erro';

  @override
  String get commonSuccess => 'Operação realizada com sucesso';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonAdd => 'Adicionar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get authLogin => 'Entrar';

  @override
  String get authRegister => 'Criar conta';

  @override
  String get authLogout => 'Sair';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Senha';

  @override
  String get authConfirmPassword => 'Confirmar senha';

  @override
  String get authFullName => 'Nome completo';

  @override
  String get authForgotPassword => 'Esqueceu sua senha?';

  @override
  String get authResetPassword => 'Redefinir senha';

  @override
  String get authSendReset => 'Enviar e-mail de recuperação';

  @override
  String get authSignInGoogle => 'Continuar com o Google';

  @override
  String get authNoAccount => 'Ainda não tem uma conta?';

  @override
  String get authHaveAccount => 'Já tem uma conta?';

  @override
  String get authVerifyEmail => 'Verificar e-mail';

  @override
  String get authEmailVerified => 'E-mail verificado';

  @override
  String get authEmailNotVerified => 'E-mail não verificado';

  @override
  String get authInvalidEmail => 'Informe um e-mail válido';

  @override
  String get authRequiredField => 'Este campo é obrigatório';

  @override
  String get authLoginFailed => 'Não foi possível entrar na sua conta';

  @override
  String get authRegisterSuccess => 'Conta criada com sucesso';

  @override
  String get navHome => 'Início';

  @override
  String get navSubjects => 'Disciplinas';

  @override
  String get navTasks => 'Tarefas';

  @override
  String get navCalendar => 'Calendário';

  @override
  String get navProfile => 'Perfil';

  @override
  String dashboardWelcome(String name) {
    return 'Olá, $name!';
  }

  @override
  String get dashboardSubtitle =>
      'Organize seu dia de estudos e alcance suas metas.';

  @override
  String get dashboardQuickAccess => 'Acessos rápidos';

  @override
  String get dashboardAcademicSummary => 'Resumo acadêmico';

  @override
  String get dashboardTaskProgress => 'Progresso das tarefas';

  @override
  String get dashboardUpcomingActivities => 'Próximas atividades';

  @override
  String get dashboardWeeklyGoal => 'Meta semanal';

  @override
  String get dashboardDaysStudied => 'Dias de estudo';

  @override
  String get dashboardStudyMinutes => 'Tempo de estudo registrado';

  @override
  String get dashboardNoTasks => 'Ainda não há tarefas cadastradas.';

  @override
  String get dashboardNoEvents => 'Não há próximas atividades.';

  @override
  String get dashboardViewAll => 'Ver todas';

  @override
  String get dashboardViewCalendar => 'Ver calendário';

  @override
  String get subjectsTitle => 'Minhas disciplinas';

  @override
  String get subjectsOrganize => 'Organize suas disciplinas';

  @override
  String get subjectsAdd => 'Adicionar disciplina';

  @override
  String get subjectsEdit => 'Editar disciplina';

  @override
  String get subjectsDelete => 'Excluir disciplina';

  @override
  String get subjectsName => 'Nome da disciplina';

  @override
  String get subjectsTeacher => 'Professor(a)';

  @override
  String get subjectsDescription => 'Descrição';

  @override
  String get subjectsNone => 'Você ainda não tem disciplinas cadastradas.';

  @override
  String get subjectsNoTasks => 'Nenhuma tarefa cadastrada';

  @override
  String get subjectsSaveSuccess => 'Disciplina salva com sucesso.';

  @override
  String get subjectsDeleteSuccess => 'Disciplina excluída.';

  @override
  String get subjectsCannotDelete =>
      'Esta disciplina tem tarefas ou provas vinculadas.';

  @override
  String get tasksTitle => 'Minhas tarefas';

  @override
  String get tasksCompleted => 'Concluídas';

  @override
  String get tasksPending => 'Pendentes';

  @override
  String get calendarTitle => 'Calendário acadêmico';

  @override
  String get calendarSubtitle => 'Consulte suas tarefas e provas por data.';

  @override
  String get calendarMonth => 'Mês';

  @override
  String get calendarWeek => 'Semana';

  @override
  String get calendarToday => 'Hoje';

  @override
  String get calendarAddExam => 'Cadastrar prova';

  @override
  String get calendarNewExam => 'Nova prova';

  @override
  String get calendarEditExam => 'Editar prova';

  @override
  String get calendarDeleteExam => 'Excluir prova';

  @override
  String get calendarExamName => 'Nome da prova';

  @override
  String get calendarSelectDate => 'Selecionar data';

  @override
  String get calendarSelectTime => 'Selecionar horário';

  @override
  String get calendarNoEvents => 'Não há atividades para este dia.';

  @override
  String get calendarNoUpcoming => 'Não há próximas atividades cadastradas.';

  @override
  String get calendarUpcoming => 'Próximas provas';

  @override
  String get calendarExamSaved => 'Prova salva com sucesso.';

  @override
  String get calendarExamDeleted => 'Prova excluída.';

  @override
  String get calendarNoSubjectAssigned => 'Sem disciplina vinculada';

  @override
  String get calendarTask => 'Tarefa';

  @override
  String get calendarExam => 'Prova';

  @override
  String get profileTitle => 'Meu perfil';

  @override
  String get profileEditName => 'Editar nome';

  @override
  String get profileAcademicData => 'Informações acadêmicas';

  @override
  String get profileInstitution => 'Instituição de ensino';

  @override
  String get profileDegree => 'Curso';

  @override
  String get profileSemester => 'Semestre';

  @override
  String get profileAcademicGoal => 'Meta acadêmica';

  @override
  String get profilePreferences => 'Preferências';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String get profileLanguageHint => 'Idioma do aplicativo';

  @override
  String get profileTheme => 'Tema do aplicativo';

  @override
  String get profileDarkMode => 'Modo escuro';

  @override
  String get profileLightMode => 'Modo claro';

  @override
  String get profileFontSize => 'Tamanho do texto';

  @override
  String get profileSaveSuccess => 'Perfil atualizado com sucesso.';

  @override
  String get quickQrScanner => 'Ler código QR';

  @override
  String get quickGps => 'GPS e mapa';

  @override
  String get quickNotifications => 'Notificações';

  @override
  String get modulesPending => 'Integração pendente';

  @override
  String get modulesResponsible => 'Responsável';

  @override
  String get modulesBackHome => 'Voltar ao início';

  @override
  String get modulesTasksTitle => 'Gerenciamento de tarefas';

  @override
  String get modulesGpsTitle => 'GPS e geolocalização';

  @override
  String get modulesNotificationsTitle => 'Notificações';

  @override
  String get modulesTasksDescription =>
      'Este módulo já foi desenvolvido e aguarda integração com o StudyTrack.';

  @override
  String get modulesGpsDescription =>
      'O módulo de localização e mapas já foi desenvolvido e aguarda integração com o StudyTrack.';

  @override
  String get modulesNotificationsDescription =>
      'A integração das notificações e dos lembretes ainda está pendente.';

  @override
  String get qrTitle => 'Leitor de códigos QR';

  @override
  String get qrCameraPermission => 'É necessário permitir o acesso à câmera.';

  @override
  String get errorsConnection => 'Verifique sua conexão com a internet.';

  @override
  String get errorsPermission =>
      'Você não tem permissão para realizar esta ação.';

  @override
  String get errorsCouldNotSave => 'Não foi possível salvar as informações.';

  @override
  String get errorsCouldNotDelete => 'Não foi possível excluir o registro.';

  @override
  String get errorsNotSignedIn => 'Entre na sua conta para continuar.';
}
