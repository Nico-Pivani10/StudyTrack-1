import 'package:studytrack/services/legal_documents.dart';

final legalDocuments = LegalDocuments(
  terms: LegalDocument(
    title: 'Termos de Uso do StudyTrack',
    version: '1.1',
    sha256: 'a' * 64,
    text:
        '# Termos de Uso do StudyTrack\n\nVersão 1.1\n\n## Conta\n\nLeia estes termos antes de criar a conta.',
  ),
  privacy: LegalDocument(
    title: 'Aviso de Privacidade do StudyTrack',
    version: '1.1',
    sha256: 'b' * 64,
    text:
        '# Aviso de Privacidade do StudyTrack\n\nVersão 1.1\n\n## Dados usados\n\n'
        '| Dados | Uso |\n|---|---|\n| Nome e e-mail | Identificar sua conta. |',
  ),
);

Map<String, dynamic> legalJson() => {
  'documentos': {
    for (final entry in {
      'termos': legalDocuments.terms,
      'privacidade': legalDocuments.privacy,
    }.entries)
      entry.key: {
        'titulo': entry.value.title,
        'versao': entry.value.version,
        'sha256': entry.value.sha256,
        'texto': entry.value.text,
      },
  },
};
