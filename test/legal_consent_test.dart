import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studytrack/l10n/app_localizations.dart';
import 'package:studytrack/screens/register_screen.dart';
import 'package:studytrack/services/legal_documents.dart';
import 'package:studytrack/widgets/legal_consent.dart';

import 'legal_fixtures.dart';

Widget app(Widget home, {double textScale = 1}) => MaterialApp(
  locale: const Locale('pt'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

void main() {
  testWidgets(
    'cadastro so libera criacao com a caixa marcada e permite desmarcar',
    (tester) async {
      await tester.pumpWidget(
        app(RegisterScreen(loadLegalDocuments: () async => legalDocuments)),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(ElevatedButton, 'Criar minha conta');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      final checkbox = find.byKey(const Key('legal-consent-checkbox'));
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leitura abre os dois documentos sem marcar aceite ou perder formulario',
    (tester) async {
      await tester.pumpWidget(
        app(RegisterScreen(loadLegalDocuments: () async => legalDocuments)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Nome preservado',
      );
      final terms = find.widgetWithText(TextButton, 'Termos de Uso');
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(find.text('Termos de Uso do StudyTrack'), findsOneWidget);
      expect(
        find.text('Leia estes termos antes de criar a conta.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final privacy = find.widgetWithText(TextButton, 'Aviso de Privacidade');
      await tester.ensureVisible(privacy);
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.text('Aviso de Privacidade do StudyTrack'), findsOneWidget);
      expect(find.text('Nome e e-mail'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('legal-consent-checkbox')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Nome preservado',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('teclado nao contorna a obrigatoriedade do aceite', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(RegisterScreen(loadLegalDocuments: () async => legalDocuments)),
    );
    await tester.pumpAndSettle();
    final confirmation = find.byType(TextFormField).last;
    await tester.ensureVisible(confirmation);
    await tester.enterText(confirmation, 'senha123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      find.text('Leia e aceite os termos antes de criar sua conta.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao carregar impede aceite e permite tentar novamente', (
    tester,
  ) async {
    var attempts = 0;
    LegalAcceptance? accepted;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: LegalConsentField(
            loadDocuments: () async {
              if (attempts++ == 0) throw Exception('Sem rede');
              return legalDocuments;
            },
            onChanged: (value) => accepted = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(accepted, isNull);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(accepted, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(accepted!.toJson()['termos']['sha256'], legalDocuments.terms.sha256);
  });

  testWidgets(
    'confirmacao para Google ou conta antiga exige caixa e permite cancelar',
    (tester) async {
      var returned = false;
      LegalAcceptance? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<LegalAcceptance>(
                    MaterialPageRoute(
                      builder: (_) => LegalAcceptanceScreen(
                        loadDocuments: () async => legalDocuments,
                      ),
                    ),
                  );
                  returned = true;
                },
                child: const Text('Continuar com Google'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Continuar com Google'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Aceitar e continuar');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
      await tester.tap(find.text('Continuar com Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(result!.toJson()['privacidade']['aceito'], isTrue);
    },
  );

  testWidgets('leitura e aceite cabem em tela estreita com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        LegalAcceptanceScreen(loadDocuments: () async => legalDocuments),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final privacy = find.widgetWithText(TextButton, 'Aviso de Privacidade');
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    await tester.pumpAndSettle();
    expect(find.text('Identificar sua conta.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
