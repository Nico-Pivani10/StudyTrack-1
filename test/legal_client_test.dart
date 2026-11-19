import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studytrack/services/api_client.dart';
import 'package:studytrack/services/legal_documents.dart';
import 'legal_fixtures.dart';

http.Response response(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('documentos sao lidos antes de autenticar e sem bearer', () async {
    final client = ApiClient(
      firebaseToken: () async => throw StateError('Nao deve autenticar'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/legal/documentos');
        expect(request.headers['Authorization'], isNull);
        return response(legalJson());
      }),
    );
    addTearDown(client.dispose);
    final documents = await client.loadLegalDocuments();
    expect(documents.terms.text, legalDocuments.terms.text);
    expect(documents.privacy.sha256, legalDocuments.privacy.sha256);
  });

  test(
    'aceite envia as duas versoes exibidas e nao se repete na renovacao',
    () async {
      var exchanges = 0;
      var reads = 0;
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/firebase') {
            final body = jsonDecode(request.body) as Map;
            expect(body.containsKey('aceite'), exchanges == 0);
            if (exchanges == 0) {
              expect(body['aceite'], LegalAcceptance(legalDocuments).toJson());
            }
            exchanges++;
            return response({
              'token': 'api-$exchanges',
              'usuario': {'id': 1, 'firebase_uid': 'uid-a'},
            });
          }
          if (request.url.path == '/api/mobile/importar') {
            return response({'importado': true});
          }
          if (request.url.path == '/api/mobile/estado') {
            return response({'perfil': {}});
          }
          if (reads++ == 0) return response({'erro': 'Expirou'}, 401);
          return response({'ok': true});
        }),
      );
      addTearDown(client.dispose);
      await client.connect(acceptance: LegalAcceptance(legalDocuments));
      await client.request('GET', '/api/auth/me');
      expect(exchanges, 2);
    },
  );

  test('aceite recusado nao importa dados nem permite uma sessao', () async {
    final paths = <String>[];
    final client = ApiClient(
      firebaseToken: () async => 'firebase-token',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return response({
          'erro': 'Confirme os documentos',
          'codigo': 'aceite_necessario',
        }, 428);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      client.connect(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.codigo,
          'codigo',
          'aceite_necessario',
        ),
      ),
    );
    expect(paths, ['/api/auth/firebase']);
    expect(client.firebaseUid, isNull);
    expect(client.estado, isEmpty);
  });

  test(
    'vinculo legado envia aceite sem o incluir no login por senha',
    () async {
      final client = ApiClient(
        firebaseToken: () async => 'firebase-token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (request.url.path == '/api/auth/login') {
            expect(body.containsKey('aceite'), isFalse);
            return response({'token': 'legado'});
          }
          expect(request.url.path, '/api/auth/firebase/vincular');
          expect(body['aceite'], LegalAcceptance(legalDocuments).toJson());
          return response({'token': 'vinculado'});
        }),
      );
      addTearDown(client.dispose);
      await client.linkLegacyAccount(
        'aluno@example.com',
        'senha',
        acceptance: LegalAcceptance(legalDocuments),
      );
    },
  );
}
