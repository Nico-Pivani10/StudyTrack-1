import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';
import '../services/studytrack_repository.dart';

import 'materias_screen.dart';
import 'calendario_screen.dart';
import 'gps_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'wearable_screen.dart';
import 'tasks_screen.dart';
import 'notifications_screen.dart';

// Alias para los documentos de Firestore.
typedef _Documentos = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

// Actividad utilizada para mostrar el resumen.
class _ActividadResumen {
  final String titulo;
  final String tipo;
  final DateTime fecha;

  const _ActividadResumen({
    required this.titulo,
    required this.tipo,
    required this.fecha,
  });
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Bordó institucional en ambas barras superiores.
  static const Color bordo = Color(0xFF670810);

  // ============================================
  // COLORES ADAPTATIVOS
  // ============================================

  Color _colorAcento(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return esOscuro ? const Color(0xFFE57373) : bordo;
  }

  Color _fondoIcono(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return esOscuro
        ? const Color(0xFFE57373).withValues(alpha: 0.16)
        : const Color(0xFFF4E9EB);
  }

  // ============================================
  // TRADUCCIONES ADICIONALES
  // ============================================

  // Los textos existentes en ARB usan AppLocalizations.
  // Esta función cubre los mensajes que todavía
  // no tienen una clave en los archivos ARB.
  String _t(BuildContext context, String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;
    return idioma == 'pt' ? pt : es;
  }

  // Traducción con singular y plural.
  String _textoTareasCompletadas(
    BuildContext context,
    int completadas,
    int total,
  ) {
    final etiqueta = total == 1
        ? _t(context, 'tarea completada', 'tarefa concluída')
        : _t(context, 'tareas completadas', 'tarefas concluídas');

    return '$completadas de $total $etiqueta';
  }

  // ============================================
  // USUARIO AUTENTICADO
  // ============================================

  String _obtenerNombre(User usuario, BuildContext context) {
    final nombre = usuario.displayName?.trim();

    if (nombre != null && nombre.isNotEmpty) {
      return nombre.split(' ').first;
    }

    final correo = usuario.email;

    if (correo != null && correo.contains('@')) {
      return correo.split('@').first;
    }

    return _t(context, 'Estudiante', 'Estudante');
  }

  // ============================================
  // NAVEGACIÓN
  // ============================================

