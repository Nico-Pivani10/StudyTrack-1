import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'StudyTrack'**
  String get appTitle;

  /// No description provided for @appSlogan.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero académico'**
  String get appSlogan;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @commonConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get commonConfirm;

  /// No description provided for @commonLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In es, this message translates to:
  /// **'Operación realizada correctamente'**
  String get commonSuccess;

  /// No description provided for @commonContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @commonAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get commonSearch;

  /// No description provided for @commonOptional.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get commonOptional;

  /// No description provided for @authLogin.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get authRegister;

  /// No description provided for @authLogout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get authLogout;

  /// No description provided for @authEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get authConfirmPassword;

  /// No description provided for @authFullName.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get authFullName;

  /// No description provided for @authForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get authForgotPassword;

  /// No description provided for @authResetPassword.
  ///
  /// In es, this message translates to:
  /// **'Restablecer contraseña'**
  String get authResetPassword;

  /// No description provided for @authSendReset.
  ///
  /// In es, this message translates to:
  /// **'Enviar correo de recuperación'**
  String get authSendReset;

  /// No description provided for @authSignInGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get authSignInGoogle;

  /// No description provided for @authNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tenés una cuenta?'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tenés una cuenta?'**
  String get authHaveAccount;

  /// No description provided for @authVerifyEmail.
  ///
  /// In es, this message translates to:
  /// **'Verificar correo electrónico'**
  String get authVerifyEmail;

  /// No description provided for @authEmailVerified.
  ///
  /// In es, this message translates to:
  /// **'Correo verificado'**
  String get authEmailVerified;

  /// No description provided for @authEmailNotVerified.
  ///
  /// In es, this message translates to:
  /// **'Correo no verificado'**
  String get authEmailNotVerified;

  /// No description provided for @authInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresá un correo válido'**
  String get authInvalidEmail;

  /// No description provided for @authRequiredField.
  ///
  /// In es, this message translates to:
  /// **'Este campo es obligatorio'**
  String get authRequiredField;

  /// No description provided for @authLoginFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión'**
  String get authLoginFailed;

  /// No description provided for @authRegisterSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cuenta creada correctamente'**
  String get authRegisterSuccess;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navSubjects.
  ///
  /// In es, this message translates to:
  /// **'Materias'**
  String get navSubjects;

  /// No description provided for @navTasks.
  ///
  /// In es, this message translates to:
  /// **'Tareas'**
  String get navTasks;

  /// No description provided for @navCalendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get navCalendar;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @dashboardWelcome.
  ///
  /// In es, this message translates to:
  /// **'¡Hola, {name}!'**
  String dashboardWelcome(String name);

  /// No description provided for @dashboardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Organizá tu día de estudio y alcanzá tus metas.'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardQuickAccess.
  ///
  /// In es, this message translates to:
  /// **'Accesos rápidos'**
  String get dashboardQuickAccess;

  /// No description provided for @dashboardAcademicSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen académico'**
  String get dashboardAcademicSummary;

  /// No description provided for @dashboardTaskProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso de tareas'**
  String get dashboardTaskProgress;

  /// No description provided for @dashboardUpcomingActivities.
  ///
  /// In es, this message translates to:
  /// **'Próximas actividades'**
  String get dashboardUpcomingActivities;

  /// No description provided for @dashboardWeeklyGoal.
  ///
  /// In es, this message translates to:
  /// **'Meta semanal'**
  String get dashboardWeeklyGoal;

  /// No description provided for @dashboardDaysStudied.
  ///
  /// In es, this message translates to:
  /// **'Días de estudio'**
  String get dashboardDaysStudied;

  /// No description provided for @dashboardStudyMinutes.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de estudio registrado'**
  String get dashboardStudyMinutes;

  /// No description provided for @dashboardNoTasks.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay tareas registradas.'**
  String get dashboardNoTasks;

  /// No description provided for @dashboardNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay próximas actividades.'**
  String get dashboardNoEvents;

  /// No description provided for @dashboardViewAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todas'**
  String get dashboardViewAll;

  /// No description provided for @dashboardViewCalendar.
  ///
  /// In es, this message translates to:
  /// **'Ver calendario'**
  String get dashboardViewCalendar;

  /// No description provided for @subjectsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis materias'**
  String get subjectsTitle;

  /// No description provided for @subjectsOrganize.
  ///
  /// In es, this message translates to:
  /// **'Organizá tus materias'**
  String get subjectsOrganize;

  /// No description provided for @subjectsAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar materia'**
  String get subjectsAdd;

  /// No description provided for @subjectsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar materia'**
  String get subjectsEdit;

  /// No description provided for @subjectsDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar materia'**
  String get subjectsDelete;

  /// No description provided for @subjectsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la materia'**
  String get subjectsName;

  /// No description provided for @subjectsTeacher.
  ///
  /// In es, this message translates to:
  /// **'Docente'**
  String get subjectsTeacher;

  /// No description provided for @subjectsDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get subjectsDescription;

  /// No description provided for @subjectsNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tenés materias.'**
  String get subjectsNone;

  /// No description provided for @subjectsNoTasks.
  ///
  /// In es, this message translates to:
  /// **'Sin tareas registradas'**
  String get subjectsNoTasks;

  /// No description provided for @subjectsSaveSuccess.
  ///
  /// In es, this message translates to:
  /// **'Materia guardada correctamente.'**
  String get subjectsSaveSuccess;

  /// No description provided for @subjectsDeleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'Materia eliminada.'**
  String get subjectsDeleteSuccess;

  /// No description provided for @subjectsCannotDelete.
  ///
  /// In es, this message translates to:
  /// **'Esta materia tiene tareas o exámenes asociados.'**
  String get subjectsCannotDelete;

  /// No description provided for @tasksTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis tareas'**
  String get tasksTitle;

  /// No description provided for @tasksCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completadas'**
  String get tasksCompleted;

  /// No description provided for @tasksPending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get tasksPending;

  /// No description provided for @calendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario académico'**
  String get calendarTitle;

  /// No description provided for @calendarSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Consultá tus tareas y exámenes por fecha.'**
  String get calendarSubtitle;

  /// No description provided for @calendarMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get calendarMonth;

  /// No description provided for @calendarWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get calendarWeek;

  /// No description provided for @calendarToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get calendarToday;

  /// No description provided for @calendarAddExam.
  ///
  /// In es, this message translates to:
  /// **'Registrar examen'**
  String get calendarAddExam;

  /// No description provided for @calendarNewExam.
  ///
  /// In es, this message translates to:
  /// **'Nuevo examen'**
  String get calendarNewExam;

  /// No description provided for @calendarEditExam.
  ///
  /// In es, this message translates to:
  /// **'Editar examen'**
  String get calendarEditExam;

  /// No description provided for @calendarDeleteExam.
  ///
  /// In es, this message translates to:
  /// **'Eliminar examen'**
  String get calendarDeleteExam;

  /// No description provided for @calendarExamName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del examen'**
  String get calendarExamName;

  /// No description provided for @calendarSelectDate.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar fecha'**
  String get calendarSelectDate;

  /// No description provided for @calendarSelectTime.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar hora'**
  String get calendarSelectTime;

  /// No description provided for @calendarNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay actividades para este día.'**
  String get calendarNoEvents;

  /// No description provided for @calendarNoUpcoming.
  ///
  /// In es, this message translates to:
  /// **'No hay próximas actividades registradas.'**
  String get calendarNoUpcoming;

  /// No description provided for @calendarUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próximos exámenes'**
  String get calendarUpcoming;

  /// No description provided for @calendarExamSaved.
  ///
  /// In es, this message translates to:
  /// **'Examen guardado correctamente.'**
  String get calendarExamSaved;

  /// No description provided for @calendarExamDeleted.
  ///
  /// In es, this message translates to:
  /// **'Examen eliminado.'**
  String get calendarExamDeleted;

  /// No description provided for @calendarNoSubjectAssigned.
  ///
  /// In es, this message translates to:
  /// **'Sin materia asignada'**
  String get calendarNoSubjectAssigned;

  /// No description provided for @calendarTask.
  ///
  /// In es, this message translates to:
  /// **'Tarea'**
  String get calendarTask;

  /// No description provided for @calendarExam.
  ///
  /// In es, this message translates to:
  /// **'Examen'**
  String get calendarExam;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Mi perfil'**
  String get profileTitle;

  /// No description provided for @profileEditName.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get profileEditName;

  /// No description provided for @profileAcademicData.
  ///
  /// In es, this message translates to:
  /// **'Información académica'**
  String get profileAcademicData;

  /// No description provided for @profileInstitution.
  ///
  /// In es, this message translates to:
  /// **'Institución educativa'**
  String get profileInstitution;

  /// No description provided for @profileDegree.
  ///
  /// In es, this message translates to:
  /// **'Carrera'**
  String get profileDegree;

  /// No description provided for @profileSemester.
  ///
  /// In es, this message translates to:
  /// **'Semestre'**
  String get profileSemester;

  /// No description provided for @profileAcademicGoal.
  ///
  /// In es, this message translates to:
  /// **'Meta académica'**
  String get profileAcademicGoal;

  /// No description provided for @profilePreferences.
  ///
  /// In es, this message translates to:
  /// **'Preferencias'**
  String get profilePreferences;

  /// No description provided for @profileLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get profileLanguage;

  /// No description provided for @profileLanguageHint.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la aplicación'**
  String get profileLanguageHint;

  /// No description provided for @profileTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema de la aplicación'**
  String get profileTheme;

  /// No description provided for @profileDarkMode.
  ///
  /// In es, this message translates to:
  /// **'Modo oscuro'**
  String get profileDarkMode;

  /// No description provided for @profileLightMode.
  ///
  /// In es, this message translates to:
  /// **'Modo claro'**
  String get profileLightMode;

  /// No description provided for @profileFontSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño del texto'**
  String get profileFontSize;

  /// No description provided for @profileSaveSuccess.
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado correctamente.'**
  String get profileSaveSuccess;

  /// No description provided for @quickQrScanner.
  ///
  /// In es, this message translates to:
  /// **'Escanear QR'**
  String get quickQrScanner;

  /// No description provided for @quickGps.
  ///
  /// In es, this message translates to:
  /// **'GPS y mapa'**
  String get quickGps;

  /// No description provided for @quickNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get quickNotifications;

  /// No description provided for @modulesPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de integración'**
  String get modulesPending;

  /// No description provided for @modulesResponsible.
  ///
  /// In es, this message translates to:
  /// **'Responsable'**
  String get modulesResponsible;

  /// No description provided for @modulesBackHome.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get modulesBackHome;

  /// No description provided for @modulesTasksTitle.
  ///
  /// In es, this message translates to:
  /// **'Gestión de tareas'**
  String get modulesTasksTitle;

  /// No description provided for @modulesGpsTitle.
  ///
  /// In es, this message translates to:
  /// **'GPS y geolocalización'**
  String get modulesGpsTitle;

  /// No description provided for @modulesNotificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get modulesNotificationsTitle;

  /// No description provided for @modulesTasksDescription.
  ///
  /// In es, this message translates to:
  /// **'Este módulo fue desarrollado y está pendiente de integración con StudyTrack.'**
  String get modulesTasksDescription;

  /// No description provided for @modulesGpsDescription.
  ///
  /// In es, this message translates to:
  /// **'El módulo de ubicación y mapas ya fue desarrollado y está pendiente de integración con StudyTrack.'**
  String get modulesGpsDescription;

  /// No description provided for @modulesNotificationsDescription.
  ///
  /// In es, this message translates to:
  /// **'La integración de notificaciones y recordatorios se encuentra pendiente.'**
  String get modulesNotificationsDescription;

  /// No description provided for @qrTitle.
  ///
  /// In es, this message translates to:
  /// **'Escáner de códigos QR'**
  String get qrTitle;

  /// No description provided for @qrCameraPermission.
  ///
  /// In es, this message translates to:
  /// **'Se necesita permiso para utilizar la cámara.'**
  String get qrCameraPermission;

  /// No description provided for @errorsConnection.
  ///
  /// In es, this message translates to:
  /// **'Revisá tu conexión a Internet.'**
  String get errorsConnection;

  /// No description provided for @errorsPermission.
  ///
  /// In es, this message translates to:
  /// **'No tenés permisos para realizar esta acción.'**
  String get errorsPermission;

  /// No description provided for @errorsCouldNotSave.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la información.'**
  String get errorsCouldNotSave;

  /// No description provided for @errorsCouldNotDelete.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar el registro.'**
  String get errorsCouldNotDelete;

  /// No description provided for @errorsNotSignedIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciá sesión para continuar.'**
  String get errorsNotSignedIn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
