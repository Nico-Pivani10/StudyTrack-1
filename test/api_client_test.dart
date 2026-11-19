import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studytrack/services/api_client.dart';

http.Response jsonResponse(Map<String, dynamic> data, {int status = 200}) {
  return http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response authResponse(String token, {String uid = 'uid-a'}) {
  return jsonResponse({
    'token': token,
    'usuario': {'id': 1, 'firebase_uid': uid},
  });
}

Matcher apiError(int statusCode, [String? message]) {
  var matcher = isA<ApiException>().having(
    (error) => error.statusCode,
    'statusCode',
    statusCode,
  );
  if (message != null) {
    matcher = matcher.having((error) => error.message, 'message', message);
  }
  return throwsA(matcher);
}

void main() {
  test(
    'connect autentica, importa e carrega o estado com a sessao da API',
    () async {
      final paths = <String>[];
      final client = ApiClient(
        baseUrl: 'https://studytrack.example',
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.url.host, 'studytrack.example');
          if (request.url.path == '/api/auth/firebase') {
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], isNull);
            expect(jsonDecode(request.body), {'id_token': 'firebase-token'});
            return authResponse('api-token');
          }
          expect(request.headers['Authorization'], 'Bearer api-token');
          if (request.url.path == '/api/mobile/importar') {
            expect(request.method, 'POST');
            return jsonResponse({'importado': true});
          }
          expect(request.method, 'GET');
          return jsonResponse({
            'perfil': {'nombre': 'Ana'},
            'materias': [],
          });
        }),
      );
      addTearDown(client.dispose);

      await client.connect();

      expect(paths, [
        '/api/auth/firebase',
        '/api/mobile/importar',
        '/api/mobile/estado',
      ]);
      expect(client.estado['perfil'], {'nombre': 'Ana'});
      expect(client.firebaseUid, 'uid-a');
    },
  );

  test(
    'request envia JSON com bearer e renova uma vez apos HTTP 401',
    () async {
      var exchanges = 0;
      final bearers = <String?>[];
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            exchanges++;
            return authResponse('api-$exchanges');
          }
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/mobile/tareas/atividade-1');
          expect(jsonDecode(request.body), {'titulo': 'Revisar'});
          bearers.add(request.headers['Authorization']);
          if (bearers.length == 1) {
            return jsonResponse({'erro': 'Sessao expirada'}, status: 401);
          }
          return jsonResponse({
            'registro': {'titulo': 'Revisar'},
          });
        }),
      );
      addTearDown(client.dispose);

      final response = await client.request(
        'PUT',
        '/api/mobile/tareas/atividade-1',
        data: {'titulo': 'Revisar'},
      );

      expect(response, {
        'registro': {'titulo': 'Revisar'},
      });
      expect(exchanges, 2);
      expect(bearers, ['Bearer api-1', 'Bearer api-2']);
    },
  );

  test(
    'HTTP 401 persistente termina depois de uma unica retentativa',
    () async {
      var exchanges = 0;
      var writes = 0;
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            exchanges++;
            return authResponse('api-$exchanges');
          }
          writes++;
          return jsonResponse({'erro': 'Sessao recusada'}, status: 401);
        }),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.request('POST', '/api/mobile/tareas', data: {'titulo': 'Teste'}),
        apiError(401, 'Sessao recusada'),
      );
      expect(exchanges, 2);
      expect(writes, 2);
    },
  );

  test('requisicoes simultaneas compartilham a renovacao do token', () async {
    var exchanges = 0;
    var expiredRequests = 0;
    final renewalStarted = Completer<void>();
    final releaseRenewal = Completer<void>();
    final bothExpired = Completer<void>();
    final client = ApiClient(
      firebaseToken: () async => 'firebase-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/firebase') {
          exchanges++;
          if (exchanges == 2) {
            renewalStarted.complete();
            await releaseRenewal.future;
          }
          return authResponse('api-$exchanges');
        }
        if (request.url.path == '/api/inicial') {
          return jsonResponse({'ok': true});
        }
        if (request.headers['Authorization'] == 'Bearer api-1') {
          expiredRequests++;
          if (expiredRequests == 2) bothExpired.complete();
          return jsonResponse({'erro': 'Expirou'}, status: 401);
        }
        expect(request.headers['Authorization'], 'Bearer api-2');
        return jsonResponse({'ok': true});
      }),
    );
    addTearDown(client.dispose);
    await client.request('GET', '/api/inicial');

    final requests = Future.wait([
      client.request('GET', '/api/primeira'),
      client.request('GET', '/api/segunda'),
    ]);
    await Future.wait([renewalStarted.future, bothExpired.future]);
    releaseRenewal.complete();
    await requests;

    expect(exchanges, 2);
    expect(expiredRequests, 2);
  });

  test('HTTP 402 preserva o erro da API e nao renova a sessao', () async {
    var exchanges = 0;
    var attempts = 0;
    final client = ApiClient(
      firebaseToken: () async => 'firebase-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/firebase') {
          exchanges++;
          return authResponse('api-token');
        }
        attempts++;
        return jsonResponse({
          'erro': 'Este recurso exige Premium',
        }, status: 402);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.request('POST', '/api/mobile/materias', data: {'nombre': 'Outra'}),
      apiError(402, 'Este recurso exige Premium'),
    );
    expect(exchanges, 1);
    expect(attempts, 1);
  });

  test('renovar sessao nao repete a importacao de dados', () async {
    var exchanges = 0;
    var imports = 0;
    var loads = 0;
    final client = ApiClient(
      firebaseToken: () async => 'firebase-token',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/auth/firebase':
            exchanges++;
            return authResponse('api-$exchanges');
          case '/api/mobile/importar':
            imports++;
            return jsonResponse({'importado': true});
          default:
            loads++;
            if (loads == 2) {
              return jsonResponse({'erro': 'Expirou'}, status: 401);
            }
            return jsonResponse({'materias': []});
        }
      }),
    );
    addTearDown(client.dispose);

    await client.connect();
    await client.refresh();

    expect(exchanges, 2);
    expect(imports, 1);
    expect(loads, 3);
  });

  test(
    'trocar conta descarta estado antigo que ainda estava em transito',
    () async {
      var firebaseToken = 'firebase-A';
      var stateLoads = 0;
      final oldRequestStarted = Completer<void>();
      final oldResponse = Completer<http.Response>();
      final client = ApiClient(
        firebaseToken: () async => firebaseToken,
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            final data = jsonDecode(request.body) as Map<String, dynamic>;
            return authResponse('api-${data['id_token']}', uid: firebaseToken);
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': true});
          }
          stateLoads++;
          if (stateLoads == 2) {
            oldRequestStarted.complete();
            return oldResponse.future;
          }
          return jsonResponse({
            'perfil': {'conta': firebaseToken},
          });
        }),
      );
      addTearDown(client.dispose);
      await client.connect();
      expect(client.estado['perfil'], {'conta': 'firebase-A'});

      final oldLoad = client.refresh();
      final oldLoadRejected = expectLater(oldLoad, apiError(401));
      await oldRequestStarted.future;
      firebaseToken = 'firebase-B';
      final newConnection = client.connect();
      expect(client.estado, isEmpty);
      await newConnection;
      oldResponse.complete(
        jsonResponse({
          'perfil': {'conta': 'firebase-A'},
        }),
      );
      await oldLoadRejected;

      expect(client.estado['perfil'], {'conta': 'firebase-B'});
    },
  );

  test('signOut limpa os dados locais mesmo se a revogacao falhar', () async {
    var exchanges = 0;
    final client = ApiClient(
      firebaseToken: () async => 'firebase-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/firebase') {
          exchanges++;
          return authResponse('api-$exchanges');
        }
        if (request.url.path == '/api/auth/logout') {
          return jsonResponse({'erro': 'Servico indisponivel'}, status: 503);
        }
        if (request.url.path == '/api/mobile/importar') {
          return jsonResponse({'importado': true});
        }
        return jsonResponse({
          'perfil': {'nome': 'Conta A'},
        });
      }),
    );
    addTearDown(client.dispose);
    await client.connect();
    expect(client.estado, isNotEmpty);

    await expectLater(client.signOut(), apiError(503));
    expect(client.estado, isEmpty);
    expect(client.firebaseUid, isNull);
    await client.request('GET', '/api/auth/me');
    expect(exchanges, 2);
  });

  test('credencial Firebase ausente impede chamadas ao servidor', () async {
    var calls = 0;
    final client = ApiClient(
      firebaseToken: () async => null,
      client: MockClient((request) async {
        calls++;
        return jsonResponse({});
      }),
    );
    addTearDown(client.dispose);

    await expectLater(client.connect(), apiError(401));
    expect(calls, 0);
    expect(client.estado, isEmpty);
  });

  test(
    'connect continua os lotes de importacao antes de carregar o estado',
    () async {
      var imports = 0;
      final paths = <String>[];
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/auth/firebase') {
            return authResponse('api-token');
          }
          expect(request.headers['Authorization'], 'Bearer api-token');
          if (request.url.path == '/api/mobile/importar') {
            imports++;
            if (imports < 3) {
              return jsonResponse({'importado': false, 'continuar': true});
            }
            return jsonResponse({'importado': true});
          }
          expect(imports, 3);
          return jsonResponse({
            'perfil': {'nombre': 'Ana'},
            'materias': [],
          });
        }),
      );
      addTearDown(client.dispose);

      await client.connect();

      expect(paths, [
        '/api/auth/firebase',
        '/api/mobile/importar',
        '/api/mobile/importar',
        '/api/mobile/importar',
        '/api/mobile/estado',
      ]);
      expect(client.estado['perfil'], {'nombre': 'Ana'});
    },
  );

  test(
    'importacao sem confirmacao interrompe entrada e limpa a sessao',
    () async {
      var stateLoads = 0;
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            return authResponse('api-token');
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': false});
          }
          stateLoads++;
          return jsonResponse({
            'perfil': {'nombre': 'Conta incompleta'},
          });
        }),
      );
      addTearDown(client.dispose);

      await expectLater(client.connect(), apiError(502));

      expect(stateLoads, 0);
      expect(client.estado, isEmpty);
      expect(client.firebaseUid, isNull);
    },
  );

  test(
    'renovacao com outra identidade nao reenvia a operacao da conta anterior',
    () async {
      var uid = 'uid-a';
      var writes = 0;
      final client = ApiClient(
        firebaseToken: () async => 'firebase-$uid',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            return authResponse('api-$uid', uid: uid);
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': true});
          }
          if (request.url.path == '/api/mobile/estado') {
            return jsonResponse({
              'perfil': {'conta': uid},
            });
          }
          writes++;
          if (writes == 1) {
            uid = 'uid-b';
            return jsonResponse({'erro': 'Sessao expirada'}, status: 401);
          }
          return jsonResponse({
            'registro': {'titulo': 'Conta errada'},
          });
        }),
      );
      addTearDown(client.dispose);
      await client.connect();

      await expectLater(
        client.request(
          'PUT',
          '/api/mobile/tareas/item-antigo',
          data: {'titulo': 'Conta A'},
        ),
        apiError(401),
      );

      expect(writes, 1);
      expect(client.estado, isEmpty);
      expect(client.firebaseUid, isNull);
    },
  );

  test('URL externa exige HTTPS e recusa credenciais embutidas', () {
    for (final url in [
      'http://studytrack.example',
      'https://usuario:senha@studytrack.example',
      'https://studytrack.example?token=teste',
      'https://studytrack.example#fragmento',
    ]) {
      expect(() => ApiClient(baseUrl: url), throwsArgumentError);
    }
    for (final url in [
      'https://studytrack.example',
      'http://localhost:5000',
      'http://127.0.0.1:5000',
      'http://10.0.2.2:5000',
    ]) {
      final client = ApiClient(baseUrl: url);
      addTearDown(client.dispose);
    }
  });

  test(
    'vinculo comprova ambas identidades e conserva senha fora da sessao',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        firebaseToken: () async => 'identidade-firebase',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/auth/login') {
            expect(request.headers['Authorization'], isNull);
            expect(jsonDecode(request.body), {
              'email': 'aluno@example.com',
              'senha': 'senha-antiga-de-teste',
            });
            return authResponse('token-legado');
          }
          if (request.url.path == '/api/auth/firebase/vincular') {
            expect(request.headers['Authorization'], 'Bearer token-legado');
            expect(jsonDecode(request.body), {
              'id_token': 'identidade-firebase',
            });
            return jsonResponse({'vinculado': true});
          }
          if (request.url.path == '/api/auth/firebase') {
            expect(jsonDecode(request.body), {
              'id_token': 'identidade-firebase',
            });
            return authResponse('token-da-sessao-firebase');
          }
          expect(
            request.headers['Authorization'],
            'Bearer token-da-sessao-firebase',
          );
          expect(request.body, isEmpty);
          return jsonResponse({
            'usuario': {'firebase_uid': 'uid-a'},
          });
        }),
      );
      addTearDown(client.dispose);

      await client.linkLegacyAccount(
        'aluno@example.com',
        'senha-antiga-de-teste',
      );
      expect(client.estado, isEmpty);
      expect(client.firebaseUid, isNull);
      await client.request('GET', '/api/auth/me');

      expect(requests.map((request) => request.url.path), [
        '/api/auth/login',
        '/api/auth/firebase/vincular',
        '/api/auth/firebase',
        '/api/auth/me',
      ]);
      expect(
        requests
            .where((request) => request.body.contains('senha-antiga-de-teste'))
            .length,
        1,
      );
      expect(client.estado.containsKey('senha'), isFalse);
    },
  );

  test('senha legada recusada impede a tentativa de vinculo', () async {
    final paths = <String>[];
    final client = ApiClient(
      firebaseToken: () async => 'identidade-firebase',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return jsonResponse({'erro': 'Email ou senha invalidos'}, status: 401);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.linkLegacyAccount('aluno@example.com', 'senha-incorreta'),
      apiError(401),
    );

    expect(paths, ['/api/auth/login']);
    expect(client.estado, isEmpty);
    expect(client.firebaseUid, isNull);
  });
}
