import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'legal_documents.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? codigo;

  const ApiException(this.statusCode, this.message, {this.codigo});

  @override
  String toString() => message;
}

/// A sessão da API fica em memória. O Firebase permite renová-la após abrir o app.
class ApiClient {
  static final ApiClient instance = ApiClient();

  final http.Client _client;
  final Future<String?> Function() _firebaseToken;
  final Uri _baseUrl;
  late final StreamController<Map<String, dynamic>> _changes;
  Timer? _poll;
  Future<void>? _authentication;
  Future<void>? _refreshing;
  String? _token;
  String? _firebaseUid;
  int _generation = 0;
  bool _loaded = false;
  Map<String, dynamic> _estado = {};
  LegalAcceptance? _pendingAcceptance;

  ApiClient({
    http.Client? client,
    Future<String?> Function()? firebaseToken,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _firebaseToken = firebaseToken ?? _currentFirebaseToken,
       _baseUrl = Uri.parse(
         baseUrl ??
             const String.fromEnvironment(
               'STUDYTRACK_API_URL',
               defaultValue: 'https://studytrackk.vercel.app',
             ),
       ) {
    final local = {
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
    }.contains(_baseUrl.host);
    if (_baseUrl.host.isEmpty ||
        (_baseUrl.scheme != 'https' && !(_baseUrl.scheme == 'http' && local)) ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment) {
      throw ArgumentError('Configure uma URL HTTPS válida para a API.');
    }
    _changes = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        _poll = Timer.periodic(const Duration(seconds: 30), (_) {
          if (_token != null) unawaited(_refreshInBackground());
        });
      },
      onCancel: () {
        _poll?.cancel();
        _poll = null;
      },
    );
  }

