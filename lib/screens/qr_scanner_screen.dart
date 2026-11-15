import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  // ============================================
  // COLORES DE STUDYTRACK
  // ============================================

  static const Color bordo = Color(0xFF670810);
  static const Color coral = Color(0xFFE57373);

  // ============================================
  // SISTEMA DE TRADUCCIONES
  // ============================================

  // Las traducciones existentes se obtienen
  // directamente desde AppLocalizations.
  //
  // Esta función se utiliza para los mensajes
  // que todavía no tienen una clave en los ARB.
  //
  // Detecta el idioma actual de StudyTrack.

  String _t(BuildContext context, String es, String pt) {
    final idioma = Localizations.localeOf(context).languageCode;

    return idioma == 'pt' ? pt : es;
  }

  // ============================================
  // CONTROLADOR DEL ESCÁNER
  // ============================================

  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  String? _resultado;

  // ============================================
  // MOSTRAR MENSAJES
  // ============================================

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ============================================
  // DETECTAR CÓDIGO QR
  // ============================================

  void _detectarCodigo(BarcodeCapture captura) {
    if (!mounted || _resultado != null) return;

    for (final codigo in captura.barcodes) {
      final texto = codigo.rawValue;

      if (texto == null || texto.isEmpty) {
        continue;
      }

      setState(() {
        _resultado = texto;
      });

      // Detener la lectura después de detectar
      // un código para evitar escaneos repetidos.
      _controller.stop();

      break;
    }
  }

  // ============================================
  // ESCANEAR NUEVAMENTE
  // ============================================

  Future<void> _escanearNuevamente() async {
    setState(() {
      _resultado = null;
    });

    try {
      await _controller.start();
    } catch (error) {
      debugPrint('Error al reiniciar cámara QR: $error');

      if (!mounted) return;

      _mostrarMensaje(
        _t(
          context,
          'No se pudo reiniciar la cámara.',
          'Não foi possível reiniciar a câmera.',
        ),
      );
    }
  }

  // ============================================
  // COPIAR RESULTADO
  // ============================================

  Future<void> _copiarResultado() async {
    final texto = _resultado;

    if (texto == null) return;

    await Clipboard.setData(ClipboardData(text: texto));

    if (!mounted) return;

    _mostrarMensaje(_t(context, 'Contenido copiado.', 'Conteúdo copiado.'));
  }

  // ============================================
  // IDENTIFICAR ENLACES WEB
  // ============================================

  Uri? _obtenerEnlace(String? contenido) {
    if (contenido == null) return null;

    var texto = contenido.trim();

    if (texto.isEmpty) return null;

    // Permitir enlaces que comienzan con www.
    if (texto.toLowerCase().startsWith('www.')) {
      texto = 'https://$texto';
    }

    final enlace = Uri.tryParse(texto);

    if (enlace == null) return null;

    // Aceptar solamente HTTP y HTTPS.
    if (enlace.scheme != 'https' && enlace.scheme != 'http') {
      return null;
    }

    // Comprobar que exista un dominio.
    if (enlace.host.isEmpty) return null;

    // Rechazar enlaces con credenciales
    // incorporadas en la dirección.
    if (enlace.userInfo.isNotEmpty) {
      return null;
    }

    return enlace;
  }

  // ============================================
  // ABRIR ENLACE DEL CÓDIGO QR
  // ============================================

  Future<void> _abrirEnlace() async {
    final enlace = _obtenerEnlace(_resultado);

    if (enlace == null) return;

    bool abierto = false;

    try {
      // Android/iOS: navegador integrado.
      // Web: nueva pestaña del navegador.

      abierto = await launchUrl(
        enlace,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
        webOnlyWindowName: '_blank',
      );
    } catch (error) {
      debugPrint('Error al abrir enlace QR: $error');
    }

    // Si el navegador integrado no funciona,
    // intentar con el navegador externo.

    if (!abierto && !kIsWeb) {
      try {
        abierto = await launchUrl(enlace, mode: LaunchMode.externalApplication);
      } catch (error) {
        debugPrint('Error al abrir navegador externo: $error');
      }
    }

    if (!mounted) return;

    if (!abierto) {
      _mostrarMensaje(
        _t(
          context,
          'No se pudo abrir el enlace. '
              'Comprobá tu conexión o copiá la dirección.',
          'Não foi possível abrir o link. '
              'Verifique sua conexão ou copie o endereço.',
        ),
      );
    }
  }

  // ============================================
  // LIBERAR LA CÁMARA
  // ============================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================
  // INTERFAZ PRINCIPAL
  // ============================================

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    final textos = AppLocalizations.of(context);

    final esOscuro = tema.brightness == Brightness.dark;

    final colorAcento = esOscuro ? coral : bordo;

    final textoSobreAcento = esOscuro ? Colors.black : Colors.white;

    // Si el QR contiene una dirección web,
    // mostrar la opción para abrirla.

    final enlaceDetectado = _obtenerEnlace(_resultado);

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,

      // ========================================
      // APPBAR INSTITUCIONAL
      // ========================================
      appBar: AppBar(
        title: Text(textos.quickQrScanner),
        backgroundColor: bordo,
        foregroundColor: Colors.white,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [
              // =================================
              // ÍCONO PRINCIPAL
              // =================================

              Icon(Icons.qr_code_scanner, size: 52, color: colorAcento),

              const SizedBox(height: 12),

              // =================================
              // TÍTULO TRADUCIDO
              // =================================
              Text(
                _resultado == null
                    ? _t(context, 'Escaneá un código QR', 'Leia um código QR')
                    : _t(context, '¡Código detectado!', 'Código detectado!'),

                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),

                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // =================================
              // INSTRUCCIONES TRADUCIDAS
              // =================================
              Text(
                _resultado == null
                    ? _t(
                        context,
                        'Colocá el código QR frente '
                            'a la cámara.',
                        'Posicione o código QR '
                            'em frente à câmera.',
                      )
                    : _t(
                        context,
                        'El contenido del código '
                            'aparece abajo.',
                        'O conteúdo do código '
                            'aparece abaixo.',
                      ),

                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // =================================
              // CÁMARA O RESULTADO
              // =================================
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 440,
                      maxHeight: 440,
                    ),

                    child: _resultado == null
                        // =========================
                        // CÁMARA
                        // =========================
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),

                            child: Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,

                              children: [
                                MobileScanner(
                                  controller: _controller,
                                  onDetect: _detectarCodigo,

                                  // =====================
                                  // ERROR DE CÁMARA
                                  // =====================
                                  errorBuilder: (context, error) {
                                    return Container(
                                      color: colores.surface,

                                      padding: const EdgeInsets.all(20),

                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,

                                        children: [
                                          Icon(
                                            Icons.no_photography,
                                            color: colorAcento,
                                            size: 55,
                                          ),

                                          const SizedBox(height: 16),

                                          Text(
                                            _t(
                                              context,
                                              'No se pudo acceder '
                                                  'a la cámara.',
                                              'Não foi possível '
                                                  'acessar a câmera.',
                                            ),

                                            textAlign: TextAlign.center,

                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 10),

                                          Text(
                                            textos.qrCameraPermission,
                                            textAlign: TextAlign.center,
                                          ),

                                          const SizedBox(height: 10),

                                          Text(
                                            _t(
                                              context,
                                              'Comprobá que haya una '
                                                  'cámara disponible y '
                                                  'que el navegador o la '
                                                  'aplicación tengan '
                                                  'permiso para usarla.',
                                              'Verifique se há uma '
                                                  'câmera disponível e '
                                                  'se o navegador ou '
                                                  'o aplicativo tem '
                                                  'permissão para usá-la.',
                                            ),

                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // =========================
                                // MARCO DE ESCANEO
                                // =========================
                                IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      width: 230,
                                      height: 230,

                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: colorAcento,
                                          width: 4,
                                        ),

                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        // =========================
                        // RESULTADO DEL ESCANEO
                        // =========================
                        : Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),

                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 56,
                                  ),

                                  const SizedBox(height: 12),

                                  // =====================
                                  // TÍTULO DEL RESULTADO
                                  // =====================
                                  Text(
                                    _t(
                                      context,
                                      'Contenido del QR',
                                      'Conteúdo do QR',
                                    ),

                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),

                                    textAlign: TextAlign.center,
                                  ),

                                  const SizedBox(height: 12),

                                  // =====================
                                  // CONTENIDO DEL QR
                                  // =====================
                                  Flexible(
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        _resultado!,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // =====================
                                  // COPIAR CONTENIDO
                                  // =====================
                                  ElevatedButton.icon(
                                    onPressed: _copiarResultado,

                                    icon: const Icon(Icons.copy),

                                    label: Text(
                                      _t(
                                        context,
                                        'Copiar contenido',
                                        'Copiar conteúdo',
                                      ),
                                    ),

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorAcento,

                                      foregroundColor: textoSobreAcento,
                                    ),
                                  ),

                                  // =====================
                                  // ABRIR ENLACE QR
                                  // =====================
                                  if (enlaceDetectado != null) ...[
                                    const SizedBox(height: 12),

                                    // Mostrar el dominio
                                    // antes de abrirlo.
                                    Text(
                                      '${_t(context, 'Sitio', 'Site')}: ${enlaceDetectado.host}',

                                      textAlign: TextAlign.center,

                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colores.onSurfaceVariant,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    ElevatedButton.icon(
                                      onPressed: _abrirEnlace,

                                      icon: const Icon(Icons.open_in_new),

                                      label: Text(
                                        _t(
                                          context,
                                          'Abrir enlace',
                                          'Abrir link',
                                        ),
                                      ),

                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorAcento,

                                        foregroundColor: textoSobreAcento,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =================================
              // ESCANEAR OTRO QR
              // =================================
              if (_resultado != null)
                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton.icon(
                    onPressed: _escanearNuevamente,

                    icon: const Icon(Icons.qr_code_scanner),

                    label: Text(
                      _t(context, 'Escanear otro QR', 'Ler outro código QR'),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorAcento,

                      foregroundColor: textoSobreAcento,

                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // =================================
              // AVISO DE SEGURIDAD
              // =================================
              Text(
                enlaceDetectado != null
                    ? _t(
                        context,
                        'Abrí enlaces únicamente '
                            'si confiás en el sitio web.',
                        'Abra links somente '
                            'se confiar no site.',
                      )
                    : _t(
                        context,
                        'StudyTrack no abre '
                            'enlaces automáticamente.',
                        'O StudyTrack não abre '
                            'links automaticamente.',
                      ),

                style: tema.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
