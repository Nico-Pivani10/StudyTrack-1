import 'app_data.dart';
import 'language_controller.dart';

/// Dados acadêmicos e perfil persistidos no Supabase através da API.
class StudyTrackRepository {
  final String uid;
  StudyTrackRepository(this.uid);

  AppRecord get usuario => AppRecord(null, uid, ownerUid: uid);
  AppCollection get materias => AppCollection('materias', ownerUid: uid);
  AppCollection get tareas => AppCollection('tareas', ownerUid: uid);
  AppCollection get examenes => AppCollection('examenes', ownerUid: uid);
  AppCollection get sesionesEstudio =>
      AppCollection('sesionesEstudio', ownerUid: uid);

  Stream<AppDocument> get escucharUsuario => usuario.snapshots();
  Stream<AppQuerySnapshot> get escucharMaterias => materias.snapshots();
  Stream<AppQuerySnapshot> get escucharTareas => tareas.snapshots();
  Stream<AppQuerySnapshot> get escucharExamenes => examenes.snapshots();
  Stream<AppQuerySnapshot> get escucharSesiones => sesionesEstudio.snapshots();

  String _t(String es, String pt) =>
      languageController.languageCode.startsWith('pt') ? pt : es;

  Future<void> guardarMateria({
    String? id,
    required String nombre,
    String descripcion = '',
    String docente = '',
  }) async {
    if (nombre.trim().isEmpty) {
      throw ArgumentError(
        _t(
          'El nombre de la materia es obligatorio.',
          'O nome da disciplina é obrigatório.',
        ),
      );
    }
    final datos = <String, dynamic>{
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'docente': docente.trim(),
    };
    if (id == null) {
      await materias.add(datos);
    } else {
      await materias.doc(id).update(datos);
    }
  }

  Future<void> eliminarMateria(String id) async {
    final tarefas = await tareas.get();
    final provas = await examenes.get();
    if (tarefas.docs.any((d) => d.data()['materiaId'] == id) ||
        provas.docs.any((d) => d.data()['materiaId'] == id)) {
      throw StateError(
        _t(
          'Esta materia tiene tareas o exámenes asociados.',
          'Esta disciplina possui tarefas ou provas associadas.',
        ),
      );
    }
    await materias.doc(id).delete();
  }

  Future<void> guardarTarea({
    String? id,
    required String titulo,
    required DateTime fechaEntrega,
    String descripcion = '',
    String materiaId = '',
    String prioridad = 'MEDIA',
    int minutosAntes = 10,
  }) async {
    if (titulo.trim().isEmpty) {
      throw ArgumentError(
        _t(
          'El título de la tarea es obligatorio.',
          'O título da tarefa é obrigatório.',
        ),
      );
    }
    final datos = <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'materiaId': materiaId,
      'fechaEntrega': AppTimestamp.fromDate(fechaEntrega),
      'prioridad': prioridad,
      'minutosAntes': minutosAntes,
    };
    if (id == null) {
      await tareas.add({...datos, 'completada': false});
    } else {
      await tareas.doc(id).update(datos);
    }
  }

  Future<void> cambiarEstadoTarea(String id, bool completada) =>
      tareas.doc(id).update({'completada': completada});
  Future<void> eliminarTarea(String id) => tareas.doc(id).delete();

  Future<void> guardarExamen({
    String? id,
    required String titulo,
    required DateTime fecha,
    String descripcion = '',
    String materiaId = '',
  }) async {
    if (titulo.trim().isEmpty) {
      throw ArgumentError(
        _t(
          'El título del examen es obligatorio.',
          'O título da prova é obrigatório.',
        ),
      );
    }
    final datos = <String, dynamic>{
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'materiaId': materiaId,
      'fecha': AppTimestamp.fromDate(fecha),
    };
    if (id == null) {
      await examenes.add(datos);
    } else {
      await examenes.doc(id).update(datos);
    }
  }

  Future<void> eliminarExamen(String id) => examenes.doc(id).delete();

  Future<void> registrarEstudio({
    required int minutos,
    String materiaId = '',
  }) async {
    if (minutos <= 0 || minutos > 1440) {
      throw ArgumentError(
        _t(
          'Los minutos deben estar entre 1 y 1440.',
          'Os minutos devem estar entre 1 e 1440.',
        ),
      );
    }
    await sesionesEstudio.add({
      'materiaId': materiaId,
      'minutos': minutos,
      'fecha': AppTimestamp.now(),
    });
  }

  Future<void> actualizarMetaSemanal(int dias) async {
    if (dias < 1 || dias > 7) {
      throw ArgumentError(
        _t(
          'La meta debe estar entre 1 y 7 días.',
          'A meta deve ser entre 1 e 7 dias.',
        ),
      );
    }
    await usuario.set({'metaSemanalDias': dias});
  }

  Future<void> guardarPerfilAcademico({
    required String institucion,
    required String carrera,
    required String semestre,
    required String metaAcademica,
  }) => usuario.set({
    'institucion': institucion.trim(),
    'carrera': carrera.trim(),
    'semestre': semestre.trim(),
    'metaAcademica': metaAcademica.trim(),
  });
}