  void _abrirPantalla(BuildContext context, Widget pantalla) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => pantalla));
  }

  void _navegar(BuildContext context, int indice) {
    switch (indice) {
      case 1:
        _abrirPantalla(context, const MateriasScreen());
        break;

      case 2:
        _abrirPantalla(context, const TasksScreen());
        break;

      case 3:
        _abrirPantalla(context, const CalendarioScreen());
        break;

      case 4:
        _abrirPantalla(context, const ProfileScreen());
        break;
    }
  }

  // ============================================
  // FUNCIONES DE FECHA
  // ============================================

  DateTime? _convertirFecha(Object? valor) {
    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    return null;
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year} - $hora:$minuto';
  }

  // ============================================
  // PANTALLA PRINCIPAL
  // ============================================

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final tema = Theme.of(context);
    final textos = AppLocalizations.of(context);

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('StudyTrack'),
          backgroundColor: bordo,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            _t(
              context,
              'Iniciá sesión para consultar tu Dashboard.',
              'Entre na sua conta para acessar o painel.',
            ),
          ),
        ),
      );
    }

    final repositorio = StudyTrackRepository(usuario.uid);

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: bordo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'StudyTrack',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _t(context, 'Simular reloj', 'Simular relógio'),
            icon: const Icon(Icons.watch),
            onPressed: () {
              _abrirPantalla(context, const WearableScreen());
            },
          ),

          IconButton(
            tooltip: textos.quickNotifications,
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              _abrirPantalla(context, const NotificationsScreen());
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // SALUDO TRADUCIDO
          Text(
            '${textos.dashboardWelcome(_obtenerNombre(usuario, context))} 👋',
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(textos.dashboardSubtitle, style: tema.textTheme.bodyMedium),

          const SizedBox(height: 26),

          // ACCESOS RÁPIDOS
          _tituloSeccion(context, textos.dashboardQuickAccess),

          const SizedBox(height: 14),

          _accesosRapidos(context),

          const SizedBox(height: 28),

          // RESUMEN ACADÉMICO
          _resumenAcademico(context, repositorio),

          const SizedBox(height: 10),

          // META SEMANAL
          _metaSemanal(context, repositorio),

          const SizedBox(height: 20),
        ],
      ),

      // ========================================
      // NAVEGACIÓN INFERIOR TRADUCIDA
      // ========================================
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: _colorAcento(context),
        unselectedItemColor: tema.colorScheme.onSurfaceVariant,
        backgroundColor: tema.colorScheme.surface,
        onTap: (indice) => _navegar(context, indice),

        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: textos.navHome,
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            label: textos.navSubjects,
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.check_box_outlined),
            label: textos.navTasks,
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_month_outlined),
            label: textos.navCalendar,
          ),

          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: textos.navProfile,
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACCESOS RÁPIDOS: QR Y GPS
  // ============================================

  Widget _accesosRapidos(BuildContext context) {
    final textos = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _tarjetaAcceso(
            context,
            icono: Icons.qr_code_scanner,
            titulo: textos.quickQrScanner,
            descripcion: _t(context, 'Cámara y códigos', 'Câmera e códigos'),
            onTap: () {
              _abrirPantalla(context, const QrScannerScreen());
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _tarjetaAcceso(
            context,
            icono: Icons.map_outlined,
            titulo: textos.quickGps,
            descripcion: _t(
              context,
              'Ubicación y rutas',
              'Localização e rotas',
            ),
            onTap: () {
              _abrirPantalla(context, const GpsScreen());
            },
          ),
        ),
      ],
    );
  }

  Widget _tarjetaAcceso(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        child: SizedBox(
          height: 145,

          child: Padding(
            padding: const EdgeInsets.all(12),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: _fondoIcono(context),
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Icon(icono, color: _colorAcento(context), size: 30),
                ),

                const SizedBox(height: 10),

                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  descripcion,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // RESUMEN DE FIRESTORE
  // ============================================

  Widget _resumenAcademico(
    BuildContext context,
    StudyTrackRepository repositorio,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: repositorio.escucharMaterias,

      builder: (context, materiasSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repositorio.escucharTareas,

          builder: (context, tareasSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: repositorio.escucharExamenes,

              builder: (context, examenesSnapshot) {
                final error =
                    materiasSnapshot.hasError ||
                    tareasSnapshot.hasError ||
                    examenesSnapshot.hasError;

                if (error) {
                  return _mensajeEstado(
                    context,
                    Icons.error_outline,
                    _t(
                      context,
                      'No se pudieron cargar los datos.',
                      'Não foi possível carregar os dados.',
                    ),
                    _t(
                      context,
                      'Revisá la conexión y las reglas de Firestore.',
                      'Verifique a conexão e as regras do Firestore.',
                    ),
                  );
                }

                if (!materiasSnapshot.hasData ||
                    !tareasSnapshot.hasData ||
                    !examenesSnapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(30),

                    child: Center(
                      child: CircularProgressIndicator(
                        color: _colorAcento(context),
                      ),
                    ),
                  );
                }

                final materias = materiasSnapshot.data!.docs;

                final tareas = tareasSnapshot.data!.docs;

                final examenes = examenesSnapshot.data!.docs;

                return _contenidoResumen(context, materias, tareas, examenes);
              },
            );
          },
        );
      },
    );
  }

  Widget _contenidoResumen(
    BuildContext context,
    _Documentos materias,
    _Documentos tareas,
    _Documentos examenes,
  ) {
    final textos = AppLocalizations.of(context);

    final completadas = tareas
        .where((tarea) => tarea.data()['completada'] == true)
        .length;

    final progreso = tareas.isEmpty ? 0.0 : completadas / tareas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _tituloSeccion(context, textos.dashboardAcademicSummary),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _tarjetaContador(
                icono: Icons.check_circle_outline,
                numero: tareas.length,
                titulo: textos.navTasks,
                color: Colors.green,
                onTap: () => _navegar(context, 2),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _tarjetaContador(
                icono: Icons.event_note_outlined,
                numero: examenes.length,
                titulo: _t(context, 'Exámenes', 'Provas'),
                color: Colors.orange,
                onTap: () => _navegar(context, 3),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _tarjetaContador(
                icono: Icons.menu_book_outlined,
                numero: materias.length,
                titulo: textos.navSubjects,
                color: _colorAcento(context),
                onTap: () => _navegar(context, 1),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // MATERIAS DEL ESTUDIANTE
        _encabezadoConAccion(
          context,
          titulo: textos.subjectsTitle,
          accion: textos.dashboardViewAll,
          onPressed: () => _navegar(context, 1),
        ),

        const SizedBox(height: 12),

        _resumenMaterias(context, materias, tareas),

        const SizedBox(height: 28),

        // PROGRESO GENERAL
        _tituloSeccion(context, textos.dashboardTaskProgress),

        const SizedBox(height: 12),

        _tarjetaProgreso(
          context,
          total: tareas.length,
          completadas: completadas,
          progreso: progreso,
        ),

        const SizedBox(height: 28),

        // PRÓXIMAS ACTIVIDADES
        _encabezadoConAccion(
          context,
          titulo: textos.dashboardUpcomingActivities,
          accion: textos.dashboardViewCalendar,
          onPressed: () => _navegar(context, 3),
        ),

        const SizedBox(height: 12),

        _resumenActividades(context, tareas, examenes),

        const SizedBox(height: 24),
      ],
    );
  }

  // ============================================
  // CONTADORES
  // ============================================

  Widget _tarjetaContador({
    required IconData icono,
    required int numero,
    required String titulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),

          child: Column(
            children: [
              Icon(icono, color: color, size: 28),

              const SizedBox(height: 8),

              Text(
                '$numero',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // RESUMEN DE MATERIAS
  // ============================================

  Widget _resumenMaterias(
    BuildContext context,
    _Documentos materias,
    _Documentos tareas,
  ) {
    final textos = AppLocalizations.of(context);

    if (materias.isEmpty) {
      return _mensajeEstado(
        context,
        Icons.menu_book_outlined,
        textos.subjectsNone,
        _t(
          context,
          'Entrá en Materias para registrar la primera.',
          'Acesse Disciplinas para cadastrar a primeira.',
        ),
      );
    }

    final lista = [...materias];

    lista.sort((a, b) {
      final nombreA = a.data()['nombre']?.toString().toLowerCase() ?? '';

      final nombreB = b.data()['nombre']?.toString().toLowerCase() ?? '';

      return nombreA.compareTo(nombreB);
    });

    return Column(
      children: lista.take(3).map((materia) {
        final nombre =
            materia.data()['nombre']?.toString() ??
            _t(context, 'Materia', 'Disciplina');

        final tareasMateria = tareas.where(
          (tarea) => tarea.data()['materiaId'] == materia.id,
        );

        final totalTareas = tareasMateria.length;

        final completadas = tareasMateria
            .where((tarea) => tarea.data()['completada'] == true)
            .length;

        final progreso = totalTareas == 0 ? 0.0 : completadas / totalTareas;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),

          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navegar(context, 1),

            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _fondoIcono(context),

                        child: Icon(
                          Icons.menu_book_outlined,
                          color: _colorAcento(context),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Icon(Icons.chevron_right, color: _colorAcento(context)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    totalTareas == 0
                        ? textos.subjectsNoTasks
                        : _textoTareasCompletadas(
                            context,
                            completadas,
                            totalTareas,
                          ),

                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                  const SizedBox(height: 9),

                  LinearProgressIndicator(
                    value: progreso,
                    minHeight: 7,
                    color: _colorAcento(context),

                    backgroundColor: _colorAcento(context).withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.22
                          : 0.12,
                    ),

                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // PROGRESO GENERAL
  // ============================================

  Widget _tarjetaProgreso(
    BuildContext context, {
    required int total,
    required int completadas,
    required double progreso,
  }) {
    final textos = AppLocalizations.of(context);
    final porcentaje = (progreso * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              total == 0
                  ? textos.dashboardNoTasks
                  : _textoTareasCompletadas(context, completadas, total),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 9,
                    color: _colorAcento(context),

                    backgroundColor: _colorAcento(context).withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.22
                          : 0.12,
                    ),

                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  '$porcentaje%',
                  style: TextStyle(
                    color: _colorAcento(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              _t(
                context,
                'El progreso se calcula según las tareas marcadas como completadas.',
                'O progresso é calculado com base nas tarefas marcadas como concluídas.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // PRÓXIMAS ACTIVIDADES
  // ============================================

  Widget _resumenActividades(
    BuildContext context,
    _Documentos tareas,
    _Documentos examenes,
  ) {
    final textos = AppLocalizations.of(context);
    final actividades = <_ActividadResumen>[];
    final ahora = DateTime.now();

    // TAREAS PENDIENTES
    for (final tarea in tareas) {
      final datos = tarea.data();

      if (datos['completada'] == true) continue;

      final fecha = _convertirFecha(datos['fechaEntrega']);

      if (fecha == null || fecha.isBefore(ahora)) {
        continue;
      }

      actividades.add(
        _ActividadResumen(
          titulo: datos['titulo']?.toString() ?? textos.calendarTask,
          tipo: 'Tarea',
          fecha: fecha,
        ),
      );
    }

    // EXÁMENES
    for (final examen in examenes) {
      final datos = examen.data();

      final fecha = _convertirFecha(datos['fecha']);

      if (fecha == null || fecha.isBefore(ahora)) {
        continue;
      }

      actividades.add(
        _ActividadResumen(
          titulo: datos['titulo']?.toString() ?? textos.calendarExam,
          tipo: 'Examen',
          fecha: fecha,
        ),
      );
    }

    actividades.sort((a, b) => a.fecha.compareTo(b.fecha));

    if (actividades.isEmpty) {
      return _mensajeEstado(
        context,
        Icons.event_available_outlined,
        textos.dashboardNoEvents,
        _t(
          context,
          'Las entregas y exámenes aparecerán aquí.',
          'Os prazos de entrega e as provas aparecerão aqui.',
        ),
      );
    }

    return Column(
      children: actividades.take(3).map((actividad) {
        // El tipo interno permanece igual.
        final esExamen = actividad.tipo == 'Examen';

        final tipoTraducido = esExamen
            ? textos.calendarExam
            : textos.calendarTask;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),

          child: ListTile(
            onTap: () => _navegar(context, esExamen ? 3 : 2),

            leading: CircleAvatar(
              backgroundColor: _fondoIcono(context),
              child: Icon(
                esExamen ? Icons.school_outlined : Icons.assignment_outlined,
                color: _colorAcento(context),
              ),
            ),

            title: Text(
              actividad.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            subtitle: Text(
              '$tipoTraducido · ${_formatearFecha(actividad.fecha)}',
            ),

            trailing: const Icon(Icons.chevron_right),
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // META SEMANAL
  // ============================================

  Widget _metaSemanal(BuildContext context, StudyTrackRepository repositorio) {
    final textos = AppLocalizations.of(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repositorio.escucharUsuario,

      builder: (context, usuarioSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repositorio.escucharSesiones,

          builder: (context, sesionesSnapshot) {
            if (usuarioSnapshot.hasError || sesionesSnapshot.hasError) {
              return _mensajeEstado(
                context,
                Icons.error_outline,
                _t(
                  context,
                  'No se pudo cargar la meta semanal.',
                  'Não foi possível carregar a meta semanal.',
                ),
                _t(
                  context,
                  'Revisá la conexión con Firestore.',
                  'Verifique a conexão com o Firestore.',
                ),
              );
            }

            if (!usuarioSnapshot.hasData || !sesionesSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final datos = usuarioSnapshot.data!.data();

            final valorMeta = datos?['metaSemanalDias'];

            final metaDias = valorMeta is num
                ? valorMeta.toInt().clamp(1, 7)
                : 5;

            final ahora = DateTime.now();

            final inicioSemana = DateTime(
              ahora.year,
              ahora.month,
              ahora.day,
            ).subtract(Duration(days: ahora.weekday - 1));

            final finSemana = inicioSemana.add(const Duration(days: 7));

            final dias = <String>{};
            int minutos = 0;

            for (final sesion in sesionesSnapshot.data!.docs) {
              final datosSesion = sesion.data();

              final fecha = _convertirFecha(datosSesion['fecha']);

              if (fecha == null ||
                  fecha.isBefore(inicioSemana) ||
                  !fecha.isBefore(finSemana)) {
                continue;
              }

              dias.add('${fecha.year}-${fecha.month}-${fecha.day}');

              final valorMinutos = datosSesion['minutos'];

              if (valorMinutos is num) {
                minutos += valorMinutos.toInt();
              }
            }

            final progreso = (dias.length / metaDias).clamp(0.0, 1.0);

            final etiquetaDias = metaDias == 1
                ? _t(context, 'día', 'dia')
                : _t(context, 'días', 'dias');

            final etiquetaMinutos = minutos == 1 ? 'minuto' : 'minutos';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                _tituloSeccion(context, textos.dashboardWeeklyGoal),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                textos.dashboardDaysStudied,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Icon(
                              Icons.emoji_events_outlined,
                              color: _colorAcento(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Text(
                          '${dias.length}/$metaDias $etiquetaDias',
                          style: TextStyle(
                            fontSize: 23,
                            color: _colorAcento(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        LinearProgressIndicator(
                          value: progreso,
                          minHeight: 8,
                          color: _colorAcento(context),

                          backgroundColor: _colorAcento(context).withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.22
                                : 0.12,
                          ),

                          borderRadius: BorderRadius.circular(10),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          '${_t(context, 'Tiempo registrado esta semana:', 'Tempo registrado nesta semana:')} $minutos $etiquetaMinutos.',
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _t(
                            context,
                            'Resumen de las sesiones de estudio registradas.',
                            'Resumo das sessões de estudo registradas.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================
  // COMPONENTES VISUALES REUTILIZABLES
  // ============================================

  Widget _tituloSeccion(BuildContext context, String titulo) {
    return Text(
      titulo,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _encabezadoConAccion(
    BuildContext context, {
    required String titulo,
    required String accion,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [
        Flexible(child: _tituloSeccion(context, titulo)),

        TextButton(
          onPressed: onPressed,

          child: Text(
            accion,
            style: TextStyle(
              color: _colorAcento(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mensajeEstado(
    BuildContext context,
    IconData icono,
    String titulo,
    String descripcion,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Center(
          child: Column(
            children: [
              Icon(icono, size: 46, color: _colorAcento(context)),

              const SizedBox(height: 14),

              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                descripcion,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

 

 
  
