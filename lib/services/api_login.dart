import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'legal_documents.dart';
import '../widgets/legal_consent.dart';

/// Confirma a conexão da API e oferece o vínculo de uma conta anterior.
Future<bool> connectApi(
  BuildContext context, {
  LegalAcceptance? acceptance,
}) async {
  var confirmed = acceptance;
  bool needsAcceptance(ApiException error) =>
      error.codigo == 'aceite_necessario' ||
      error.codigo == 'documentos_atualizados';

  while (context.mounted) {
    try {
      await ApiClient.instance.connect(acceptance: confirmed);
      return true;
    } on ApiException catch (error) {
      if (!context.mounted) return false;
      if (needsAcceptance(error)) {
        confirmed = await requestLegalAcceptance(context);
        if (confirmed == null) return false;
        continue;
      }
      if (error.statusCode != 409 || error.codigo != 'conta_nao_vinculada') {
        rethrow;
      }
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null || email.isEmpty) rethrow;
      final password = await showDialog<String>(
        context: context,
        builder: (_) => _LegacyAccountDialog(email: email),
      );
      if (password == null || !context.mounted) return false;
      while (context.mounted) {
        try {
          await ApiClient.instance.linkLegacyAccount(
            email,
            password,
            acceptance: confirmed,
          );
          break;
        } on ApiException catch (linkError) {
          if (!needsAcceptance(linkError)) rethrow;
          if (!context.mounted) return false;
          confirmed = await requestLegalAcceptance(context);
          if (confirmed == null) return false;
        }
      }
    }
  }
  return false;
}

class _LegacyAccountDialog extends StatefulWidget {
  final String email;

  const _LegacyAccountDialog({required this.email});

  @override
  State<_LegacyAccountDialog> createState() => _LegacyAccountDialogState();
}

class _LegacyAccountDialogState extends State<_LegacyAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  String _t(String es, String pt) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : es;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_t('Conectar cuenta anterior', 'Conectar conta anterior')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Ya existe una cuenta de la API de StudyTrack con este correo. '
                      'Ingresá la contraseña que usabas en esa cuenta para vincularla '
                      'con tu acceso actual y conservar sus datos.',
                  'Já existe uma conta da API do StudyTrack com este e-mail. '
                      'Informe a senha que usava nessa conta para conectá-la '
                      'ao seu acesso atual e preservar os dados.',
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(widget.email),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: _t(
                    'Contraseña de la cuenta anterior',
                    'Senha da conta anterior',
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? _t('Ingresá la contraseña.', 'Informe a senha.')
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t('Cancelar', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_t('Conectar cuenta', 'Conectar conta')),
        ),
      ],
    );
  }
}
