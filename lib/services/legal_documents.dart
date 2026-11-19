class LegalDocument {
  final String title;
  final String version;
  final String sha256;
  final String text;

  const LegalDocument({
    required this.title,
    required this.version,
    required this.sha256,
    required this.text,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> data) {
    final title = data['titulo'];
    final version = data['versao'];
    final hash = data['sha256'];
    final text = data['texto'];
    if (title is! String ||
        title.isEmpty ||
        version is! String ||
        version.isEmpty ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        text is! String ||
        text.isEmpty) {
      throw const FormatException('Documentos indisponíveis.');
    }
    return LegalDocument(
      title: title,
      version: version,
      sha256: hash,
      text: text,
    );
  }
}

class LegalDocuments {
  final LegalDocument terms;
  final LegalDocument privacy;

  const LegalDocuments({required this.terms, required this.privacy});

  factory LegalDocuments.fromJson(Map<String, dynamic> data) {
    final documents = data['documentos'];
    if (documents is! Map ||
        documents['termos'] is! Map<String, dynamic> ||
        documents['privacidade'] is! Map<String, dynamic>) {
      throw const FormatException('Documentos indisponíveis.');
    }
    return LegalDocuments(
      terms: LegalDocument.fromJson(documents['termos']),
      privacy: LegalDocument.fromJson(documents['privacidade']),
    );
  }
}

/// Criado somente após a confirmação da caixa, com as versões exibidas na tela.
class LegalAcceptance {
  final LegalDocuments documents;
  const LegalAcceptance(this.documents);

  Map<String, dynamic> toJson() => {
    for (final item in {
      'termos': documents.terms,
      'privacidade': documents.privacy,
    }.entries)
      item.key: {
        'aceito': true,
        'versao': item.value.version,
        'sha256': item.value.sha256,
      },
  };
}
