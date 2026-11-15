
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyTrackThemeController {
  static const String claveModoOscuro =
      'studytrack_modo_oscuro';

  static final SharedPreferencesAsync _preferencias =
      SharedPreferencesAsync();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  // Cargar la preferencia al abrir StudyTrack.
  static Future<void> inicializar() async {
    try {
      final modoOscuro =
          await _preferencias.getBool(claveModoOscuro) ??
              false;

      themeMode.value =
          modoOscuro ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      debugPrint('Error cargando el tema: $e');

      themeMode.value = ThemeMode.light;
    }
  }

  // Comprobar si está activado.
  static bool get modoOscuroActivado {
    return themeMode.value == ThemeMode.dark;
  }

  // Cambiar y guardar el modo oscuro.
  static Future<void> cambiarModoOscuro(
    bool activar,
  ) async {
    await _preferencias.setBool(
      claveModoOscuro,
      activar,
    );

    themeMode.value =
        activar ? ThemeMode.dark : ThemeMode.light;
  }
}
