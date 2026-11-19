import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/api_login.dart';
import '../services/legal_documents.dart';
import '../widgets/legal_consent.dart';
import 'dashboard_screen.dart';

// =====================================================
// REGISTRO DE USUARIOS - STUDYTRACK
// =====================================================
//
// Compatible con español y portugués brasileño.
//
// Utiliza el idioma seleccionado desde Login.
// Mantiene Firebase Authentication, validaciones,
// navegación y diseño blanco institucional.
//
// =====================================================

class RegisterScreen extends StatefulWidget {
  final Future<LegalDocuments> Function()? loadLegalDocuments;
  const RegisterScreen({super.key, this.loadLegalDocuments});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // =====================================================
  // COLOR INSTITUCIONAL
  // =====================================================

  static const Color bordo = Color(0xFF670810);

  // =====================================================
  // FORMULARIO Y CONTROLADORES
  // =====================================================

  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _cargando = false;
  bool _cuentaCreada = false;
  bool _mostrarPassword = false;
  bool _mostrarConfirmacion = false;
  LegalAcceptance? _legalAcceptance;

  // =====================================================
  // TRADUCCIONES
  // =====================================================

  // El idioma proviene del MaterialApp de StudyTrack.
  // No es necesario crear otro controlador.

  String _t(String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;

    return idioma == 'pt' ? pt : es;
  }

  // =====================================================
  // LIBERAR CONTROLADORES
  // =====================================================

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();

