import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studytrack/services/api_client.dart';
import 'package:studytrack/services/app_data.dart';

http.Response jsonResponse(Map<String, dynamic> data) {
  return http.Response(
    jsonEncode(data),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'datas de horario local conservam o instante apos ida e volta na API',
    () {
      final date = DateTime(2026, 11, 18, 10, 30);
      final photo = Uint8List.fromList([1, 2, 3, 4]);
      final encoded =
          encodeAppValue({
                'fechaEntrega': AppTimestamp.fromDate(date),
                'creadaEn': date,
                'fotoPerfilBytes': AppBlob(photo),
              })
              as Map<String, dynamic>;
      final reference = AppRecord('tareas', 'tarefa-1');
      final decoded = AppDocument('tarefa-1', reference, encoded).data()!;

      expect(encoded['fechaEntrega'], date.toUtc().toIso8601String());
      expect(encoded['creadaEn'], date.toUtc().toIso8601String());
      expect(
        (decoded['fechaEntrega'] as AppTimestamp).toDate().isAtSameMomentAs(
          date,
        ),
        isTrue,
      );
      expect(
        (decoded['fotoPerfilBytes'] as AppBlob).bytes,
        orderedEquals(photo),
      );
    },
  );

  test(
    'escrita atualiza o estado mesmo com uma leitura anterior em andamento',
    () async {
      var loads = 0;
      final oldReadStarted = Completer<void>();
      final releaseOldRead = Completer<http.Response>();
      final writeStarted = Completer<void>();
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            return jsonResponse({
              'token': 'api-token',
              'usuario': {'id': 1, 'firebase_uid': 'uid-a'},
            });
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': true});
          }
          if (request.method == 'PUT') {
            expect(request.url.path, '/api/mobile/materias/materia-1');
            expect(jsonDecode(request.body), {'nombre': 'Matematica'});
            writeStarted.complete();
            return jsonResponse({
              'registro': {'id': 'materia-1'},
            });
          }
          loads++;
          if (loads == 2) {
            oldReadStarted.complete();
            return releaseOldRead.future;
          }
          return jsonResponse({
            'perfil': {},
            'materias': loads >= 3
                ? [
                    {
                      'id': 'materia-1',
                      'dados': {'nombre': 'Matematica'},
                    },
                  ]
                : [],
          });
        }),
      );
      addTearDown(client.dispose);
      await client.connect();
      final record = AppRecord('materias', 'materia-1', client: client);

      final previousRead = client.refresh();
      await oldReadStarted.future;
      final write = record.set({'nombre': 'Matematica'});
      await writeStarted.future;
      releaseOldRead.complete(jsonResponse({'perfil': {}, 'materias': []}));
      await Future.wait([previousRead, write]);

      expect(loads, 3);
      final records = client.estado['materias'] as List;
      expect(records.single['dados'], {'nombre': 'Matematica'});
    },
  );

  test(
    'referencia de conta anterior nao pode escrever na nova conta',
    () async {
      var uid = 'uid-a';
      var writes = 0;
      final client = ApiClient(
        firebaseToken: () async => 'firebase-$uid',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            return jsonResponse({
              'token': 'api-$uid',
              'usuario': {'id': uid == 'uid-a' ? 1 : 2, 'firebase_uid': uid},
            });
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': true});
          }
          if (request.method == 'PATCH' || request.method == 'PUT') writes++;
          return jsonResponse({
            'perfil': {'nombre': uid},
            'materias': [],
          });
        }),
      );
      addTearDown(client.dispose);
      await client.connect();
      final previousProfile = AppRecord(null, 'uid-a', client: client);
      final previousRecord = AppRecord('materias', 'materia-1', client: client);
      uid = 'uid-b';
      await client.connect();

      final rejected = throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      );
      await expectLater(
        previousProfile.set({'nombre': 'Nome antigo'}),
        rejected,
      );
      await expectLater(
        previousRecord.set({'nombre': 'Materia antiga'}),
        rejected,
      );

      expect(writes, 0);
      expect(client.estado['perfil'], {'nombre': 'uid-b'});
    },
  );

  test(
    'escrita confirmada conserva o resultado quando atualizar estado falha',
    () async {
      var loads = 0;
      final client = ApiClient(
        firebaseToken: () async => 'identidade-firebase',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            return jsonResponse({
              'token': 'api-token',
              'usuario': {'id': 1, 'firebase_uid': 'uid-a'},
            });
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': true});
          }
          if (request.method == 'PUT') {
            return jsonResponse({
              'registro': {
                'id': 'materia-1',
                'dados': {'nombre': 'Materia confirmada'},
              },
            });
          }
          loads++;
          if (loads > 1) {
            return http.Response(
              jsonEncode({'erro': 'Servico indisponivel'}),
              503,
            );
          }
          return jsonResponse({'perfil': {}, 'materias': []});
        }),
      );
      addTearDown(client.dispose);
      await client.connect();
      final record = AppRecord('materias', 'materia-1', client: client);

      await record.set({'nombre': 'Materia confirmada'});

      final records = client.estado['materias'] as List;
      expect(records.single['dados'], {'nombre': 'Materia confirmada'});
      expect(loads, 2);
    },
  );

  test(
    'reenvio de cadastro conserva ID ate confirmar e depois permite novo igual',
    () async {
      SharedPreferences.setMockInitialValues({});
      final attemptedIds = <String>[];
      final stored = <String, Map<String, dynamic>>{};
      final client = ApiClient(
        firebaseToken: () async => 'identidade-firebase',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            return jsonResponse({
              'token': 'api-token',
              'usuario': {'id': 1, 'firebase_uid': 'uid-a'},
            });
          }
          if (request.url.path == '/api/mobile/importar') {
            return jsonResponse({'importado': true});
          }
          if (request.method == 'PUT') {
            final id = request.url.pathSegments.last;
            attemptedIds.add(id);
            final data = jsonDecode(request.body) as Map<String, dynamic>;
            stored[id] = data;
            if (attemptedIds.length == 1) {
              throw http.ClientException('Resposta perdida depois de salvar');
            }
            return jsonResponse({
              'registro': {'id': id, 'dados': data},
            });
          }
          return jsonResponse({
            'perfil': {},
            'tareas': [
              for (final entry in stored.entries)
                {'id': entry.key, 'dados': entry.value},
            ],
          });
        }),
      );
      addTearDown(client.dispose);
      await client.connect();
      final collection = AppCollection('tareas', client: client);
      final data = <String, dynamic>{
        'titulo': 'Revisar conteudo',
        'fechaEntrega': AppTimestamp.fromDate(DateTime(2026, 11, 20, 14)),
        'creadaEn': AppTimestamp.fromDate(DateTime(2026, 11, 18, 10)),
        'notificacionId': 101,
      };

      await expectLater(
        collection.add(data),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(preferences.getString('studytrack_criacoes_uid-a_tareas')!)
              as Map;
      expect(saved.values.single, attemptedIds.single);

      final retry = await collection.add({
        ...data,
        'creadaEn': AppTimestamp.fromDate(DateTime(2026, 11, 18, 11)),
        'actualizadoEn': AppFieldValue.serverTimestamp(),
        'notificacionId': 102,
      });
      expect(attemptedIds, [retry.id, retry.id]);
      expect(stored.length, 1);
      expect(
        jsonDecode(preferences.getString('studytrack_criacoes_uid-a_tareas')!),
        isEmpty,
      );

      final next = await collection.add(data);
      expect(next.id, isNot(retry.id));
      expect(attemptedIds, [retry.id, retry.id, next.id]);
      expect(stored.length, 2);
    },
  );
}
