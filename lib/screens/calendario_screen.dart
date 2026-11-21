import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/studytrack_repository.dart';

// =========================================================
// COLORES ADAPTATIVOS DE STUDYTRACK
// =========================================================

const Color _bordo = Color(0xFF670810);
const Color _coralOscuro = Color(0xFFE57373);

// Detectar el modo oscuro.
bool _esOscuro(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// Bordó en modo claro y coral en modo oscuro.
Color _colorAcento(BuildContext context) =>
    _esOscuro(context) ? _coralOscuro : _bordo;

// Fondo suave para íconos y avatares.
Color _fondoIcono(BuildContext context) => _esOscuro(context)
    ? _coralOscuro.withValues(alpha: 0.16)
    : const Color(0xFFF4E9EB);

// Contraste sobre botones y días seleccionados.
Color _textoSobreAcento(BuildContext context) =>
    _esOscuro(context) ? Colors.black : Colors.white;

// =========================================================
// SISTEMA DE TRADUCCIONES
// =========================================================

// Obtener el idioma seleccionado en StudyTrack.
String _idiomaCalendario(BuildContext context) {
  final idioma = Localizations.localeOf(context).languageCode;

  return idioma == 'pt' ? 'pt_BR' : 'es';
}

// Traducciones complementarias para mensajes
// que todavía no tienen una clave en los ARB.
String _t(BuildContext context, String es, String pt) {
  return _idiomaCalendario(context) == 'pt_BR' ? pt : es;
}

// Formato numérico de fecha y hora.
String _fechaTexto(BuildContext context, DateTime fecha) {
  return DateFormat(
    'dd/MM/yyyy HH:mm',
    _idiomaCalendario(context),
  ).format(fecha);
}

// Fecha escrita con el día y el mes traducidos.
String _fechaDiaSeleccionado(BuildContext context, DateTime fecha) {
  return DateFormat(
    "EEEE d 'de' MMMM",
    _idiomaCalendario(context),
  ).format(fecha);
}

// =========================================================
// DOCUMENTOS Y FUNCIONES DE FECHA
// =========================================================

typedef _Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

DateTime? _leerFecha(dynamic valor) {
  if (valor is Timestamp) {
    return valor.toDate();
  }

  if (valor is DateTime) {
    return valor;
  }

  return null;
}

// =========================================================
// MODELO DE EVENTO
// =========================================================

class _Evento {
  final String titulo;
  final DateTime fecha;
  final bool esExamen;
  final bool completada;

  final QueryDocumentSnapshot<Map<String, dynamic>>? examen;

  const _Evento({
    required this.titulo,
    required this.fecha,
    required this.esExamen,
    this.completada = false,
    this.examen,
  });
}

// =========================================================
// PANTALLA DE CALENDARIO
// =========================================================

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _diaEnfocado = DateTime.now();

  CalendarFormat _formato = CalendarFormat.month;

  StudyTrackRepository? _repositorio;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _materiasStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _tareasStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _examenesStream;

  // =====================================================
  // INICIALIZACIÓN
  // =====================================================

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      _repositorio = StudyTrackRepository(uid);

      _materiasStream = _repositorio!.escucharMaterias;

      _tareasStream = _repositorio!.escucharTareas;

      _examenesStream = _repositorio!.escucharExamenes;
    }
  }

  // =====================================================
  // MOSTRAR MENSAJES
  // =====================================================

  void _mensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // =====================================================
  // OBTENER EVENTOS DE FIRESTORE
  // =====================================================

  List<_Evento> _obtenerEventos(_Docs tareas, _Docs examenes) {
    final textos = AppLocalizations.of(context);

    final eventos = <_Evento>[];

    // ==========================================
    // TAREAS
    // ==========================================

    for (final tarea in tareas) {
      final datos = tarea.data();

      final fecha = _leerFecha(datos['fechaEntrega']);

      if (fecha == null) continue;

      eventos.add(
        _Evento(
          titulo: datos['titulo']?.toString() ?? textos.calendarTask,
          fecha: fecha,
          esExamen: false,
          completada: datos['completada'] == true,
        ),
      );
    }

    // ==========================================
    // EXÁMENES
    // ==========================================

    for (final examen in examenes) {
      final datos = examen.data();

      final fecha = _leerFecha(datos['fecha']);

      if (fecha == null) continue;

      eventos.add(
        _Evento(
          titulo: datos['titulo']?.toString() ?? textos.calendarExam,
          fecha: fecha,
          esExamen: true,
          examen: examen,
        ),
      );
    }

    // Ordenar cronológicamente.
    eventos.sort((a, b) => a.fecha.compareTo(b.fecha));

    return eventos;
  }

  // =====================================================
  // CREAR O EDITAR EXAMEN
  // =====================================================

  Future<void> _abrirFormulario(
    _Docs materias, {
    QueryDocumentSnapshot<Map<String, dynamic>>? examen,
  }) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioExamen(
        repositorio: _repositorio!,
        materias: materias,
        fechaInicial: _diaSeleccionado,
        examen: examen,
      ),
    );

    if (!mounted) return;

    if (guardado == true) {
      _mensaje(AppLocalizations.of(context).calendarExamSaved);
    }
  }

  // =====================================================
  // ELIMINAR EXAMEN
  // =====================================================

  Future<void> _eliminarExamen(
    QueryDocumentSnapshot<Map<String, dynamic>> examen,
  ) async {
    final textos = AppLocalizations.of(context);

    final confirmar = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => AlertDialog(
        title: Text(textos.calendarDeleteExam),

        content: Text(
          _t(
            dialogContext,
            '¿Querés eliminar este examen definitivamente?',
            'Deseja excluir esta prova permanentemente?',
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(textos.commonCancel),
          ),

          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              textos.commonDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmar != true) return;

    try {
      await _repositorio!.eliminarExamen(examen.id);

      if (!mounted) return;

      _mensaje(AppLocalizations.of(context).calendarExamDeleted);
    } catch (error) {
      if (!mounted) return;

      _mensaje(
        '${_t(context, 'No se pudo eliminar', 'Não foi possível excluir')}: $error',
      );
    }
  }

  // =====================================================
  // CONSTRUCCIÓN PRINCIPAL
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);

    // ==========================================
    // USUARIO SIN SESIÓN
    // ==========================================

    if (_repositorio == null) {
      return Scaffold(body: Center(child: Text(textos.errorsNotSignedIn)));
    }

    return Scaffold(
      // ========================================
      // APPBAR INSTITUCIONAL
      // ========================================

      appBar: AppBar(
        title: Text(textos.calendarTitle),

        backgroundColor: _bordo,
        foregroundColor: Colors.white,
      ),

      // ========================================
      // DATOS DE FIRESTORE
      // ========================================
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _materiasStream,

        builder: (context, materiasSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _tareasStream,

            builder: (context, tareasSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _examenesStream,

                builder: (context, examenesSnapshot) {
                  final error =
                      materiasSnapshot.hasError ||
                      tareasSnapshot.hasError ||
                      examenesSnapshot.hasError;

                  if (error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),

                        child: Text(
                          _t(
                            context,
                            'No se pudieron cargar los eventos. '
                                'Revisá la conexión y Firestore.',
                            'Não foi possível carregar os eventos. '
                                'Verifique a conexão com o Firestore.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!materiasSnapshot.hasData ||
                      !tareasSnapshot.hasData ||
                      !examenesSnapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: _colorAcento(context),
                      ),
                    );
                  }

                  final materias = materiasSnapshot.data!.docs;

                  final tareas = tareasSnapshot.data!.docs;

                  final examenes = examenesSnapshot.data!.docs;

                  final eventos = _obtenerEventos(tareas, examenes);

                  return _contenidoCalendario(materias, eventos);
                },
              );
            },
          );
        },
      ),
    );
  }

  // =====================================================
  // CONTENIDO DEL CALENDARIO
  // =====================================================

  Widget _contenidoCalendario(_Docs materias, List<_Evento> eventos) {
    final tema = Theme.of(context);
    final textos = AppLocalizations.of(context);

    final textoColor = tema.colorScheme.onSurface;

    // ==========================================
    // ACTIVIDADES DEL DÍA SELECCIONADO
    // ==========================================

    final eventosDelDia = eventos
        .where((evento) => isSameDay(evento.fecha, _diaSeleccionado))
        .toList();

    // ==========================================
    // PRÓXIMAS ACTIVIDADES
    // ==========================================

    final proximos = eventos
        .where(
          (evento) =>
              evento.fecha.isAfter(DateTime.now()) &&
              !evento.completada &&
              !isSameDay(evento.fecha, _diaSeleccionado),
        )
        .take(4)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        // ======================================
        // TÍTULO DEL CALENDARIO
        // ======================================

        Text(
          _t(context, 'Mi calendario', 'Meu calendário'),

          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(textos.calendarSubtitle),

        const SizedBox(height: 16),

        // ======================================
        // CAMBIAR ENTRE MES Y SEMANA
        // ======================================
        Row(
          mainAxisAlignment: MainAxisAlignment.end,

          children: [
            SegmentedButton<CalendarFormat>(
              segments: [
                ButtonSegment<CalendarFormat>(
                  value: CalendarFormat.month,
                  label: Text(textos.calendarMonth),
                  icon: const Icon(Icons.calendar_month),
                ),

                ButtonSegment<CalendarFormat>(
                  value: CalendarFormat.week,
                  label: Text(textos.calendarWeek),
                  icon: const Icon(Icons.view_week),
                ),
              ],

              selected: {_formato},

              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _colorAcento(context),

                selectedForegroundColor: _textoSobreAcento(context),

                foregroundColor: textoColor,
              ),

              onSelectionChanged: (seleccion) {
                setState(() {
                  _formato = seleccion.first;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ======================================
        // CALENDARIO INTERACTIVO
        // ======================================
        Card(
          margin: EdgeInsets.zero,

          child: Padding(
            padding: const EdgeInsets.all(8),

            child: TableCalendar<_Evento>(
              // =================================
              // IDIOMA DINÁMICO
              // =================================

              locale: _idiomaCalendario(context),

              firstDay: DateTime(2020),
              lastDay: DateTime(2100),

              focusedDay: _diaEnfocado,
              calendarFormat: _formato,

              startingDayOfWeek: StartingDayOfWeek.monday,

              // =================================
              // DÍA SELECCIONADO
              // =================================
              selectedDayPredicate: (fecha) {
                return isSameDay(_diaSeleccionado, fecha);
              },

              // =================================
              // EVENTOS DEL DÍA
              // =================================
              eventLoader: (dia) {
                return eventos
                    .where((evento) => isSameDay(evento.fecha, dia))
                    .toList();
              },

              // =================================
              // SELECCIÓN DE DÍA
              // =================================
              onDaySelected: (seleccionado, enfocado) {
                setState(() {
                  _diaSeleccionado = seleccionado;
                  _diaEnfocado = enfocado;
                });
              },

              // =================================
              // CAMBIO DE MES
              // =================================
              onPageChanged: (enfocado) {
                setState(() {
                  _diaEnfocado = enfocado;
                });
              },

              // =================================
              // CAMBIO DE FORMATO
              // =================================
              onFormatChanged: (formato) {
                setState(() {
                  _formato = formato;
                });
              },

              // =================================
              // DÍAS DE LA SEMANA
              // =================================
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: textoColor,
                  fontWeight: FontWeight.w500,
                ),

                weekendStyle: TextStyle(
                  color: textoColor,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // =================================
              // ENCABEZADO DEL CALENDARIO
              // =================================
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,

                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textoColor,
                ),

                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: _colorAcento(context),
                ),

                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: _colorAcento(context),
                ),
              ),

              // =================================
              // COLORES DEL CALENDARIO
              // =================================
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,

                defaultTextStyle: TextStyle(color: textoColor),

                weekendTextStyle: TextStyle(color: textoColor),

                // Día seleccionado.
                selectedDecoration: BoxDecoration(
                  color: _colorAcento(context),
                  shape: BoxShape.circle,
                ),

                selectedTextStyle: TextStyle(
                  color: _textoSobreAcento(context),
                  fontWeight: FontWeight.bold,
                ),

                // Día actual.
                todayDecoration: BoxDecoration(
                  color: _colorAcento(
                    context,
                  ).withValues(alpha: _esOscuro(context) ? 0.22 : 0.35),
                  shape: BoxShape.circle,
                ),

                todayTextStyle: TextStyle(
                  color: textoColor,
                  fontWeight: FontWeight.bold,
                ),

                // Puntos de tareas y exámenes.
                markerDecoration: BoxDecoration(
                  color: _colorAcento(context),
                  shape: BoxShape.circle,
                ),

                markersMaxCount: 3,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ======================================
        // ACTIVIDADES DEL DÍA
        // ======================================
        Row(
          children: [
            Expanded(
              child: Text(
                _fechaDiaSeleccionado(context, _diaSeleccionado),

                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ElevatedButton.icon(
              onPressed: () => _abrirFormulario(materias),

              style: ElevatedButton.styleFrom(
                backgroundColor: _colorAcento(context),

                foregroundColor: _textoSobreAcento(context),
              ),

              icon: const Icon(Icons.add),

              label: Text(textos.calendarExam),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ======================================
        // ESTADO SIN ACTIVIDADES
        // ======================================
        if (eventosDelDia.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),

              child: Column(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: _colorAcento(context),
                    size: 42,
                  ),

                  const SizedBox(height: 10),

                  Text(textos.calendarNoEvents, textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          ...eventosDelDia.map((evento) => _tarjetaEvento(evento, materias)),

        const SizedBox(height: 24),

        // ======================================
        // PRÓXIMAS ACTIVIDADES
        // ======================================
        Text(
          textos.dashboardUpcomingActivities,

          style: tema.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (proximos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Text(textos.calendarNoUpcoming),
            ),
          )
        else
          ...proximos.map((evento) => _tarjetaEvento(evento, materias)),

        const SizedBox(height: 16),
      ],
    );
  }

  // =====================================================
  // TARJETA DE TAREA O EXAMEN
  // =====================================================

  Widget _tarjetaEvento(_Evento evento, _Docs materias) {
    final textos = AppLocalizations.of(context);

    final tipoEvento = evento.esExamen
        ? textos.calendarExam
        : textos.calendarTask;

    final estadoCompletada = evento.completada
        ? _t(context, ' · Completada', ' · Concluída')
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),

      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _fondoIcono(context),

          child: Icon(
            evento.esExamen ? Icons.school_outlined : Icons.assignment_outlined,

            color: _colorAcento(context),
          ),
        ),

        title: Text(
          evento.titulo,

          style: TextStyle(
            fontWeight: FontWeight.bold,

            decoration: evento.completada ? TextDecoration.lineThrough : null,
          ),
        ),

        subtitle: Text(
          '$tipoEvento'
          ' · ${_fechaTexto(context, evento.fecha)}'
          '$estadoCompletada',
        ),

        // ======================================
        // OPCIONES DE EXAMEN
        // ======================================
        trailing: evento.examen == null
            ? null
            : PopupMenuButton<String>(
                onSelected: (opcion) {
                  if (opcion == 'editar') {
                    _abrirFormulario(materias, examen: evento.examen);
                  } else if (opcion == 'eliminar') {
                    _eliminarExamen(evento.examen!);
                  }
                },

                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'editar',
                    child: Text(textos.calendarEditExam),
                  ),

                  PopupMenuItem<String>(
                    value: 'eliminar',
                    child: Text(textos.calendarDeleteExam),
                  ),
                ],
              ),
      ),
    );
  }
}

// =========================================================
// FORMULARIO INDEPENDIENTE DE EXÁMENES
// =========================================================

class _FormularioExamen extends StatefulWidget {
  final StudyTrackRepository repositorio;
  final _Docs materias;
  final DateTime fechaInicial;

  final QueryDocumentSnapshot<Map<String, dynamic>>? examen;

  const _FormularioExamen({
    required this.repositorio,
    required this.materias,
    required this.fechaInicial,
    this.examen,
  });

  @override
  State<_FormularioExamen> createState() => _FormularioExamenState();
}

class _FormularioExamenState extends State<_FormularioExamen> {
  final _formKey = GlobalKey<FormState>();

  late String _titulo;
  late String _descripcion;
  late String _materiaId;
  late DateTime _fecha;

  bool _guardando = false;
  String? _error;

  // =====================================================
  // INICIALIZACIÓN DEL FORMULARIO
  // =====================================================

  @override
  void initState() {
    super.initState();

    final datos = widget.examen?.data();

    _titulo = datos?['titulo']?.toString() ?? '';

    _descripcion = datos?['descripcion']?.toString() ?? '';

    _materiaId = datos?['materiaId']?.toString() ?? '';

    // Mantener una materia válida.
    if (!widget.materias.any((materia) => materia.id == _materiaId)) {
      _materiaId = '';
    }

    // Mantener la fecha existente o usar
    // el día seleccionado a las 09:00.
    _fecha =
        _leerFecha(datos?['fecha']) ??
        DateTime(
          widget.fechaInicial.year,
          widget.fechaInicial.month,
          widget.fechaInicial.day,
          9,
        );
  }

  // =====================================================
  // SELECCIONAR FECHA Y HORA
  // =====================================================

  Future<void> _elegirFecha() async {
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (dia == null || !mounted) return;

    // ==========================================
    // FORMATO DE 24 HORAS
    // ==========================================

    // Mantener la misma corrección utilizada
    // en el formulario de Tareas.

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (hora == null || !mounted) return;

    setState(() {
      _fecha = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    });
  }

  // =====================================================
  // GUARDAR EN FIRESTORE
  // =====================================================

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      // ========================================
      // DATOS EN FIRESTORE
      // ========================================

      // Se conservan los mismos campos
      // y la misma función del repositorio.

      await widget.repositorio.guardarExamen(
        id: widget.examen?.id,
        titulo: _titulo.trim(),
        descripcion: _descripcion.trim(),
        materiaId: _materiaId,
        fecha: _fecha,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _guardando = false;

        _error =
            '${_t(context, 'No se pudo guardar', 'Não foi possível salvar')}: $error';
      });
    }
  }

  // =====================================================
  // DISEÑO DEL FORMULARIO
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);

    return AlertDialog(
      // ========================================
      // TÍTULO
      // ========================================

      title: Text(
        widget.examen == null
            ? textos.calendarNewExam
            : textos.calendarEditExam,
      ),

      content: SizedBox(
        width: 400,

        child: SingleChildScrollView(
          child: Form(
            key: _formKey,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // ================================
                // NOMBRE DEL EXAMEN
                // ================================

                TextFormField(
                  initialValue: _titulo,
                  maxLength: 80,

                  textCapitalization: TextCapitalization.sentences,

                  decoration: InputDecoration(
                    labelText: textos.calendarExamName,

                    border: const OutlineInputBorder(),
                  ),

                  onChanged: (valor) {
                    _titulo = valor;
                  },

                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return _t(
                        context,
                        'Ingresá un nombre',
                        'Informe um nome',
                      );
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ================================
                // MATERIA ASOCIADA
                // ================================
                DropdownButtonFormField<String>(
                  initialValue: _materiaId,
                  isExpanded: true,

                  decoration: InputDecoration(
                    labelText: _t(context, 'Materia', 'Disciplina'),

                    border: const OutlineInputBorder(),
                  ),

                  items: [
                    DropdownMenuItem<String>(
                      value: '',

                      child: Text(textos.calendarNoSubjectAssigned),
                    ),

                    ...widget.materias.map(
                      (materia) => DropdownMenuItem<String>(
                        value: materia.id,

                        child: Text(
                          materia.data()['nombre']?.toString() ??
                              _t(context, 'Materia', 'Disciplina'),

                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],

                  onChanged: _guardando
                      ? null
                      : (valor) {
                          setState(() {
                            _materiaId = valor ?? '';
                          });
                        },
                ),

                const SizedBox(height: 16),

                // ================================
                // FECHA Y HORA DEL EXAMEN
                // ================================
                OutlinedButton.icon(
                  onPressed: _guardando ? null : _elegirFecha,

                  style: OutlinedButton.styleFrom(
                    foregroundColor: _colorAcento(context),
                  ),

                  icon: const Icon(Icons.event),

                  label: Text(_fechaTexto(context, _fecha)),
                ),

                const SizedBox(height: 16),

                // ================================
                // DESCRIPCIÓN OPCIONAL
                // ================================
                TextFormField(
                  initialValue: _descripcion,
                  maxLength: 300,
                  maxLines: 3,

                  decoration: InputDecoration(
                    labelText:
                        '${textos.subjectsDescription} '
                        '(${textos.commonOptional.toLowerCase()})',

                    border: const OutlineInputBorder(),
                  ),

                  onChanged: (valor) {
                    _descripcion = valor;
                  },
                ),

                // ================================
                // ERRORES
                // ================================
                if (_error != null) ...[
                  const SizedBox(height: 10),

                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),

      // ========================================
      // BOTONES DEL FORMULARIO
      // ========================================
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),

          style: TextButton.styleFrom(foregroundColor: _colorAcento(context)),

          child: Text(textos.commonCancel),
        ),

        ElevatedButton(
          onPressed: _guardando ? null : _guardar,

          style: ElevatedButton.styleFrom(
            backgroundColor: _colorAcento(context),

            foregroundColor: _textoSobreAcento(context),
          ),

          child: Text(
            _guardando
                ? _t(context, 'Guardando...', 'Salvando...')
                : textos.commonSave,
          ),
        ),
      ],
    );
  }
}

 
              

                 