    super.dispose();
  }

  // =====================================================
  // MOSTRAR MENSAJES
  // =====================================================

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: bordo));
  }

  // =====================================================
  // ERRORES DE FIREBASE TRADUCIDOS
  // =====================================================

  String _mensajeFirebase(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':
        return _t(
          'Este correo ya está registrado.',
          'Este e-mail já está cadastrado.',
        );

      case 'invalid-email':
        return _t(
          'El correo electrónico no es válido.',
          'O endereço de e-mail não é válido.',
        );

      case 'weak-password':
        return _t(
          'La contraseña es demasiado débil.',
          'A senha é muito fraca.',
        );

      case 'operation-not-allowed':
        return _t(
          'El registro por correo no está habilitado.',
          'O cadastro por e-mail não está habilitado.',
        );

      case 'network-request-failed':
        return _t(
          'Revisá tu conexión a Internet.',
          'Verifique sua conexão com a Internet.',
        );

      case 'too-many-requests':
        return _t(
          'Demasiados intentos. '
              'Probá nuevamente más tarde.',
          'Muitas tentativas. '
              'Tente novamente mais tarde.',
        );

      default:
        return _t(
          'No se pudo crear la cuenta. '
              'Intentá nuevamente.',
          'Não foi possível criar a conta. '
              'Tente novamente.',
        );
    }
  }

  // =====================================================
  // REGISTRAR USUARIO EN FIREBASE
  // =====================================================

  Future<void> _registrarUsuario() async {
    if (_cargando) return;
    if (_cuentaCreada) {
      Navigator.pop(context);
      return;
    }
    if (_legalAcceptance == null) {
      _mostrarMensaje(
        _t(
          'Leé y aceptá los términos antes de crear tu cuenta.',
          'Leia e aceite os termos antes de criar sua conta.',
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      final nombre = _nombreController.text.trim();

      final correo = _correoController.text.trim();

      final password = _passwordController.text;

      // ========================================
      // CREAR CUENTA EN FIREBASE AUTHENTICATION
      // ========================================

      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: correo, password: password);
      _cuentaCreada = true;

      // ========================================
      // GUARDAR NOMBRE DEL ESTUDIANTE
      // ========================================

      try {
        await credencial.user?.updateDisplayName(nombre);
      } catch (error) {
        debugPrint('No se pudo actualizar el nombre: $error');
      }

      if (!mounted) return;
      if (!await connectApi(context, acceptance: _legalAcceptance)) return;
      if (!mounted) return;

      // ========================================
      // NAVEGAR AL DASHBOARD
      // ========================================

      // Se conserva el comportamiento original.

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _mostrarMensaje(
        _t(
              'La cuenta se creó. Volvé al inicio de sesión para intentar la conexión nuevamente. ',
              'A conta foi criada. Volte ao login para tentar a conexão novamente. ',
            ) +
            error.message,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _mostrarMensaje(_mensajeFirebase(error.code));
    } catch (error) {
      debugPrint('Error inesperado durante el registro: $error');

      if (!mounted) return;

      _mostrarMensaje(
        _t('Ocurrió un error inesperado.', 'Ocorreu um erro inesperado.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // =====================================================
  // DISEÑO DE LOS CAMPOS
  // =====================================================

  InputDecoration _decoracion(String etiqueta, IconData icono) {
    return InputDecoration(
      labelText: etiqueta,

      prefixIcon: Icon(icono, color: bordo),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: const BorderSide(color: bordo, width: 2),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // =====================================================
  // PANTALLA DE REGISTRO
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);

    // Igual que Login, Registro conserva un tema
    // claro propio. Esto evita problemas de contraste
    // si StudyTrack está en modo oscuro.

    final temaRegistro = ThemeData.light(useMaterial3: true).copyWith(
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
      data: temaRegistro,

      child: Scaffold(
        backgroundColor: Colors.white,

        // ========================================
        // APPBAR
        // ========================================
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: bordo,
          elevation: 0,

          title: Text(_t('Crear cuenta', 'Criar conta')),
        ),

        // ========================================
        // CONTENIDO PRINCIPAL
        // ========================================
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      // ================================
                      // LOGO STUDYTRACK
                      // ================================

                      Image.asset(
                        'assets/images/logo_studytrack.png',
                        height: 110,
                      ),

                      const SizedBox(height: 20),

                      // ================================
                      // BIENVENIDA
                      // ================================
                      Text(
                        _t(
                          '¡Bienvenido a StudyTrack!',
                          'Boas-vindas ao StudyTrack!',
                        ),

                        textAlign: TextAlign.center,

                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: bordo,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ================================
                      // DESCRIPCIÓN
                      // ================================
                      Text(
                        _t(
                          'Creá tu cuenta y comenzá '
                              'a organizar tus estudios.',
                          'Crie sua conta e comece '
                              'a organizar seus estudos.',
                        ),

                        textAlign: TextAlign.center,

                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ================================
                      // NOMBRE COMPLETO
                      // ================================
                      TextFormField(
                        controller: _nombreController,

                        textCapitalization: TextCapitalization.words,

                        textInputAction: TextInputAction.next,

                        decoration: _decoracion(
                          textos.authFullName,
                          Icons.person_outline,
                        ),

                        validator: (valor) {
                          if (valor == null || valor.trim().length < 3) {
                            return _t(
                              'Ingresá tu nombre completo.',
                              'Digite seu nome completo.',
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ================================
                      // CORREO ELECTRÓNICO
                      // ================================
                      TextFormField(
                        controller: _correoController,

                        keyboardType: TextInputType.emailAddress,

                        textInputAction: TextInputAction.next,

                        decoration: _decoracion(
                          textos.authEmail,
                          Icons.email_outlined,
                        ),

                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return _t(
                              'Ingresá tu correo.',
                              'Digite seu e-mail.',
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

                      const SizedBox(height: 16),

                      // ================================
                      // CONTRASEÑA
                      // ================================
                      TextFormField(
                        controller: _passwordController,

                        obscureText: !_mostrarPassword,

                        textInputAction: TextInputAction.next,

                        decoration:
                            _decoracion(
                              textos.authPassword,
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _mostrarPassword
                                    ? _t('Ocultar contraseña', 'Ocultar senha')
                                    : _t('Mostrar contraseña', 'Mostrar senha'),

                                icon: Icon(
                                  _mostrarPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),

                                onPressed: () {
                                  setState(() {
                                    _mostrarPassword = !_mostrarPassword;
                                  });
                                },
                              ),
                            ),

                        validator: (valor) {
                          if (valor == null || valor.isEmpty) {
                            return _t(
                              'Ingresá una contraseña.',
                              'Digite uma senha.',
                            );
                          }

                          if (valor.length < 6) {
                            return _t(
                              'Debe tener al menos '
                                  '6 caracteres.',
                              'A senha deve ter pelo '
                                  'menos 6 caracteres.',
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ================================
                      // CONFIRMAR CONTRASEÑA
                      // ================================
                      TextFormField(
                        controller: _confirmarController,

                        obscureText: !_mostrarConfirmacion,

                        textInputAction: TextInputAction.done,

                        onFieldSubmitted: (_) => _registrarUsuario(),

                        decoration:
                            _decoracion(
                              textos.authConfirmPassword,
                              Icons.lock_reset_outlined,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _mostrarConfirmacion
                                    ? _t('Ocultar contraseña', 'Ocultar senha')
                                    : _t('Mostrar contraseña', 'Mostrar senha'),

                                icon: Icon(
                                  _mostrarConfirmacion
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),

                                onPressed: () {
                                  setState(() {
                                    _mostrarConfirmacion =
                                        !_mostrarConfirmacion;
                                  });
                                },
                              ),
                            ),

                        validator: (valor) {
                          if (valor == null || valor.isEmpty) {
                            return _t(
                              'Confirmá tu contraseña.',
                              'Confirme sua senha.',
                            );
                          }

                          if (valor != _passwordController.text) {
                            return _t(
                              'Las contraseñas '
                                  'no coinciden.',
                              'As senhas não coincidem.',
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 20),
                      LegalConsentField(
                        loadDocuments: widget.loadLegalDocuments,
                        enabled: !_cargando && !_cuentaCreada,
                        onChanged: (value) =>
                            setState(() => _legalAcceptance = value),
                      ),
                      const SizedBox(height: 20),

                      // ================================
                      // BOTÓN CREAR CUENTA
                      // ================================
                      SizedBox(
                        height: 52,

                        child: ElevatedButton(
                          onPressed:
                              _cargando ||
                                  (!_cuentaCreada && _legalAcceptance == null)
                              ? null
                              : _registrarUsuario,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: bordo,
                            foregroundColor: Colors.white,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          child: _cargando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,

                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _cuentaCreada
                                      ? _t(
                                          'Volver al inicio de sesión',
                                          'Voltar ao login',
                                        )
                                      : _t(
                                          'Crear mi cuenta',
                                          'Criar minha conta',
                                        ),

                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ================================
                      // VOLVER AL LOGIN
                      // ================================
                      Wrap(
                        alignment: WrapAlignment.center,

                        crossAxisAlignment: WrapCrossAlignment.center,

                        children: [
                          Text(
                            _t('¿Ya tenés una cuenta? ', 'Já tem uma conta? '),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },

                            child: Text(
                              textos.authLogin,

                              style: const TextStyle(
                                color: bordo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
