import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'language_controller.dart';

// =====================================================
// HISTORIAL DE NOTIFICACIONES - STUDYTRACK
// =====================================================
//
// Historial personal de avisos en Firestore.
//
// Ruta:
// usuarios/{uid}/notificaciones
//
// Compatible con español y portugués brasileño.
//
// El idioma se obtiene del languageController.
//
// IMPORTANTE:
// Un recordatorio "programado" NO confirma
// que Android ya haya mostrado la notificación.
//
// =====================================================

class NotificationHistory {
  // =====================================================
  // ESTADO DEL HISTORIAL
  // =====================================================

  static final ValueNotifier<List<Map<String, dynamic>>> notificaciones =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  // =====================================================
  // SUSCRIPCIONES
  // =====================================================

  static StreamSubscription<User?>? _suscripcionSesion;

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _suscripcionHistorial;

  static String? _uidEscuchado;

  static bool _escuchando = false;

  // =====================================================
  // TRADUCCIONES
  // =====================================================

  // Este servicio no utiliza BuildContext.
  //
  // Consultamos el mismo languageController
  // que utilizan Login, Perfil y el resto
  // de StudyTrack.

  static bool get _esPortugues {
    return languageController.languageCode.startsWith('pt');
  }

  static String _t(String es, String pt) {
    return _esPortugues ? pt : es;
  }

  // =====================================================
  // COLECCIÓN DE FIRESTORE
  // =====================================================

  static CollectionReference<Map<String, dynamic>> _coleccion(String uid) {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones');
  }

  // =====================================================
  // INICIAR ESCUCHA DEL HISTORIAL
  // =====================================================

  // Mantiene la campanita sincronizada al
  // iniciar sesión y cerrar sesión.
  //
  // Es seguro llamarlo más de una vez.

  static void iniciarEscucha() {
    if (_escuchando) return;

    _escuchando = true;

    _suscripcionSesion = FirebaseAuth.instance.authStateChanges().listen(
      (usuario) {
        _escucharUsuario(usuario?.uid);
      },

      onError: (Object errorSesion) {
        debugPrint('Error escuchando la sesión: $errorSesion');

        error.value = _t(
          'No se pudo comprobar la sesión del usuario.',
          'Não foi possível verificar a sessão '
              'do usuário.',
        );
      },
    );

    _escucharUsuario(FirebaseAuth.instance.currentUser?.uid);
  }

  // =====================================================
  // ESCUCHAR NOTIFICACIONES DEL USUARIO
  // =====================================================

