import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';

// =====================================================
// RECUPERACIÓN DE CONTRASEÑA - STUDYTRACK
// =====================================================
//
// Compatible con español y portugués brasileño.
//
// El idioma se obtiene del MaterialApp principal.
//
// Mantiene:
// - Firebase Authentication
// - Validación del correo
// - Envío del enlace de recuperación
// - Pantalla de confirmación
// - Reenvío del enlace
// - Navegación al Login
//
// =====================================================

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // =====================================================
  // COLOR INSTITUCIONAL
  // =====================================================

  static const Color bordo = Color(0xFF670810);

  // =====================================================
  // FORMULARIO
  // =====================================================

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController correoController;

  bool cargando = false;
  bool correoSolicitado = false;

  // =====================================================
  // TRADUCCIONES
  // =====================================================

  String _t(String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;

    return idioma == 'pt' ? pt : es;
  }

  // =====================================================
  // INICIALIZAR CORREO
  // =====================================================

  @override
  void initState() {
    super.initState();

    correoController = TextEditingController(text: widget.initialEmail);
  }

  // =====================================================
  // LIBERAR CONTROLADOR
  // =====================================================

  @override
  void dispose() {
    correoController.dispose();
    super.dispose();
  }

  // =====================================================
  // MOSTRAR MENSAJES
  // =====================================================

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: bordo));
  }

  // =====================================================
  // ENVIAR CORREO DE RECUPERACIÓN
  // =====================================================

  Future<void> recuperarContrasena() async {
    if (cargando) return;

    // Validar el formulario antes del primer envío.
    // Después de solicitarlo, se permite reenviar
    // sin depender del formulario anterior.

    if (!correoSolicitado) {
      if (_formKey.currentState?.validate() != true) {
        return;
      }
    }

    final correo = correoController.text.trim().toLowerCase();

    setState(() {
      cargando = true;
    });

    try {
      // ========================================
      // FIREBASE AUTHENTICATION
      // ========================================

      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);

      if (!mounted) return;

      setState(() {
        correoSolicitado = true;
      });

      mostrarMensaje(
        _t(
          'Solicitud de recuperación procesada.',
          'Solicitação de recuperação processada.',
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String mensaje = _t(
        'No se pudo solicitar la recuperación.',
        'Não foi possível solicitar '
            'a recuperação de senha.',
      );

      // ========================================
      // ERRORES DE FIREBASE
      // ========================================

      if (error.code == 'invalid-email') {
        mensaje = _t(
          'El correo electrónico no es válido.',
          'O endereço de e-mail não é válido.',
        );
      } else if (error.code == 'network-request-failed') {
        mensaje = _t(
          'Revisá tu conexión a Internet.',
          'Verifique sua conexão com a Internet.',
        );
      } else if (error.code == 'too-many-requests') {
        mensaje = _t(
          'Demasiados intentos. Probá más tarde.',
          'Muitas tentativas. Tente mais tarde.',
        );
      } else if (error.code == 'user-not-found') {
        // No revelar si existe una cuenta asociada
        // al correo electrónico ingresado.

        setState(() {
          correoSolicitado = true;
        });

        mensaje = _t(
          'Solicitud de recuperación procesada.',
          'Solicitação de recuperação processada.',
        );
      } else if (error.code == 'operation-not-allowed') {
        mensaje = _t(
          'La recuperación no está habilitada '
              'en Firebase.',
          'A recuperação de senha não está '
              'habilitada no Firebase.',
        );
      }

      mostrarMensaje(mensaje);
    } catch (error) {
      debugPrint('Error inesperado en recuperación: $error');

      if (!mounted) return;

      mostrarMensaje(
        _t(
          'Ocurrió un error inesperado. '
              'Intentá nuevamente.',
          'Ocorreu um erro inesperado. '
              'Tente novamente.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  // =====================================================
  // PANTALLA DESPUÉS DE SOLICITAR EL CORREO
  // =====================================================

  Widget pantallaConfirmacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        // ========================================
        // ÍCONO DE CONFIRMACIÓN
        // ========================================

        const Icon(Icons.mark_email_read_outlined, color: bordo, size: 90),

        const SizedBox(height: 25),

        // ========================================
        // TÍTULO
        // ========================================
        Text(
          _t('Revisá tu correo', 'Verifique seu e-mail'),

          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: bordo,
          ),
        ),

        const SizedBox(height: 15),

        // ========================================
        // EXPLICACIÓN
        // ========================================
        Text(
          _t(
            'Si existe una cuenta de StudyTrack '
                'asociada a esta dirección, recibirás '
                'un enlace para cambiar tu contraseña.',
            'Se existir uma conta do StudyTrack '
                'associada a este endereço, você '
                'receberá um link para alterar sua senha.',
          ),

          textAlign: TextAlign.center,

          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),

        const SizedBox(height: 15),

        // ========================================
        // CORREO INGRESADO
        // ========================================
        Text(
          correoController.text.trim(),

          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 20),

        // ========================================
        // INSTRUCCIONES
        // ========================================
        Text(
          _t(
            'Abrí tu correo, revisá también la '
                'carpeta de Spam y seguí las '
                'instrucciones del mensaje.',
            'Abra seu e-mail, confira também '
                'a pasta de Spam e siga as '
                'instruções da mensagem.',
          ),

          textAlign: TextAlign.center,

          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),

        const SizedBox(height: 30),

        // ========================================
        // VOLVER AL LOGIN
        // ========================================
        SizedBox(
          height: 52,

          child: ElevatedButton(
            onPressed: cargando ? null : () => Navigator.pop(context),

            style: ElevatedButton.styleFrom(
              backgroundColor: bordo,
              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            child: Text(
              _t('VOLVER AL LOGIN', 'VOLTAR AO LOGIN'),

              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ========================================
        // REENVIAR ENLACE
        // ========================================
        TextButton(
          onPressed: cargando ? null : recuperarContrasena,

          child: Text(
            _t(
              'Reenviar enlace de recuperación',
              'Reenviar link de recuperação',
            ),

            style: const TextStyle(color: bordo, fontWeight: FontWeight.w600),
          ),
        ),

        // ========================================
        // INDICADOR DE ENVÍO
        // ========================================
        if (cargando)
          const Padding(
            padding: EdgeInsets.all(12),

            child: Center(child: CircularProgressIndicator(color: bordo)),
          ),
      ],
    );
  }

  // =====================================================
  // FORMULARIO DE RECUPERACIÓN
  // =====================================================

  Widget formularioRecuperacion() {
    final textos = AppLocalizations.of(context);

    return Form(
      key: _formKey,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          // ========================================
          // ÍCONO
          // ========================================

          const Icon(Icons.lock_reset_outlined, color: bordo, size: 85),

          const SizedBox(height: 20),

          // ========================================
          // TÍTULO
          // ========================================
          Text(
            textos.authForgotPassword,

            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: bordo,
            ),
          ),

          const SizedBox(height: 15),

          // ========================================
          // INSTRUCCIONES
          // ========================================
          Text(
            _t(
              'Ingresá el correo electrónico '
                  'asociado a tu cuenta de StudyTrack.',
              'Digite o endereço de e-mail '
                  'associado à sua conta do StudyTrack.',
            ),

            textAlign: TextAlign.center,

            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),

          const SizedBox(height: 35),

          // ========================================
          // CORREO ELECTRÓNICO
          // ========================================
          Text(
            textos.authEmail,

            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: correoController,

            keyboardType: TextInputType.emailAddress,

            textInputAction: TextInputAction.done,

            onFieldSubmitted: (_) {
              recuperarContrasena();
            },

            style: const TextStyle(color: Colors.black87, fontSize: 16),

            cursorColor: bordo,

            decoration: InputDecoration(
              hintText: _t('ejemplo@gmail.com', 'exemplo@gmail.com'),

              hintStyle: const TextStyle(color: Colors.black45),

              prefixIcon: const Icon(Icons.email_outlined, color: bordo),

              filled: true,
              fillColor: Colors.white,

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),

                borderSide: const BorderSide(color: bordo, width: 2),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),

                borderSide: const BorderSide(color: Colors.black26),
              ),

              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),

                borderSide: const BorderSide(color: Colors.red),
              ),

              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),

                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),

            // ====================================
            // VALIDACIÓN
            // ====================================
            validator: (valor) {
              if (valor == null || valor.trim().isEmpty) {
                return _t(
                  'Ingresá tu correo electrónico.',
                  'Digite seu endereço de e-mail.',
                );
              }

              final correoValido = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(valor.trim());

              if (!correoValido) {
                return _t(
                  'Ingresá un correo válido.',
                  'Digite um e-mail válido.',
                );
              }

              return null;
            },
          ),

          const SizedBox(height: 28),

          // ========================================
          // ENVIAR ENLACE DE RECUPERACIÓN
          // ========================================
          SizedBox(
            height: 52,

            child: ElevatedButton(
              onPressed: cargando ? null : recuperarContrasena,

              style: ElevatedButton.styleFrom(
                backgroundColor: bordo,
                foregroundColor: Colors.white,
                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,

                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _t('ENVIAR ENLACE', 'ENVIAR LINK'),

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // ========================================
          // VOLVER AL LOGIN
          // ========================================
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },

            icon: const Icon(Icons.arrow_back, color: bordo),

            label: Text(
              _t('Volver al inicio de sesión', 'Voltar para o login'),

              style: const TextStyle(color: bordo, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PANTALLA PRINCIPAL
  // =====================================================

  @override
  Widget build(BuildContext context) {
    // Mantenemos un tema claro propio, como
    // en Login y Registro, independientemente
    // del modo oscuro del resto de StudyTrack.

    final temaRecuperacion = ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: bordo,
        brightness: Brightness.light,
      ),

      scaffoldBackgroundColor: Colors.white,

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: bordo,
        selectionHandleColor: bordo,
      ),
    );

    return Theme(
      data: temaRecuperacion,

      child: Scaffold(
        backgroundColor: Colors.white,

        // ========================================
        // APPBAR
        // ========================================
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: bordo,
          elevation: 0,

          title: Text(_t('Recuperar contraseña', 'Recuperar senha')),
        ),

        // ========================================
        // CONTENIDO
        // ========================================
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),

              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),

                child: correoSolicitado
                    ? pantallaConfirmacion()
                    : formularioRecuperacion(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
