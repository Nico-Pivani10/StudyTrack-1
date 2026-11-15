import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/notification_history.dart';

// =====================================================
// NOTIFICACIONES DE STUDYTRACK
// =====================================================
//
// Historial de notificaciones desde Firestore.
//
// Compatible con español y portugués brasileño.
//
// Traduce los textos automáticos de recordatorios
// ya almacenados, sin modificar los datos originales.
//
// Conserva los colores crema de las tarjetas
// en modo claro y modo oscuro.
//
// =====================================================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // =====================================================
  // COLORES INSTITUCIONALES
  // =====================================================

  static const Color bordo = Color(0xFF670810);
  static const Color coral = Color(0xFFE57373);

  // =====================================================
  // COLORES DE LAS NOTIFICACIONES
  // =====================================================

  static const Color cremaNoLeida = Color(0xFFFFF0E2);
  static const Color cremaLeida = Color(0xFFFFF9F2);

  static const Color bordeNoLeida = Color(0xFFE6C8BD);
  static const Color bordeLeida = Color(0xFFE9DED4);

  static const Color textoPrincipal = Color(0xFF292322);
  static const Color textoSecundario = Color(0xFF5F5650);
  static const Color verdeLeida = Color(0xFF5E7C65);

  // =====================================================
  // TRADUCCIONES
  // =====================================================

  String _t(String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;

    return idioma == 'pt' ? pt : es;
  }

  // =====================================================
  // MODO OSCURO
  // =====================================================

  bool get _esOscuro => Theme.of(context).brightness == Brightness.dark;

  Color get _acento => _esOscuro ? coral : bordo;

  // =====================================================
  // INICIAR ESCUCHA DE NOTIFICACIONES
  // =====================================================

  @override
  void initState() {
    super.initState();

    NotificationHistory.iniciarEscucha();
  }

  // =====================================================
  // FORMATO DE FECHAS
  // =====================================================

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');

    final mes = fecha.month.toString().padLeft(2, '0');

    final hora = fecha.hour.toString().padLeft(2, '0');

    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }

  // =====================================================
  // TRADUCIR TÍTULOS DE RECORDATORIOS
  // =====================================================

  // Las notificaciones antiguas fueron guardadas
  // con títulos como:
  //
  // "Recordatorio: PRUEBA"
  //
  // En portugués se mostrarán como:
  //
  // "Lembrete: PRUEBA"
  //
  // El nombre de la tarea permanece intacto.
  // No se modifica la información de Firestore.

  String _traducirTitulo(String titulo, String tipo) {
    if (tipo != 'tarea') {
      return titulo;
    }

    final patron = RegExp(
      r'^(Recordatorio|Lembrete)\s*:\s*',
      caseSensitive: false,
    );

    if (!patron.hasMatch(titulo)) {
      return titulo;
    }

    final nombreTarea = titulo.replaceFirst(patron, '').trim();

    final etiqueta = _t('Recordatorio', 'Lembrete');

    if (nombreTarea.isEmpty) {
      return etiqueta;
    }

    return '$etiqueta: $nombreTarea';
  }

  // =====================================================
  // TRADUCIR MENSAJES AUTOMÁTICOS ANTIGUOS
  // =====================================================

  // Solo se traducen frases automáticas conocidas.
  //
  // Los mensajes personalizados escritos por
  // el estudiante se mantienen sin cambios.
  //
  // Esto permite mostrar las notificaciones
  // anteriores en ambos idiomas sin reescribir
  // los documentos de Firebase.

  String _traducirMensaje(String mensaje, String tipo) {
    if (tipo != 'tarea') {
      return mensaje;
    }

    final normalizado = mensaje.trim().toLowerCase();

    // ========================================
    // RECORDATORIO DE TAREA PRÓXIMA
    // ========================================

    if (normalizado == 'tenés una tarea próxima.' ||
        normalizado == 'tenés una tarea próxima' ||
        normalizado == 'tienes una tarea próxima.' ||
        normalizado == 'tienes una tarea próxima' ||
        normalizado == 'você tem uma tarefa próxima.' ||
        normalizado == 'você tem uma tarefa próxima') {
      return _t('Tenés una tarea próxima.', 'Você tem uma tarefa próxima.');
    }

    // ========================================
    // RECORDATORIO CANCELADO
    // ========================================

    if (normalizado == 'recordatorio cancelado' ||
        normalizado == 'lembrete cancelado') {
      return _t('Recordatorio cancelado', 'Lembrete cancelado');
    }

    // ========================================
    // OTROS MENSAJES
    // ========================================

    // Si no reconocemos una plantilla automática,
    // conservamos el texto original.

    return mensaje;
  }

  // =====================================================
  // OBTENER TÍTULO DEL AVISO
  // =====================================================

  String _obtenerTitulo(Map<String, dynamic> aviso) {
    final tipo = aviso['tipo']?.toString() ?? 'general';

    final titulo = aviso['titulo']?.toString() ?? '';

    if (titulo.isEmpty) {
      return _t('Aviso', 'Aviso');
    }

    return _traducirTitulo(titulo, tipo);
  }

  // =====================================================
  // OBTENER DETALLE DEL AVISO
  // =====================================================

  String _obtenerDetalle(Map<String, dynamic> aviso) {
    final tipo = aviso['tipo']?.toString() ?? 'general';

    final estado = aviso['estado']?.toString() ?? 'registrado';

    final fecha = aviso['fecha'];

    final mensajeOriginal = aviso['mensaje']?.toString() ?? '';

    // Mostrar una traducción del mensaje automático
    // sin modificar el contenido almacenado.

    String detalle = _traducirMensaje(mensajeOriginal, tipo);

    // ========================================
    // RECORDATORIOS DE TAREAS
    // ========================================

    if (tipo == 'tarea') {
      if (estado == 'cancelado') {
        final cancelado = _t('Recordatorio cancelado', 'Lembrete cancelado');

        // Evitar repetir el estado si el mensaje
        // ya contiene exactamente ese texto.

        if (detalle.trim() != cancelado) {
          detalle += '${detalle.isEmpty ? '' : '\n'}$cancelado';
        }
      } else if (fecha is DateTime) {
        final etiqueta = _t('Hora prevista', 'Horário programado');

        detalle +=
            '${detalle.isEmpty ? '' : '\n'}'
            '$etiqueta: ${_formatearFecha(fecha)}';
      }
    }

    return detalle;
  }

  // =====================================================
  // PANTALLA PRINCIPAL
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ========================================
      // APPBAR
      // ========================================
      appBar: AppBar(
        backgroundColor: bordo,
        foregroundColor: Colors.white,

        title: Text(textos.quickNotifications),

        actions: [
          IconButton(
            tooltip: _t('Marcar todas como leídas', 'Marcar todas como lidas'),

            icon: const Icon(Icons.done_all),

            onPressed: NotificationHistory.marcarTodasLeidas,
          ),
        ],
      ),

      // ========================================
      // ESCUCHAR ERRORES DEL HISTORIAL
      // ========================================
      body: ValueListenableBuilder<String?>(
        valueListenable: NotificationHistory.error,

        builder: (context, error, _) {
          // ====================================
          // ERROR AL CARGAR
          // ====================================

          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(Icons.error_outline, color: _acento, size: 56),

                    const SizedBox(height: 16),

                    Text(
                      _t(
                        'No se pudieron cargar '
                            'las notificaciones.',
                        'Não foi possível carregar '
                            'as notificações.',
                      ),

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Conservar el detalle técnico
                    // entregado por el servicio.
                    Text(
                      error,
                      textAlign: TextAlign.center,

                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ====================================
          // ESCUCHAR LISTA DE NOTIFICACIONES
          // ====================================

          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: NotificationHistory.notificaciones,

            builder: (context, lista, _) {
              // ================================
              // SIN NOTIFICACIONES
              // ================================

              if (lista.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(Icons.notifications_none, size: 70, color: _acento),

                      const SizedBox(height: 16),

                      Text(
                        _t('No hay notificaciones', 'Não há notificações'),

                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),

                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _t(
                          'Tus avisos aparecerán aquí.',
                          'Seus avisos aparecerão aqui.',
                        ),

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ================================
              // LISTA DE NOTIFICACIONES
              // ================================

              return ListView.builder(
                padding: const EdgeInsets.all(12),

                itemCount: lista.length,

                itemBuilder: (context, index) {
                  final aviso = lista[index];

                  // ============================
                  // ESTADO DE LECTURA
                  // ============================

                  final leida = aviso['leida'] == true;

                  // ============================
                  // TIPO DE NOTIFICACIÓN
                  // ============================

                  final tipo = aviso['tipo']?.toString() ?? 'general';

                  // ============================
                  // TEXTOS LOCALIZADOS
                  // ============================

                  final titulo = _obtenerTitulo(aviso);

                  final detalle = _obtenerDetalle(aviso);

                  // ============================
                  // TARJETA DE NOTIFICACIÓN
                  // ============================

                  return Card(
                    color: leida ? cremaLeida : cremaNoLeida,

                    surfaceTintColor: Colors.transparent,

                    elevation: 0,

                    margin: const EdgeInsets.only(bottom: 10),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),

                      side: BorderSide(
                        color: leida ? bordeLeida : bordeNoLeida,

                        width: 1,
                      ),
                    ),

                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),

                      // ========================
                      // ÍCONO
                      // ========================
                      leading: Container(
                        width: 42,
                        height: 42,

                        decoration: BoxDecoration(
                          color: bordo.withValues(alpha: 0.08),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Icon(
                          tipo == 'gps'
                              ? Icons.location_on
                              : tipo == 'tarea'
                              ? Icons.alarm
                              : Icons.notifications_active,

                          color: bordo,
                        ),
                      ),

                      // ========================
                      // TÍTULO
                      // ========================
                      title: Text(
                        titulo,

                        style: TextStyle(
                          fontWeight: leida
                              ? FontWeight.normal
                              : FontWeight.bold,

                          color: textoPrincipal,
                          fontSize: 15,
                        ),
                      ),

                      // ========================
                      // MENSAJE
                      // ========================
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),

                        child: Text(
                          detalle,

                          style: const TextStyle(
                            color: textoSecundario,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      isThreeLine: tipo == 'tarea',

                      // ========================
                      // LEÍDA / NO LEÍDA
                      // ========================
                      trailing: leida
                          ? const Icon(
                              Icons.check_circle_outline,
                              color: verdeLeida,
                              size: 22,
                            )
                          : const Icon(Icons.circle, size: 11, color: bordo),

                      // ========================
                      // MARCAR COMO LEÍDA
                      // ========================
                      onTap: () {
                        final id = aviso['id'];

                        if (id is int) {
                          NotificationHistory.marcarLeida(id);
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