  static void _escucharUsuario(String? uid) {
    if (uid == _uidEscuchado) return;

    // ========================================
    // CANCELAR SUSCRIPCIÓN ANTERIOR
    // ========================================

    final suscripcionAnterior = _suscripcionHistorial;

    if (suscripcionAnterior != null) {
      unawaited(suscripcionAnterior.cancel());
    }

    _suscripcionHistorial = null;

    _uidEscuchado = uid;

    // Limpiar datos del usuario anterior.
    notificaciones.value = [];
    error.value = null;

    if (uid == null) return;

    // ========================================
    // ESCUCHAR FIRESTORE EN TIEMPO REAL
    // ========================================

    _suscripcionHistorial = _coleccion(uid)
        .orderBy('creadaEn', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (_uidEscuchado != uid) return;

            // ====================================
            // CONVERTIR DOCUMENTOS
            // ====================================

            final lista = snapshot.docs.map((documento) {
              final datos = documento.data();

              final fechaGuardada = datos['fecha'];

              final fecha = fechaGuardada is Timestamp
                  ? fechaGuardada.toDate()
                  : fechaGuardada is DateTime
                  ? fechaGuardada
                  : null;

              // Mantener los nombres originales
              // de los campos de Firestore.

              return <String, dynamic>{
                ...datos,

                'documentoId': documento.id,

                'id': datos['id'] is int ? datos['id'] : 0,

                'titulo': datos['titulo']?.toString() ?? _t('Aviso', 'Aviso'),

                'mensaje': datos['mensaje']?.toString() ?? '',

                'tipo': datos['tipo']?.toString() ?? 'general',

                'estado': datos['estado']?.toString() ?? 'registrado',

                'fecha': fecha,

                'leida': datos['leida'] == true,
              };
            }).toList();

            notificaciones.value = lista;
            error.value = null;
          },

          onError: (Object errorHistorial) {
            if (_uidEscuchado != uid) return;

            debugPrint(
              'Error cargando el historial '
              'de Firestore: $errorHistorial',
            );

            error.value = _t(
              'No se pudo cargar el historial. '
                  'Revisá las reglas de Firestore.',
              'Não foi possível carregar o histórico. '
                  'Verifique as regras do Firestore.',
            );
          },
        );
  }

  // =====================================================
  // AGREGAR NOTIFICACIÓN INMEDIATA
  // =====================================================

  // Registra avisos generales o de proximidad.
  //
  // El título y el mensaje ya llegan localizados
  // desde NotificationService.
  //
  // No traducimos nuevamente estos parámetros
  // para conservar los mensajes personalizados.

  static Future<void> agregar({
    required String titulo,
    required String mensaje,
    required String tipo,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    await _coleccion(usuario.uid).add(<String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch,

      'titulo': titulo,

      'mensaje': mensaje,

      'tipo': tipo,

      'estado': 'registrado',

      'fecha': Timestamp.now(),

      'creadaEn': FieldValue.serverTimestamp(),

      'leida': false,
    });
  }

  // =====================================================
  // REGISTRAR RECORDATORIO PROGRAMADO
  // =====================================================

  // Guarda que Android recibió una solicitud
  // para programar el recordatorio.
  //
  // No indica que haya sido entregado.
  //
  // Ahora guarda los textos automáticos
  // en el idioma seleccionado.
  //
  // El nombre de la tarea no se traduce.

  static Future<void> registrarProgramado({
    required int id,
    required String titulo,
    required DateTime fecha,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    // ========================================
    // TEXTOS SEGÚN EL IDIOMA
    // ========================================

    final tituloNotificacion = _t('Recordatorio: $titulo', 'Lembrete: $titulo');

    final mensajeNotificacion = _t(
      'Tenés una tarea próxima.',
      'Você tem uma tarefa próxima.',
    );

    // ========================================
    // GUARDAR EN FIRESTORE
    // ========================================

    await _coleccion(usuario.uid).doc('tarea_$id').set(<String, dynamic>{
      'id': id,

      'titulo': tituloNotificacion,

      'mensaje': mensajeNotificacion,

      // Los identificadores internos
      // permanecen en español.
      //
      // Estos NO deben traducirse.
      'tipo': 'tarea',

      'estado': 'programado',

      'fecha': Timestamp.fromDate(fecha),

      'creadaEn': FieldValue.serverTimestamp(),

      'leida': false,
    });
  }

  // =====================================================
  // MARCAR RECORDATORIO COMO CANCELADO
  // =====================================================

  // Se conserva el comportamiento original:
  // solamente se cancela en el historial
  // si la hora del recordatorio aún no pasó.

  static Future<void> marcarCancelado(int id) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    final referencia = _coleccion(usuario.uid).doc('tarea_$id');

    final documento = await referencia.get();

    if (!documento.exists) return;

    final datos = documento.data();

    final fecha = datos?['fecha'];

    if (fecha is Timestamp && fecha.toDate().isAfter(DateTime.now())) {
      await referencia.update(<String, dynamic>{
        'estado': 'cancelado',

        'canceladaEn': FieldValue.serverTimestamp(),
      });
    }
  }

  // =====================================================
  // MARCAR UNA NOTIFICACIÓN COMO LEÍDA
  // =====================================================

  // Mantener la firma original que utiliza
  // NotificationsScreen.

  static void marcarLeida(int id) {
    final coincidencias = notificaciones.value
        .where((aviso) => aviso['id'] == id)
        .toList();

    if (coincidencias.isEmpty) return;

    // Actualizar primero la interfaz.
    // Después sincronizar con Firestore.

    notificaciones.value = [
      for (final aviso in notificaciones.value)
        <String, dynamic>{...aviso, if (aviso['id'] == id) 'leida': true},
    ];

    final documentoId = coincidencias.first['documentoId'];

    if (documentoId is String) {
      unawaited(_guardarLeida(documentoId));
    }
  }

  // =====================================================
  // GUARDAR ESTADO DE LECTURA
  // =====================================================

  static Future<void> _guardarLeida(String documentoId) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    try {
      await _coleccion(
        usuario.uid,
      ).doc(documentoId).update(<String, dynamic>{'leida': true});
    } catch (errorLectura) {
      debugPrint(
        'No se pudo marcar la notificación '
        'como leída: $errorLectura',
      );
    }
  }

  // =====================================================
  // MARCAR TODAS COMO LEÍDAS
  // =====================================================

  static void marcarTodasLeidas() {
    final documentos = notificaciones.value
        .where((aviso) => aviso['leida'] != true)
        .map((aviso) => aviso['documentoId'])
        .whereType<String>()
        .toList();

    // Actualizar de inmediato la pantalla.

    notificaciones.value = [
      for (final aviso in notificaciones.value)
        <String, dynamic>{...aviso, 'leida': true},
    ];

    // Guardar los cambios en Firestore.

    unawaited(_guardarTodasLeidas(documentos));
  }

  // =====================================================
  // GUARDAR TODAS LAS NOTIFICACIONES LEÍDAS
  // =====================================================

  static Future<void> _guardarTodasLeidas(List<String> documentos) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null || documentos.isEmpty) {
      return;
    }

    try {
      // Firestore admite como máximo
      // 500 escrituras por lote.
      //
      // Se conserva el tamaño de lote
      // original de 400 documentos.

      for (var inicio = 0; inicio < documentos.length; inicio += 400) {
        final fin = (inicio + 400 < documentos.length)
            ? inicio + 400
            : documentos.length;

        final lote = FirebaseFirestore.instance.batch();

        for (final documentoId in documentos.sublist(inicio, fin)) {
          lote.update(
            _coleccion(usuario.uid).doc(documentoId),

            <String, dynamic>{'leida': true},
          );
        }

        await lote.commit();
      }
    } catch (errorLectura) {
      debugPrint(
        'No se pudieron marcar '
        'todos los avisos: $errorLectura',
      );
    }
  }

  // =====================================================
  // LIMPIAR LISTA LOCAL
  // =====================================================

  // Borra la lista mostrada en pantalla.
  //
  // NO elimina documentos de Firestore.

  static void limpiar() {
    notificaciones.value = [];
  }

  // =====================================================
  // DETENER ESCUCHA
  // =====================================================

  static Future<void> detenerEscucha() async {
    await _suscripcionHistorial?.cancel();
    await _suscripcionSesion?.cancel();

    _suscripcionHistorial = null;
    _suscripcionSesion = null;

    _uidEscuchado = null;
    _escuchando = false;

    limpiar();

    error.value = null;
  }
}
