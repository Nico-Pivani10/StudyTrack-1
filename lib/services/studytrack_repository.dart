import 'package:cloud_firestore/cloud_firestore.dart';

import 'language_controller.dart';

// =====================================================
// REPOSITORIO DE STUDYTRACK
// =====================================================
//
// Gestión de información académica mediante Firestore.
//
// Compatible con español y portugués brasileño
// en los mensajes de validación.
//
// No se modifican los nombres de colecciones,
// campos, identificadores ni consultas.
//
// =====================================================

class StudyTrackRepository {
  final String uid;

  StudyTrackRepository(this.uid);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =====================================================
  // TRADUCCIONES
  // =====================================================

  // El repositorio no tiene BuildContext.
  // Utilizamos el controlador global de idioma.

  String _t(String es, String pt) {
    final esPortugues = languageController.languageCode.startsWith('pt');

    return esPortugues ? pt : es;
  }

  // =====================================================
  // REFERENCIAS DE FIRESTORE
  // =====================================================

  DocumentReference<Map<String, dynamic>> get usuario {
    return _db.collection('usuarios').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get materias {
    return usuario.collection('materias');
  }

  CollectionReference<Map<String, dynamic>> get tareas {
    return usuario.collection('tareas');
  }

  CollectionReference<Map<String, dynamic>> get examenes {
    return usuario.collection('examenes');
  }

  CollectionReference<Map<String, dynamic>> get sesionesEstudio {
    return usuario.collection('sesionesEstudio');
  }

  // =====================================================
  // CONSULTAS EN TIEMPO REAL
  // =====================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> get escucharUsuario {
    return usuario.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get escucharMaterias {
    return materias.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get escucharTareas {
    return tareas.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get escucharExamenes {
    return examenes.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get escucharSesiones {
    return sesionesEstudio.snapshots();
  }

  // =====================================================
  // GESTIÓN DE MATERIAS
  // =====================================================

  Future<void> guardarMateria({
    String? id,
    required String nombre,
    String descripcion = '',
    String docente = '',
  }) async {
    // ========================================
    // VALIDAR NOMBRE
    // ========================================

    if (nombre.trim().isEmpty) {
      throw ArgumentError(
        _t(
          'El nombre de la materia es obligatorio.',
          'O nome da disciplina é obrigatório.',
        ),
      );
    }

    // ========================================
    // PREPARAR DATOS
    // ========================================

    final datos = <String, dynamic>{
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'docente': docente.trim(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    // ========================================
    // CREAR O ACTUALIZAR
    // ========================================

    if (id == null) {
      datos['creadaEn'] = FieldValue.serverTimestamp();

      await materias.add(datos);
    } else {
      await materias.doc(id).update(datos);
    }
  }

  // =====================================================
  // ELIMINAR MATERIA
  // =====================================================

  Future<void> eliminarMateria(String id) async {
    // Verificar si existen tareas asociadas.

    final tareasAsociadas = await tareas
        .where('materiaId', isEqualTo: id)
        .limit(1)
        .get();

    // Verificar si existen exámenes asociados.

    final examenesAsociados = await examenes
        .where('materiaId', isEqualTo: id)
        .limit(1)
        .get();

    // No permitir eliminar materias
    // que todavía tengan actividades.

    if (tareasAsociadas.docs.isNotEmpty || examenesAsociados.docs.isNotEmpty) {
      throw StateError(
        _t(
          'Esta materia tiene tareas o '
              'exámenes asociados.',
          'Esta disciplina possui tarefas '
              'ou provas associadas.',
        ),
      );
    }

    await materias.doc(id).delete();
  }

  // =====================================================
  // GESTIÓN DE TAREAS
  // =====================================================

  // Se mantiene la integración con el
  // módulo de tareas de StudyTrack.

  Future<void> guardarTarea({
    String? id,
    required String titulo,
    required DateTime fechaEntrega,
    String descripcion = '',
    String materiaId = '',
    String prioridad = 'MEDIA',
    int minutosAntes = 10,
  }) async {
    // ========================================
    // VALIDAR TÍTULO
    // ========================================

    if (titulo.trim().isEmpty) {
      throw ArgumentError(
        _t(
          'El título de la tarea es obligatorio.',
          'O título da tarefa é obrigatório.',
        ),
      );
    }

    // ========================================
    // PREPARAR DATOS
    // ========================================

    final datos = <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'materiaId': materiaId,
      'fechaEntrega': Timestamp.fromDate(fechaEntrega),
      'prioridad': prioridad,
      'minutosAntes': minutosAntes,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    // ========================================
    // CREAR O ACTUALIZAR
    // ========================================

    if (id == null) {
      datos['completada'] = false;
      datos['creadaEn'] = FieldValue.serverTimestamp();

      await tareas.add(datos);
    } else {
      await tareas.doc(id).update(datos);
    }
  }

  // =====================================================
  // CAMBIAR ESTADO DE UNA TAREA
  // =====================================================

  Future<void> cambiarEstadoTarea(String id, bool completada) async {
    await tareas.doc(id).update({
      'completada': completada,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // ELIMINAR TAREA
  // =====================================================

  Future<void> eliminarTarea(String id) async {
    await tareas.doc(id).delete();
  }

  // =====================================================
  // GESTIÓN DE EXÁMENES
  // =====================================================

  Future<void> guardarExamen({
    String? id,
    required String titulo,
    required DateTime fecha,
    String descripcion = '',
    String materiaId = '',
  }) async {
    // ========================================
    // VALIDAR TÍTULO
    // ========================================

    if (titulo.trim().isEmpty) {
      throw ArgumentError(
        _t(
          'El título del examen es obligatorio.',
          'O título da prova é obrigatório.',
        ),
      );
    }

    // ========================================
    // PREPARAR DATOS
    // ========================================

    final datos = <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'materiaId': materiaId,
      'fecha': Timestamp.fromDate(fecha),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    // ========================================
    // CREAR O ACTUALIZAR
    // ========================================

    if (id == null) {
      datos['creadaEn'] = FieldValue.serverTimestamp();

      await examenes.add(datos);
    } else {
      await examenes.doc(id).update(datos);
    }
  }

  // =====================================================
  // ELIMINAR EXAMEN
  // =====================================================

  Future<void> eliminarExamen(String id) async {
    await examenes.doc(id).delete();
  }

  // =====================================================
  // SESIONES DE ESTUDIO
  // =====================================================

  Future<void> registrarEstudio({
    required int minutos,
    String materiaId = '',
  }) async {
    // ========================================
    // VALIDAR DURACIÓN
    // ========================================

    if (minutos <= 0 || minutos > 1440) {
      throw ArgumentError(
        _t(
          'Los minutos deben estar '
              'entre 1 y 1440.',
          'Os minutos devem estar '
              'entre 1 e 1440.',
        ),
      );
    }

    // ========================================
    // GUARDAR SESIÓN
    // ========================================

    await sesionesEstudio.add({
      'materiaId': materiaId,
      'minutos': minutos,
      'fecha': Timestamp.now(),
      'creadaEn': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // META SEMANAL
  // =====================================================

  Future<void> actualizarMetaSemanal(int dias) async {
    // ========================================
    // VALIDAR META
    // ========================================

    if (dias < 1 || dias > 7) {
      throw ArgumentError(
        _t(
          'La meta debe estar entre 1 y 7 días.',
          'A meta deve ser entre 1 e 7 dias.',
        ),
      );
    }

    // ========================================
    // GUARDAR META
    // ========================================

    await usuario.set({
      'metaSemanalDias': dias,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =====================================================
  // PERFIL ACADÉMICO
  // =====================================================

  Future<void> guardarPerfilAcademico({
    required String institucion,
    required String carrera,
    required String semestre,
    required String metaAcademica,
  }) async {
    // Los datos escritos por el estudiante
    // se conservan en su idioma original.

    await usuario.set({
      'institucion': institucion.trim(),
      'carrera': carrera.trim(),
      'semestre': semestre.trim(),
      'metaAcademica': metaAcademica.trim(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
