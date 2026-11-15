import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'language_controller.dart';
import 'notification_history.dart';

// =====================================================
// SERVICIO DE NOTIFICACIONES - STUDYTRACK
// =====================================================
//
// Compatible con español y portugués brasileño.
//
// El idioma se obtiene del languageController,
// que utiliza el resto de StudyTrack.
//
// Se mantienen:
// - Notificaciones locales de Android
// - Recordatorios programados
// - Notificaciones por proximidad GPS
// - Historial de Firestore
// - Cancelación de recordatorios
// - Zona horaria del dispositivo
// - Identificadores de canales y notificaciones
//
// =====================================================

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  // =====================================================
  // SISTEMA DE TRADUCCIONES
  // =====================================================

  // Como este servicio no tiene BuildContext,
  // consultamos directamente el controlador global.
  //
  // La preferencia ya fue cargada en main.dart.
  //
  // Idiomas:
  // es    = Español
  // pt_BR = Português (Brasil)

  static bool get _esPortugues {
    return languageController.languageCode.startsWith('pt');
  }

  static String _t(String es, String pt) {
    return _esPortugues ? pt : es;
  }

  // =====================================================
  // INICIALIZAR NOTIFICACIONES
  // =====================================================

  static Future<void> initialize() async {
    if (_inicializado) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings: settings);

    // ========================================
    // ZONA HORARIA DEL DISPOSITIVO
    // ========================================

    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (error) {
      debugPrint('Error configurando zona horaria: $error');

      // Mantener el comportamiento original.
      tz.setLocalLocation(tz.UTC);
    }

    // ========================================
    // PERMISO DE NOTIFICACIONES EN ANDROID
    // ========================================

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _inicializado = true;

    // Mantener la escucha del historial.
    NotificationHistory.iniciarEscucha();

    debugPrint('StudyTrack: notificaciones inicializadas');
  }

  // =====================================================
  // NOTIFICACIONES DE PROXIMIDAD GPS
  // =====================================================

  static Future<void> mostrarProximidad(String lugar) async {
    await initialize();

    // Mantener el mismo ID del canal de Android.
    // Solo se localizan su nombre y descripción.

    final androidDetails = AndroidNotificationDetails(
      'studytrack_proximidad',

      _t('Proximidad', 'Proximidade'),

      channelDescription: _t(
        'Notificaciones de proximidad de StudyTrack',
        'Notificações de proximidade do StudyTrack',
      ),

      importance: Importance.high,
      priority: Priority.high,
    );

    // ========================================
    // MENSAJE SEGÚN EL IDIOMA
    // ========================================

    final tituloNotificacion = _t(
      'StudyTrack - Proximidad',
      'StudyTrack - Proximidade',
    );

    final mensaje = _t('Estás cerca de $lugar.', 'Você está perto de $lugar.');

    // ========================================
    // MOSTRAR NOTIFICACIÓN EN ANDROID
    // ========================================

    await _notifications.show(
      id: 100,

      title: tituloNotificacion,
      body: mensaje,

      notificationDetails: NotificationDetails(android: androidDetails),
    );

    // ========================================
    // GUARDAR EN HISTORIAL
    // ========================================

    try {
      await NotificationHistory.agregar(
        titulo: _t('Proximidad detectada', 'Proximidade detectada'),

        mensaje: mensaje,
        tipo: 'gps',
      );
    } catch (error) {
      debugPrint(
        'Aviso GPS enviado, pero no guardado '
        'en Firestore: $error',
      );
    }

    debugPrint('Proximidad registrada: $lugar');
  }

  // =====================================================
  // PROGRAMAR RECORDATORIO DE TAREA
  // =====================================================

  static Future<void> programarRecordatorio({
    required int id,
    required String titulo,
    required DateTime fecha,
  }) async {
    await initialize();

    // ========================================
    // VALIDAR LA FECHA
    // ========================================

    if (!fecha.isAfter(DateTime.now())) {
      throw ArgumentError(
        _t(
          'La fecha del recordatorio debe ser futura.',
          'A data do lembrete deve ser futura.',
        ),
      );
    }

    // ========================================
    // CONFIGURACIÓN DE ANDROID
    // ========================================

    // El identificador del canal no cambia.
    // Esto conserva su compatibilidad.

    final androidDetails = AndroidNotificationDetails(
      'studytrack_tareas',

      _t('Recordatorios de tareas', 'Lembretes de tarefas'),

      channelDescription: _t(
        'Avisos de las tareas programadas en StudyTrack',
        'Avisos das tarefas programadas no StudyTrack',
      ),

      importance: Importance.high,
      priority: Priority.high,
    );

    // ========================================
    // TÍTULO Y MENSAJE LOCALIZADOS
    // ========================================

    // El nombre de la tarea nunca se traduce.
    // Solo cambia la parte automática del aviso.

    final tituloNotificacion = _t('Recordatorio: $titulo', 'Lembrete: $titulo');

    final mensajeNotificacion = _t(
      'Tenés una tarea próxima.',
      'Você tem uma tarefa próxima.',
    );

    // ========================================
    // PROGRAMAR NOTIFICACIÓN
    // ========================================

    // Se conserva el modo original:
    // inexactAllowWhileIdle.
    //
    // Esto permite mantener el funcionamiento
    // existente de los recordatorios.

    await _notifications.zonedSchedule(
      id: id,

      title: tituloNotificacion,
      body: mensajeNotificacion,

      scheduledDate: tz.TZDateTime.from(fecha, tz.local),

      notificationDetails: NotificationDetails(android: androidDetails),

      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    // ========================================
    // REGISTRAR EN FIRESTORE
    // ========================================

    // Conservamos el método original.
    //
    // El historial registra que el aviso fue
    // programado, no que ya fue entregado.

    try {
      await NotificationHistory.registrarProgramado(
        id: id,
        titulo: titulo,
        fecha: fecha,
      );
    } catch (error) {
      debugPrint(
        'Recordatorio programado, '
        'pero no registrado: $error',
      );
    }

    debugPrint('Recordatorio programado: $titulo para $fecha');
  }

  // =====================================================
  // CANCELAR RECORDATORIO
  // =====================================================

  static Future<void> cancelarRecordatorio(int id) async {
    await initialize();

    // Cancelar la notificación de Android.
    await _notifications.cancel(id: id);

    // ========================================
    // ACTUALIZAR HISTORIAL
    // ========================================

    try {
      await NotificationHistory.marcarCancelado(id);
    } catch (error) {
      debugPrint(
        'Aviso cancelado, pero historial '
        'sin actualizar: $error',
      );
    }

    debugPrint('Recordatorio cancelado: $id');
  }

  // =====================================================
  // MOSTRAR NOTIFICACIÓN INMEDIATA
  // =====================================================

  static Future<void> mostrarNotificacion({
    required int id,
    required String titulo,
    required String mensaje,
  }) async {
    await initialize();

    // ========================================
    // CANAL GENERAL DE ANDROID
    // ========================================

    final androidDetails = AndroidNotificationDetails(
      'studytrack_general',

      _t('Notificaciones generales', 'Notificações gerais'),

      channelDescription: _t(
        'Notificaciones generales de StudyTrack',
        'Notificações gerais do StudyTrack',
      ),

      importance: Importance.high,
      priority: Priority.high,
    );

    // ========================================
    // MOSTRAR NOTIFICACIÓN
    // ========================================

    // Los textos recibidos como parámetros
    // no se modifican automáticamente.
    //
    // Así respetamos cualquier mensaje
    // personalizado que envíe otra pantalla.

    await _notifications.show(
      id: id,

      title: titulo,
      body: mensaje,

      notificationDetails: NotificationDetails(android: androidDetails),
    );

    // ========================================
    // GUARDAR EN FIRESTORE
    // ========================================

    try {
      await NotificationHistory.agregar(
        titulo: titulo,
        mensaje: mensaje,
        tipo: 'general',
      );
    } catch (error) {
      debugPrint(
        'Aviso inmediato enviado, '
        'pero no guardado: $error',
      );
    }

    debugPrint('Notificación registrada: $titulo');
  }

  // =====================================================
  // NOTIFICACIÓN DE PRUEBA
  // =====================================================

  static Future<void> enviarPrueba() async {
    await mostrarNotificacion(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),

      titulo: 'StudyTrack',

      mensaje: _t(
        '¡Las notificaciones están '
            'funcionando correctamente!',
        'As notificações estão '
            'funcionando corretamente!',
      ),
    );
  }
}
