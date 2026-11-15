
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'theme_controller.dart';

// Sistema de idiomas.
import 'services/language_controller.dart';
import 'l10n/app_localizations.dart';

// Servicio de notificaciones de StudyTrack.
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================
  // INICIALIZAR FIREBASE
  // ============================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================
  // RECUPERAR EL TEMA GUARDADO
  // ============================================

  await StudyTrackThemeController.inicializar();

  // ============================================
  // RECUPERAR EL IDIOMA GUARDADO
  // ============================================

  await languageController.loadSavedLanguage();

  // ============================================
  // CONFIGURAR FECHAS EN AMBOS IDIOMAS
  // ============================================

  await initializeDateFormatting('es');
  await initializeDateFormatting('pt');
  await initializeDateFormatting('pt_BR');

  // ============================================
  // INICIALIZAR NOTIFICACIONES EN ANDROID
  // ============================================

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android) {
    try {
      await NotificationService.initialize();

      debugPrint(
        'StudyTrack: notificaciones inicializadas.',
      );
    } catch (error) {
      debugPrint(
        'Error al iniciar notificaciones: $error',
      );
    }
  }

  // ============================================
  // INICIAR STUDYTRACK
  // ============================================

  runApp(const StudyTrackApp());
}

class StudyTrackApp extends StatelessWidget {
  const StudyTrackApp({super.key});

  // Bordó original para el modo claro.
  static const Color bordo = Color(0xFF670810);

  // Rojo más visible para el modo oscuro.
  static const Color rojoModoOscuro = Color(0xFFD65A68);

  // ============================================
  // TEMA CLARO
  // ============================================

  ThemeData get temaClaro {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      brightness: Brightness.light,

      colorScheme: ColorScheme.fromSeed(
        seedColor: bordo,
        brightness: Brightness.light,
      ),

      scaffoldBackgroundColor: const Color(0xFFF8F8F8),

      appBarTheme: const AppBarTheme(
        backgroundColor: bordo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      dividerColor: Colors.black12,

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================
  // TEMA OSCURO
  // ============================================

  ThemeData get temaOscuro {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: bordo,
        brightness: Brightness.dark,
      ).copyWith(
        // Nuevo rojo para los componentes
        // que usan el color primario del tema.
        primary: rojoModoOscuro,
        onPrimary: Colors.black,

        // Conservamos los fondos originales.
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
      ),

      scaffoldBackgroundColor: const Color(0xFF121212),

      // Barra superior con el rojo más claro.
      appBarTheme: const AppBarTheme(
        backgroundColor: rojoModoOscuro,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      dividerColor: Colors.white24,

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================
  // CONSTRUCCIÓN DE LA APLICACIÓN
  // ============================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageController,

      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable:
              StudyTrackThemeController.themeMode,

          builder: (context, modoActual, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,

              title: 'StudyTrack',

              // ====================================
              // CONFIGURACIÓN DE APARIENCIA
              // ====================================

              theme: temaClaro,
              darkTheme: temaOscuro,
              themeMode: modoActual,

              // ====================================
              // CONFIGURACIÓN DE IDIOMAS
              // ====================================

              locale: languageController.locale,

              supportedLocales:
                  AppLocalizations.supportedLocales,

              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,

              // ====================================
              // PANTALLA INICIAL
              // ====================================

              home: const LoginScreen(),
            );
          },
        );
      },
    );
  }
}
