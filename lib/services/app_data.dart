import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AppTimestamp {
  final DateTime _date;
  AppTimestamp.fromDate(this._date);
  AppTimestamp.now() : _date = DateTime.now();
  DateTime toDate() => _date;
}

class AppBlob {
  final Uint8List bytes;
  AppBlob(this.bytes);
}

class AppFieldValue {
  final bool _delete;
  const AppFieldValue._(this._delete);
  static AppFieldValue serverTimestamp() => const AppFieldValue._(false);
  static AppFieldValue delete() => const AppFieldValue._(true);
}

Object? encodeAppValue(Object? value) {
  if (value is AppTimestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is AppBlob) return base64Encode(value.bytes);
  if (value is AppFieldValue) {
    return value._delete ? null : DateTime.now().toUtc().toIso8601String();
  }
  if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, encodeAppValue(v)));
  }
  if (value is List) return value.map(encodeAppValue).toList();
  return value;
}

Map<String, dynamic> _decodeData(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (key == 'fotoPerfilBytes' && value is String) {
      return MapEntry(key, AppBlob(base64Decode(value)));
    }
    const dates = {
      'fecha',
      'fechaEntrega',
      'creadaEn',
      'actualizadoEn',
      'creadoEn',
      'planActualizadoEn',
      'fotoPerfilActualizada',
      'canceladaEn',
    };
    if (dates.contains(key) && value is String) {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return MapEntry(key, AppTimestamp.fromDate(date.toLocal()));
      }
    }
    return MapEntry(key, value);
  });
}

String newAppId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class AppDocument {
  final String id;
  final AppRecord reference;
  final Map<String, dynamic>? _data;

  AppDocument(this.id, this.reference, Map<String, dynamic>? data)
    : _data = data == null ? null : _decodeData(data);

  bool get exists => _data != null;
  Map<String, dynamic>? data() => _data == null ? null : Map.of(_data);
}

class AppQueryDocument extends AppDocument {
  AppQueryDocument(super.id, super.reference, Map<String, dynamic> super.data);

  @override
  Map<String, dynamic> data() => super.data()!;
}

class AppQuerySnapshot {
  final List<AppQueryDocument> docs;
  AppQuerySnapshot(this.docs);
}

/// Representa um registro do contrato mobile da API.
class AppRecord {
  final String? tipo;
  final String id;
  final ApiClient client;
  final String? ownerUid;

  AppRecord(this.tipo, this.id, {ApiClient? client, String? ownerUid})
    : client = client ?? ApiClient.instance,
      ownerUid = ownerUid ?? (client ?? ApiClient.instance).firebaseUid;

  void _requireOwner() {
    if (ownerUid == null || ownerUid != client.firebaseUid) {
      throw const ApiException(
        401,
        'Este registro pertence a outra sessão. Entre novamente.',
      );
    }
  }

  Map<String, dynamic>? _find(Map<String, dynamic> state) {
    if (tipo == null) {
      final data = state['perfil'];
      return data is Map<String, dynamic> ? data : null;
    }
    for (final entry in (state[tipo] as List? ?? [])) {
      if (entry is Map && entry['id'] == id) {
        return Map<String, dynamic>.from(entry['dados'] as Map);
      }
    }
    return null;
  }

  Future<AppDocument> get() async {
    _requireOwner();
    await client.refresh();
    _requireOwner();
    return AppDocument(id, this, _find(client.estado));
  }

  Stream<AppDocument> snapshots() => client.states.map(
    (state) => AppDocument(
      id,
      this,
      ownerUid == client.firebaseUid ? _find(state) : null,
    ),
  );

  Future<void> set(Map<String, dynamic> data, {bool merge = true}) async {
    await _write('PUT', data);
  }

