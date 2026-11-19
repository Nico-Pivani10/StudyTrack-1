import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/legal_documents.dart';

String _t(BuildContext context, String es, String pt) =>
    Localizations.localeOf(context).languageCode == 'pt' ? pt : es;

class LegalConsentField extends StatefulWidget {
  final ValueChanged<LegalAcceptance?> onChanged;
  final Future<LegalDocuments> Function()? loadDocuments;
  final bool enabled;

  const LegalConsentField({
    super.key,
    required this.onChanged,
    this.loadDocuments,
    this.enabled = true,
  });

  @override
  State<LegalConsentField> createState() => _LegalConsentFieldState();
}

class _LegalConsentFieldState extends State<LegalConsentField> {
  LegalDocuments? _documents;
  bool _checked = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final documents =
          await (widget.loadDocuments ??
              ApiClient.instance.loadLegalDocuments)();
      if (mounted) setState(() => _documents = documents);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _open(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documents = _documents;
    if (documents == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _failed
                ? _t(
                    context,
                    'No se pudieron cargar los documentos.',
                    'Não foi possível carregar os documentos.',
                  )
                : _t(
                    context,
                    'Cargando términos y privacidad…',
                    'Carregando termos e privacidade…',
                  ),
          ),
          if (_failed)
            TextButton(
              onPressed: () {
                setState(() => _failed = false);
                _load();
              },
              child: Text(
                _t(context, 'Intentar nuevamente', 'Tentar novamente'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            context,
            'Antes de continuar, leé los documentos:',
            'Antes de continuar, leia os documentos:',
          ),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => _open(documents.terms),
              child: Text(_t(context, 'Términos de Uso', 'Termos de Uso')),
            ),
            TextButton(
              onPressed: () => _open(documents.privacy),
              child: Text(
                _t(context, 'Aviso de Privacidad', 'Aviso de Privacidade'),
              ),
            ),
          ],
        ),
        if (Localizations.localeOf(context).languageCode != 'pt')
          const Text(
            'Documentos disponibles en portugués.',
            style: TextStyle(fontSize: 12),
          ),
        CheckboxListTile(
          key: const Key('legal-consent-checkbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _checked,
          onChanged: widget.enabled
              ? (value) {
                  setState(() => _checked = value == true);
                  widget.onChanged(
                    _checked ? LegalAcceptance(documents) : null,
                  );
                }
              : null,
          title: Text(
            _t(
              context,
              'Leí y acepto los Términos de Uso y declaro haber leído el Aviso de Privacidad.',
              'Li e aceito os Termos de Uso e declaro que li o Aviso de Privacidade.',
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

Future<LegalAcceptance?> requestLegalAcceptance(BuildContext context) =>
    Navigator.of(context).push<LegalAcceptance>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LegalAcceptanceScreen(),
      ),
    );

class LegalAcceptanceScreen extends StatefulWidget {
  final Future<LegalDocuments> Function()? loadDocuments;
  const LegalAcceptanceScreen({super.key, this.loadDocuments});

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  LegalAcceptance? _acceptance;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t(context, 'Términos y privacidad', 'Termos e privacidade')),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t(
                    context,
                    'Tu cuenta de StudyTrack',
                    'Sua conta do StudyTrack',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                LegalConsentField(
                  loadDocuments: widget.loadDocuments,
                  onChanged: (value) => setState(() => _acceptance = value),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _acceptance == null
                      ? null
                      : () => Navigator.of(context).pop(_acceptance),
                  child: Text(
                    _t(context, 'Aceptar y continuar', 'Aceitar e continuar'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Leitura nativa, com texto selecionável e tabelas apresentadas como pares de dados.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;
  const LegalDocumentScreen({super.key, required this.document});

  String _plain(String text) => text
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
        (m) => '${m[1]} (${m[2]})',
      )
      .replaceAll('**', '')
      .replaceAll('`', '');

  List<Widget> _content(BuildContext context) {
    final widgets = <Widget>[];
    final paragraphs = document.text.split(RegExp(r'\n\s*\n'));
    for (final paragraph in paragraphs) {
      if (paragraph.startsWith('# ')) continue;
      if (paragraph.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              _plain(paragraph.substring(3)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );
      } else if (paragraph.startsWith('|')) {
        final rows = paragraph.split('\n').skip(2);
        for (final row in rows) {
          final cells = row
              .split('|')
              .where((cell) => cell.trim().isNotEmpty)
              .toList();
          if (cells.length < 2) continue;
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _plain(cells[0].trim()),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SelectableText(_plain(cells.skip(1).join(' ').trim())),
                ],
              ),
            ),
          );
        }
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText(
              _plain(paragraph),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(document.title)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _content(context),
            ),
          ),
        ),
      ),
    ),
  );
}