  static Future<String?> _currentFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(true);
  }

  Map<String, dynamic> get estado => Map.unmodifiable(_estado);
  String? get firebaseUid => _firebaseUid;

  Stream<Map<String, dynamic>> get states => Stream.multi((sink) {
    final subscription = _changes.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    if (_loaded) sink.add(estado);
    if (_token != null) unawaited(_refreshInBackground());
    sink.onCancel = subscription.cancel;
  });

  /// Só entra no dashboard depois da autenticação e da importação confirmadas.
  Future<void> connect({LegalAcceptance? acceptance}) async {
    _clearSession();
    _pendingAcceptance = acceptance;
    final generation = _generation;
    try {
      await _authenticate();
      var importing = true;
      while (importing) {
        final response = await request('POST', '/api/mobile/importar');
        _requireGeneration(generation);
        importing = response['importado'] != true;
        if (importing && response['continuar'] != true) {
          throw const ApiException(
            502,
            'A importação não foi confirmada. Tente entrar novamente.',
          );
        }
      }
      await refresh();
    } catch (_) {
      if (generation == _generation) _clearSession();
      rethrow;
    }
  }

  Future<LegalDocuments> loadLegalDocuments() async {
    final response = _checked(await _send('GET', '/api/legal/documentos'));
    try {
      return LegalDocuments.fromJson(response);
    } on FormatException {
      throw const ApiException(
        502,
        'Não foi possível carregar os documentos. Tente novamente.',
      );
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final generation = _generation;
    if (_token == null) await _authenticate();
    _requireGeneration(generation);
    var token = _token;
    var result = await _send(method, path, data: data, token: token);
    _requireGeneration(generation);
    if (result.$1 == 401) {
      // Requisições simultâneas compartilham a mesma renovação da sessão.
      if (_token == token) await _authenticate();
      _requireGeneration(generation);
      token = _token;
      result = await _send(method, path, data: data, token: token);
      _requireGeneration(generation);
    }
    return _checked(result);
  }

  Future<void> _authenticate() {
    final running = _authentication;
    if (running != null) return running;
    late final Future<void> pending;
    pending = _exchange().whenComplete(() {
      if (identical(_authentication, pending)) _authentication = null;
    });
    _authentication = pending;
    return pending;
  }

  Future<void> _exchange() async {
    final generation = _generation;
    final idToken = await _firebaseToken();
    _requireGeneration(generation);
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException(401, 'Entre novamente na sua conta.');
    }
    final response = _checked(
      await _send(
        'POST',
        '/api/auth/firebase',
        data: {
          'id_token': idToken,
          if (_pendingAcceptance != null)
            'aceite': _pendingAcceptance!.toJson(),
        },
      ),
    );
    _requireGeneration(generation);
    final jwt = response['token'];
    if (jwt is! String || jwt.isEmpty) {
      throw const ApiException(502, 'A API retornou uma sessão inválida.');
    }
    final newUid = (response['usuario'] as Map?)?['firebase_uid'] as String?;
    if (_firebaseUid != null && _firebaseUid != newUid) {
      _clearSession();
      throw const ApiException(401, 'A conta mudou. Entre novamente.');
    }
    _token = jwt;
    _firebaseUid = newUid;
    _pendingAcceptance = null;
  }

  Future<void> refresh({bool force = false}) async {
    final generation = _generation;
    final running = _refreshing;
    if (running != null) {
      await running;
      _requireGeneration(generation);
      if (!force) return;
    }
    final pending = _loadState();
    _refreshing = pending;
    try {
      await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  Future<void> _loadState() async {
    final generation = _generation;
    final response = await request('GET', '/api/mobile/estado');
    _requireGeneration(generation);
    _estado = response;
    _loaded = true;
    _changes.add(estado);
  }

  Future<void> _refreshInBackground() async {
    final generation = _generation;
    try {
      await refresh();
    } catch (error, stack) {
      if (generation == _generation) _changes.addError(error, stack);
    }
  }

  Future<void> signOut() async {
    try {
      if (_token != null) await request('POST', '/api/auth/logout');
    } finally {
      _clearSession();
    }
  }

  void applyMobileResult(
    String? tipo,
    String id,
    Map<String, dynamic> result, {
    bool deleted = false,
  }) {
    if (tipo == null) {
      _estado['perfil'] = result['perfil'];
    } else {
      final records = List<dynamic>.from(_estado[tipo] as List? ?? []);
      records.removeWhere((entry) => entry['id'] == id);
      if (!deleted && result['registro'] is Map) {
        records.add(result['registro']);
      }
      _estado[tipo] = records;
    }
    _loaded = true;
    _changes.add(estado);
  }

  /// O vínculo exige a sessão Firebase atual e a senha da conta antiga da API.
  Future<void> linkLegacyAccount(
    String email,
    String password, {
    LegalAcceptance? acceptance,
  }) async {
    final generation = _generation;
    final firebaseToken = await _firebaseToken();
    _requireGeneration(generation);
    if (firebaseToken == null) {
      throw const ApiException(401, 'Entre novamente na sua conta.');
    }
    final legacy = _checked(
      await _send(
        'POST',
        '/api/auth/login',
        data: {'email': email, 'senha': password},
      ),
    );
    _requireGeneration(generation);
    final token = legacy['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(502, 'A API retornou uma sessão inválida.');
    }
    _checked(
      await _send(
        'POST',
        '/api/auth/firebase/vincular',
        data: {
          'id_token': firebaseToken,
          if (acceptance != null) 'aceite': acceptance.toJson(),
        },
        token: token,
      ),
    );
    _requireGeneration(generation);
  }

  void _clearSession() {
    _generation++;
    _token = null;
    _firebaseUid = null;
    _pendingAcceptance = null;
    _estado = {};
    _loaded = false;
    _authentication = null;
    _refreshing = null;
    _changes.add(estado);
  }

  void _requireGeneration(int generation) {
    if (generation != _generation) {
      throw const ApiException(401, 'A sessão mudou. Entre novamente.');
    }
  }

  Future<(int, Map<String, dynamic>)> _send(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? token,
  }) async {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://')) {
      throw ArgumentError('Caminho de API inválido.');
    }
    final uri = Uri.parse(
      '${_baseUrl.toString().replaceFirst(RegExp(r'/$'), '')}$path',
    );
    final req = http.Request(method, uri)..followRedirects = false;
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (data != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(data);
    }
    try {
      final timeout = Duration(
        seconds: path == '/api/mobile/importar' ? 120 : 30,
      );
      final response = await http.Response.fromStream(
        await _client.send(req).timeout(timeout),
      ).timeout(timeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Resposta inesperada da API');
      }
      return (response.statusCode, decoded);
    } on TimeoutException {
      throw const ApiException(408, 'A conexão demorou. Tente novamente.');
    } on http.ClientException {
      throw const ApiException(
        503,
        'Não foi possível acessar a API. Confira sua conexão.',
      );
    } on FormatException {
      throw const ApiException(
        502,
        'O servidor retornou uma resposta inesperada.',
      );
    }
  }

  Map<String, dynamic> _checked((int, Map<String, dynamic>) response) {
    if (response.$1 < 200 || response.$1 >= 300) {
      throw ApiException(
        response.$1,
        response.$2['erro']?.toString() ??
            'Não foi possível concluir a operação.',
        codigo: response.$2['codigo'] as String?,
      );
    }
    return response.$2;
  }

  void dispose() {
    _poll?.cancel();
    _client.close();
    unawaited(_changes.close());
  }
}
