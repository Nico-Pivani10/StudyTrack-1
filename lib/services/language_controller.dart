
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends ChangeNotifier {
  static const String _storageKey = 'studytrack_language';

  // Español como idioma inicial.
  Locale _locale = const Locale('es');

  // Idioma actualmente seleccionado.
  Locale get locale => _locale;

  // Código del idioma para usarlo en Perfil.
  String get languageCode {
    if (_locale.languageCode == 'pt') {
      return 'pt_BR';
    }

    return 'es';
  }

  bool get isPortuguese => _locale.languageCode == 'pt';

  // ==================================================
  // CARGAR EL IDIOMA GUARDADO
  // ==================================================

  Future<void> loadSavedLanguage() async {
    final preferences = await SharedPreferences.getInstance();

    final savedLanguage = preferences.getString(_storageKey);

    if (savedLanguage == 'pt_BR' || savedLanguage == 'pt') {
      _locale = const Locale('pt', 'BR');
    } else {
      _locale = const Locale('es');
    }

    notifyListeners();
  }

  // ==================================================
  // CAMBIAR EL IDIOMA
  // ==================================================

  Future<void> setLanguage(String code) async {
    late final Locale newLocale;
    late final String newCode;

    if (code == 'es') {
      newLocale = const Locale('es');
      newCode = 'es';
    } else if (code == 'pt' || code == 'pt_BR') {
      newLocale = const Locale('pt', 'BR');
      newCode = 'pt_BR';
    } else {
      throw ArgumentError('Idioma no compatible: $code');
    }

    if (_locale == newLocale) return;

    // Guardar la preferencia.
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_storageKey, newCode);

    // Aplicar el idioma seleccionado.
    _locale = newLocale;

    // Notificar a las pantallas que escuchan los cambios.
    notifyListeners();
  }

  // ==================================================
  // RESTABLECER EL IDIOMA PREDETERMINADO
  // ==================================================

  Future<void> resetLanguage() async {
    await setLanguage('es');
  }
}

// Instancia compartida por toda la aplicación.
final languageController = LanguageController();
