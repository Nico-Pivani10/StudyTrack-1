import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/app_data.dart';

import '../l10n/app_localizations.dart';
import '../services/studytrack_repository.dart';

// =====================================================
// WEARABLE DE STUDYTRACK
// =====================================================
//
// Reloj circular conectado a Firebase.
//
// El aro indica el porcentaje de tiempo restante:
//
// Verde: más del 50%.
// Amarillo: entre 25% y 50%.
// Rojo: 25% o menos.
//
// El reloj y la cuenta regresiva se actualizan
// automáticamente cada segundo.
//
// Compatible con español y portugués brasileño.
//
// =====================================================

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  // =====================================================
  // COLORES DE STUDYTRACK
  // =====================================================

  static const Color bordo = Color(0xFF670810);
  static const Color coral = Color(0xFFE57373);
  static const Color rojoReloj = Color(0xFFD14F60);

  // =====================================================
  // SISTEMA DE TRADUCCIONES
  // =====================================================

  // Los textos disponibles en los archivos ARB
  // se obtienen desde AppLocalizations.
  //
  // Para los mensajes específicos del Wearable,
  // utilizamos esta función complementaria.
  //
  // Detecta automáticamente el idioma seleccionado
  // desde el Perfil de StudyTrack.

  String _t(String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;

    return idioma == 'pt' ? pt : es;
  }

  // =====================================================
  // COLORES ADAPTATIVOS
  // =====================================================

  bool _esOscuro(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _colorAcento(BuildContext context) =>
      _esOscuro(context) ? coral : bordo;

  Color _textoSobreAcento(BuildContext context) =>
      _esOscuro(context) ? Colors.black : Colors.white;

  // Conservar el color original del ícono del reloj
  // en modo claro y usar coral en modo oscuro.

  Color _colorIconoReloj(BuildContext context) =>
      _esOscuro(context) ? coral : rojoReloj;

  // =====================================================
  // COLORES DE URGENCIA
  // =====================================================

  // No cambian con el modo claro ni oscuro.

  static const Color verde = Color(0xFF37C978);
  static const Color amarillo = Color(0xFFFFD02C);
  static const Color rojo = Color(0xFFF05262);

  // =====================================================
  // FIREBASE Y TEMPORIZADOR
  // =====================================================

  Stream<AppQuerySnapshot>? _flujoTareas;

  Timer? _temporizador;

  DateTime _ahora = DateTime.now();

  bool _guardando = false;

  // Guardamos el estado del error en lugar de un texto
  // fijo para que pueda cambiar con el idioma.

  bool _errorGuardado = false;

  // =====================================================
  // INICIALIZAR EL RELOJ
  // =====================================================

  @override
  void initState() {
    super.initState();

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario != null) {
      final repositorio = StudyTrackRepository(usuario.uid);

      _flujoTareas = repositorio.escucharTareas;
    }

    // Actualizar el reloj cada segundo,
    // sin salir de la pantalla.

    _temporizador = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _ahora = DateTime.now();
      });
    });
  }

  // =====================================================
  // LIBERAR TEMPORIZADOR
  // =====================================================

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  // =====================================================
  // OBTENER FECHAS
  // =====================================================

  DateTime? _obtenerFecha(Object? valor) {
    if (valor is AppTimestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    return null;
  }

  // =====================================================
  // FORMATEAR FECHA
  // =====================================================

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');

    final mes = fecha.month.toString().padLeft(2, '0');

    // Formato válido para español y portugués BR.
    return '$dia/$mes';
  }

  // =====================================================
  // CUENTA REGRESIVA EN TIEMPO REAL
  // =====================================================

  String _textoRestante(DateTime fecha) {
    final diferencia = fecha.difference(_ahora);

    // ==========================================
    // ENTREGA VENCIDA
    // ==========================================

    if (diferencia.inMilliseconds <= 0) {
      return _t('Entrega vencida', 'Prazo vencido');
    }

    // Redondear hacia arriba para no marcar
    // una tarea como vencida antes de tiempo.

    final totalSegundos = (diferencia.inMilliseconds / 1000).ceil();

    final dias = totalSegundos ~/ 86400;

    final horas = (totalSegundos % 86400) ~/ 3600;

    final minutos = (totalSegundos % 3600) ~/ 60;

    final segundos = totalSegundos % 60;

    final hh = horas.toString().padLeft(2, '0');

    final mm = minutos.toString().padLeft(2, '0');

    final ss = segundos.toString().padLeft(2, '0');

    // ==========================================
    // TEXTO SEGÚN EL IDIOMA
    // ==========================================

    final palabraRestante = _t('Faltan', 'Restam');

    // Ejemplos:
    //
    // ES: Faltan 2d 03:12:45
    // PT: Restam 2d 03:12:45

    if (dias > 0) {
      return '$palabraRestante ${dias}d $hh:$mm:$ss';
    }

    // ES: Faltan 04:15:32
    // PT: Restam 04:15:32

    if (horas > 0) {
      return '$palabraRestante $hh:$mm:$ss';
    }

    // ES: Faltan 09:59
    // PT: Restam 09:59

    return '$palabraRestante $mm:$ss';
  }

  // =====================================================
  // CÁLCULO REAL DEL TIEMPO RESTANTE
  // =====================================================

  double? _calcularProgreso({
    required DateTime fechaEntrega,
    required DateTime? fechaCreacion,
  }) {
    // Necesitamos las dos fechas para calcular
    // correctamente el porcentaje del plazo.

    if (fechaCreacion == null) {
      return null;
    }

    // Utilizar milisegundos para mantener
    // la precisión del aro en tiempo real.

    final duracionTotal = fechaEntrega.difference(fechaCreacion).inMilliseconds;

    final tiempoRestante = fechaEntrega.difference(_ahora).inMilliseconds;

    if (duracionTotal <= 0) {
      return 0.0;
    }

    if (tiempoRestante <= 0) {
      return 0.0;
    }

    final progreso = tiempoRestante / duracionTotal;

    return progreso.clamp(0.0, 1.0);
  }

  // =====================================================
  // COLORES SEGÚN EL TIEMPO RESTANTE
  // =====================================================

  Color _colorSegunTiempo(double progreso) {
    // Más de la mitad del plazo disponible.
    if (progreso > 0.50) {
      return verde;
    }

    // Entre la mitad y la cuarta parte.
    if (progreso > 0.25) {
      return amarillo;
    }

    // Última cuarta parte del plazo.
    return rojo;
  }

  // =====================================================
  // COMPLETAR TAREA EN FIREBASE
  // =====================================================

  Future<void> _completarTarea(AppQueryDocument tarea) async {
    if (_guardando) return;

    setState(() {
      _guardando = true;
      _errorGuardado = false;
    });

    try {
      // ========================================
      // ACTUALIZAR TAREA MEDIANTE LA API
      // ========================================

      // Se mantienen los nombres originales
      // de los campos para no afectar
      // Dashboard, Tareas ni Calendario.

      await tarea.reference.update({
        'completada': true,
        'actualizadoEn': AppFieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Error al completar tarea: $error');

      if (mounted) {
        setState(() {
          _errorGuardado = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // =====================================================
  // MENSAJES DEL RELOJ
  // =====================================================

  Widget _mostrarMensaje(IconData icono, String mensaje) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icono, color: _colorIconoReloj(context), size: 35),

          const SizedBox(height: 12),

          Text(
            mensaje,
            textAlign: TextAlign.center,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // MOSTRAR UNA TAREA
  // =====================================================

  Widget _mostrarTarea(AppQueryDocument tarea) {
    final datos = tarea.data();
    final textos = AppLocalizations.of(context);

    // ==========================================
    // TÍTULO DE LA TAREA
    // ==========================================

    // Los títulos escritos por el usuario
    // se mantienen como fueron guardados.

    final titulo = datos['titulo']?.toString() ?? textos.calendarTask;

    // ==========================================
    // FECHA DE ENTREGA
    // ==========================================

    final fecha = _obtenerFecha(datos['fechaEntrega']);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,

      mainAxisSize: MainAxisSize.min,

      children: [
        // ========================================
        // ÍCONO Y NOMBRE DE LA APLICACIÓN
        // ========================================

        Icon(Icons.menu_book, color: _colorIconoReloj(context), size: 24),

        const SizedBox(height: 4),

        const Text(
          'StudyTrack',

          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        // ========================================
        // PRÓXIMA TAREA
        // ========================================
        Text(
          _t('PRÓXIMA TAREA', 'PRÓXIMA TAREFA'),

          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 5),

        // ========================================
        // NOMBRE DE LA TAREA
        // ========================================
        Text(
          titulo,

          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,

          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 5),

        // ========================================
        // FECHA DE ENTREGA TRADUCIDA
        // ========================================
        Text(
          fecha == null
              ? _t('Sin fecha de entrega', 'Sem data de entrega')
              : '${_t('Entrega', 'Entrega')}: ${_formatearFecha(fecha)}',

          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),

        // ========================================
        // CUENTA REGRESIVA CADA SEGUNDO
        // ========================================
        if (fecha != null) ...[
          const SizedBox(height: 4),

          Text(
            _textoRestante(fecha),

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: Color(0xFFFFD02C),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],

        // ========================================
        // MENSAJE DE ERROR
        // ========================================
        if (_errorGuardado) ...[
          const SizedBox(height: 4),

          Text(
            textos.errorsCouldNotSave,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.redAccent, fontSize: 10),
          ),
        ],

        const SizedBox(height: 10),

        // ========================================
        // BOTÓN COMPLETAR TAREA
        // ========================================
        SizedBox(
          width: 145,
          height: 38,

          child: ElevatedButton(
            onPressed: _guardando ? null : () => _completarTarea(tarea),

            style: ElevatedButton.styleFrom(
              backgroundColor: _colorAcento(context),

              foregroundColor: _textoSobreAcento(context),

              disabledBackgroundColor: _colorAcento(context),

              shape: const StadiumBorder(),
              padding: EdgeInsets.zero,
            ),

            child: _guardando
                ? SizedBox(
                    width: 18,
                    height: 18,

                    child: CircularProgressIndicator(
                      color: _textoSobreAcento(context),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _t('Completar', 'Concluir'),

                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // DISEÑO DEL RELOJ CIRCULAR
  // =====================================================

  Widget _reloj({required Widget contenido, double? progreso}) {
    return SizedBox(
      width: 250,
      height: 250,

      child: Stack(
        alignment: Alignment.center,

        children: [
          // ========================================
          // FONDO NEGRO DEL RELOJ
          // ========================================

          // Se conserva en ambos temas.
          const Positioned.fill(
            child: ClipOval(child: ColoredBox(color: Colors.black)),
          ),

          // ========================================
          // ARO DE PROGRESO
          // ========================================
          if (progreso != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _AroCronometroPainter(
                  progreso: progreso,

                  colorAro: _colorSegunTiempo(progreso),
                ),
              ),
            ),

          // ========================================
          // CONTENIDO DEL RELOJ
          // ========================================
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),

              child: contenido,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ESCUCHAR TAREAS DE FIREBASE
  // =====================================================

  Widget _contenidoReloj() {
    // ==========================================
    // USUARIO SIN SESIÓN
    // ==========================================

    if (_flujoTareas == null) {
      return _reloj(
        contenido: _mostrarMensaje(
          Icons.lock_outline,

          _t('Iniciá sesión', 'Entre na sua conta'),
        ),
      );
    }

    // ==========================================
    // ESCUCHA DE LA API
    // ==========================================

    return StreamBuilder<AppQuerySnapshot>(
      stream: _flujoTareas,

      builder: (context, snapshot) {
        // ======================================
        // ERROR AL CARGAR TAREAS
        // ======================================

        if (snapshot.hasError) {
          return _reloj(
            contenido: _mostrarMensaje(
              Icons.error_outline,

              _t('Error al cargar tareas', 'Erro ao carregar tarefas'),
            ),
          );
        }

        // ======================================
        // CARGANDO DATOS
        // ======================================

        if (!snapshot.hasData) {
          return _reloj(
            contenido: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // ======================================
        // OBTENER TAREAS PENDIENTES
        // ======================================

        final tareasPendientes = snapshot.data!.docs
            .where((tarea) => tarea.data()['completada'] != true)
            .toList();

        // ======================================
        // ORDENAR POR FECHA DE ENTREGA
        // ======================================

        tareasPendientes.sort((a, b) {
          final fechaA = _obtenerFecha(a.data()['fechaEntrega']);

          final fechaB = _obtenerFecha(b.data()['fechaEntrega']);

          if (fechaA == null && fechaB == null) {
            return 0;
          }

          if (fechaA == null) return 1;
          if (fechaB == null) return -1;

          return fechaA.compareTo(fechaB);
        });

        // ======================================
        // SIN TAREAS PENDIENTES
        // ======================================

        if (tareasPendientes.isEmpty) {
          return _reloj(
            contenido: _mostrarMensaje(
              Icons.check_circle_outline,

              _t('¡Todo al día!', 'Tudo em dia!'),
            ),
          );
        }

        // ======================================
        // SELECCIONAR LA TAREA MÁS PRÓXIMA
        // ======================================

        final tarea = tareasPendientes.first;

        final datos = tarea.data();

        final fechaEntrega = _obtenerFecha(datos['fechaEntrega']);

        final fechaCreacion = _obtenerFecha(datos['creadaEn']);

        double? progreso;

        if (fechaEntrega != null) {
          progreso = _calcularProgreso(
            fechaEntrega: fechaEntrega,
            fechaCreacion: fechaCreacion,
          );
        }

        // ======================================
        // RELOJ CON TAREA Y PROGRESO
        // ======================================

        return _reloj(contenido: _mostrarTarea(tarea), progreso: progreso);
      },
    );
  }

  // =====================================================
  // PANTALLA PRINCIPAL
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Modo claro: fondo gris original.
      // Modo oscuro: fondo oscuro de StudyTrack.

      backgroundColor: _esOscuro(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFECECEC),

      body: Center(child: _contenidoReloj()),
    );
  }
}

// =====================================================
// ARO CIRCULAR CON MARCAS Y COLORES
// =====================================================

class _AroCronometroPainter extends CustomPainter {
  final double progreso;
  final Color colorAro;

  const _AroCronometroPainter({required this.progreso, required this.colorAro});

  // =====================================================
  // DIBUJAR EL ARO
  // =====================================================

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);

    final radio = math.min(size.width, size.height) / 2 - 13;

    // ==========================================
    // MARCAS DEL RELOJ
    // ==========================================

    final pinturaMarcas = Paint()
      ..color = const Color(0xFF514851)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 72; i++) {
      final angulo = (i * 2 * math.pi / 72) - math.pi / 2;

      final marcaLarga = i % 6 == 0;

      final radioInicio = radio - (marcaLarga ? 5.0 : 3.0);

      final radioFin = radio + 4;

      final inicio = Offset(
        centro.dx + radioInicio * math.cos(angulo),

        centro.dy + radioInicio * math.sin(angulo),
      );

      final fin = Offset(
        centro.dx + radioFin * math.cos(angulo),

        centro.dy + radioFin * math.sin(angulo),
      );

      canvas.drawLine(inicio, fin, pinturaMarcas);
    }

    // ==========================================
    // ARCO DE TIEMPO RESTANTE
    // ==========================================

    if (progreso > 0) {
      final rectangulo = Rect.fromCircle(center: centro, radius: radio);

      final pinturaAro = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = colorAro;

      canvas.drawArc(
        rectangulo,
        -math.pi / 2,

        2 * math.pi * progreso.clamp(0.0, 1.0),

        false,
        pinturaAro,
      );
    }
  }

  // =====================================================
  // ACTUALIZAR CUANDO CAMBIA EL PROGRESO
  // =====================================================

  @override
  bool shouldRepaint(covariant _AroCronometroPainter anterior) {
    return anterior.progreso != progreso || anterior.colorAro != colorAro;
  }
}