  Future<void> _write(String method, Map<String, dynamic> data) async {
    _requireOwner();
    // Atualizações do perfil são sempre parciais, preservando campos de outras telas.
    final path = tipo == null
        ? '/api/mobile/perfil'
        : '/api/mobile/$tipo/${Uri.encodeComponent(id)}';
    final response = await client.request(
      tipo == null ? 'PATCH' : method,
      path,
      data: Map<String, dynamic>.from(encodeAppValue(data) as Map),
    );
    _requireOwner();
    client.applyMobileResult(tipo, id, response);
    try {
      await client.refresh(force: true);
    } on ApiException catch (error) {
      if (error.statusCode != 408 && error.statusCode != 503) rethrow;
      // A escrita já foi confirmada. O próximo ciclo atualiza os demais registros.
    }
  }

  Future<void> update(Map<String, dynamic> data) => _write('PATCH', data);

  Future<void> delete() async {
    _requireOwner();
    if (tipo == null) throw StateError('Use o fluxo de exclusão de conta.');
    await client.request(
      'DELETE',
      '/api/mobile/$tipo/${Uri.encodeComponent(id)}',
    );
    _requireOwner();
    client.applyMobileResult(tipo, id, {}, deleted: true);
    try {
      await client.refresh(force: true);
    } on ApiException catch (error) {
      if (error.statusCode != 408 && error.statusCode != 503) rethrow;
    }
  }
}

class AppCollection {
  static final Map<String, Future<void>> _pendingLocks = {};
  final String tipo;
  final ApiClient client;
  final String? ownerUid;

  AppCollection(this.tipo, {ApiClient? client, String? ownerUid})
    : client = client ?? ApiClient.instance,
      ownerUid = ownerUid ?? (client ?? ApiClient.instance).firebaseUid;

  AppRecord doc(String id) =>
      AppRecord(tipo, id, client: client, ownerUid: ownerUid);

  AppQuerySnapshot _snapshot(Map<String, dynamic> state) {
    if (ownerUid != client.firebaseUid) return AppQuerySnapshot([]);
    final records = state[tipo] as List? ?? [];
    return AppQuerySnapshot(
      records.map((entry) {
        final id = entry['id'] as String;
        return AppQueryDocument(
          id,
          doc(id),
          Map<String, dynamic>.from(entry['dados'] as Map),
        );
      }).toList(),
    );
  }

  Stream<AppQuerySnapshot> snapshots() => client.states.map(_snapshot);

  Future<AppQuerySnapshot> get() async {
    if (ownerUid == null || ownerUid != client.firebaseUid) {
      throw const ApiException(401, 'A sessão mudou. Entre novamente.');
    }
    await client.refresh();
    return _snapshot(client.estado);
  }

  Future<AppRecord> add(Map<String, dynamic> data) async {
    if (ownerUid == null || ownerUid != client.firebaseUid) {
      throw const ApiException(401, 'A sessão mudou. Entre novamente.');
    }
    final storageKey = 'studytrack_criacoes_${ownerUid}_$tipo';
    final signatureData = Map<String, dynamic>.from(encodeAppValue(data) as Map)
      ..remove('creadaEn')
      ..remove('actualizadoEn')
      ..remove('notificacionId');
    final keys = signatureData.keys.toList()..sort();
    final signature = jsonEncode({
      for (final key in keys) key: signatureData[key],
    });
    final previous = _pendingLocks[storageKey] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(storageKey);
      final pending = saved == null
          ? <String, dynamic>{}
          : jsonDecode(saved) as Map<String, dynamic>;
      final record = doc(pending[signature] as String? ?? newAppId());
      pending[signature] = record.id;
      if (!await preferences.setString(storageKey, jsonEncode(pending))) {
        throw const ApiException(
          507,
          'Não foi possível guardar a identificação deste cadastro no dispositivo.',
        );
      }
      await record.set(data);
      pending.remove(signature);
      if (!await preferences.setString(storageKey, jsonEncode(pending))) {
        throw const ApiException(
          507,
          'O cadastro foi salvo. Tente confirmar novamente quando houver espaço no dispositivo.',
        );
      }
      return record;
    });
    final completed = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pendingLocks[storageKey] = completed;
    try {
      return await operation;
    } finally {
      if (identical(_pendingLocks[storageKey], completed)) {
        _pendingLocks.remove(storageKey);
      }
    }
  }
}
