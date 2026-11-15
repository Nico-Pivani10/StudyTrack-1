// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'StudyTrack';

  @override
  String get appSlogan => 'Tu compañero académico';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Operación realizada correctamente';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonAdd => 'Agregar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get authLogin => 'Iniciar sesión';

  @override
  String get authRegister => 'Registrarse';

  @override
  String get authLogout => 'Cerrar sesión';

  @override
  String get authEmail => 'Correo electrónico';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authConfirmPassword => 'Confirmar contraseña';

  @override
  String get authFullName => 'Nombre completo';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authResetPassword => 'Restablecer contraseña';

  @override
  String get authSendReset => 'Enviar correo de recuperación';

  @override
  String get authSignInGoogle => 'Continuar con Google';

  @override
  String get authNoAccount => '¿No tenés una cuenta?';

  @override
  String get authHaveAccount => '¿Ya tenés una cuenta?';

  @override
  String get authVerifyEmail => 'Verificar correo electrónico';

  @override
  String get authEmailVerified => 'Correo verificado';

  @override
  String get authEmailNotVerified => 'Correo no verificado';

  @override
  String get authInvalidEmail => 'Ingresá un correo válido';

  @override
  String get authRequiredField => 'Este campo es obligatorio';

  @override
  String get authLoginFailed => 'No se pudo iniciar sesión';

  @override
  String get authRegisterSuccess => 'Cuenta creada correctamente';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSubjects => 'Materias';

  @override
  String get navTasks => 'Tareas';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navProfile => 'Perfil';

  @override
  String dashboardWelcome(String name) {
    return '¡Hola, $name!';
  }

  @override
  String get dashboardSubtitle =>
      'Organizá tu día de estudio y alcanzá tus metas.';

  @override
  String get dashboardQuickAccess => 'Accesos rápidos';

  @override
  String get dashboardAcademicSummary => 'Resumen académico';

  @override
  String get dashboardTaskProgress => 'Progreso de tareas';

  @override
  String get dashboardUpcomingActivities => 'Próximas actividades';

  @override
  String get dashboardWeeklyGoal => 'Meta semanal';

  @override
  String get dashboardDaysStudied => 'Días de estudio';

  @override
  String get dashboardStudyMinutes => 'Tiempo de estudio registrado';

  @override
  String get dashboardNoTasks => 'Todavía no hay tareas registradas.';

  @override
  String get dashboardNoEvents => 'No hay próximas actividades.';

  @override
  String get dashboardViewAll => 'Ver todas';

  @override
  String get dashboardViewCalendar => 'Ver calendario';

  @override
  String get subjectsTitle => 'Mis materias';

  @override
  String get subjectsOrganize => 'Organizá tus materias';

  @override
  String get subjectsAdd => 'Agregar materia';

  @override
  String get subjectsEdit => 'Editar materia';

  @override
  String get subjectsDelete => 'Eliminar materia';

  @override
  String get subjectsName => 'Nombre de la materia';

  @override
  String get subjectsTeacher => 'Docente';

  @override
  String get subjectsDescription => 'Descripción';

  @override
  String get subjectsNone => 'Todavía no tenés materias.';

  @override
  String get subjectsNoTasks => 'Sin tareas registradas';

  @override
  String get subjectsSaveSuccess => 'Materia guardada correctamente.';

  @override
  String get subjectsDeleteSuccess => 'Materia eliminada.';

  @override
  String get subjectsCannotDelete =>
      'Esta materia tiene tareas o exámenes asociados.';

  @override
  String get tasksTitle => 'Mis tareas';

  @override
  String get tasksCompleted => 'Completadas';

  @override
  String get tasksPending => 'Pendientes';

  @override
  String get calendarTitle => 'Calendario académico';

  @override
  String get calendarSubtitle => 'Consultá tus tareas y exámenes por fecha.';

  @override
  String get calendarMonth => 'Mes';

  @override
  String get calendarWeek => 'Semana';

  @override
  String get calendarToday => 'Hoy';

  @override
  String get calendarAddExam => 'Registrar examen';

  @override
  String get calendarNewExam => 'Nuevo examen';

  @override
  String get calendarEditExam => 'Editar examen';

  @override
  String get calendarDeleteExam => 'Eliminar examen';

  @override
  String get calendarExamName => 'Nombre del examen';

  @override
  String get calendarSelectDate => 'Seleccionar fecha';

  @override
  String get calendarSelectTime => 'Seleccionar hora';

  @override
  String get calendarNoEvents => 'No hay actividades para este día.';

  @override
  String get calendarNoUpcoming => 'No hay próximas actividades registradas.';

  @override
  String get calendarUpcoming => 'Próximos exámenes';

  @override
  String get calendarExamSaved => 'Examen guardado correctamente.';

  @override
  String get calendarExamDeleted => 'Examen eliminado.';

  @override
  String get calendarNoSubjectAssigned => 'Sin materia asignada';

  @override
  String get calendarTask => 'Tarea';

  @override
  String get calendarExam => 'Examen';

  @override
  String get profileTitle => 'Mi perfil';

  @override
  String get profileEditName => 'Editar nombre';

  @override
  String get profileAcademicData => 'Información académica';

  @override
  String get profileInstitution => 'Institución educativa';

  @override
  String get profileDegree => 'Carrera';

  @override
  String get profileSemester => 'Semestre';

  @override
  String get profileAcademicGoal => 'Meta académica';

  @override
  String get profilePreferences => 'Preferencias';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String get profileLanguageHint => 'Idioma de la aplicación';

  @override
  String get profileTheme => 'Tema de la aplicación';

  @override
  String get profileDarkMode => 'Modo oscuro';

  @override
  String get profileLightMode => 'Modo claro';

  @override
  String get profileFontSize => 'Tamaño del texto';

  @override
  String get profileSaveSuccess => 'Perfil actualizado correctamente.';

  @override
  String get quickQrScanner => 'Escanear QR';

  @override
  String get quickGps => 'GPS y mapa';

  @override
  String get quickNotifications => 'Notificaciones';

  @override
  String get modulesPending => 'Pendiente de integración';

  @override
  String get modulesResponsible => 'Responsable';

  @override
  String get modulesBackHome => 'Volver al inicio';

  @override
  String get modulesTasksTitle => 'Gestión de tareas';

  @override
  String get modulesGpsTitle => 'GPS y geolocalización';

  @override
  String get modulesNotificationsTitle => 'Notificaciones';

  @override
  String get modulesTasksDescription =>
      'Este módulo fue desarrollado y está pendiente de integración con StudyTrack.';

  @override
  String get modulesGpsDescription =>
      'El módulo de ubicación y mapas ya fue desarrollado y está pendiente de integración con StudyTrack.';

  @override
  String get modulesNotificationsDescription =>
      'La integración de notificaciones y recordatorios se encuentra pendiente.';

  @override
  String get qrTitle => 'Escáner de códigos QR';

  @override
  String get qrCameraPermission =>
      'Se necesita permiso para utilizar la cámara.';

  @override
  String get errorsConnection => 'Revisá tu conexión a Internet.';

  @override
  String get errorsPermission => 'No tenés permisos para realizar esta acción.';

  @override
  String get errorsCouldNotSave => 'No se pudo guardar la información.';

  @override
  String get errorsCouldNotDelete => 'No se pudo eliminar el registro.';

  @override
  String get errorsNotSignedIn => 'Iniciá sesión para continuar.';
}
