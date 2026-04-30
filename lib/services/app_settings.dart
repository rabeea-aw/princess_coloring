import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  device,
  english,
  arabic,
}

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _languageKey = 'app_language';

  SharedPreferences? _prefs;
  AppLanguage _language = AppLanguage.device;

  AppLanguage get language => _language;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs?.getString(_languageKey);
    _language = _fromRaw(raw);
  }

  Locale resolveLocale(Locale deviceLocale) {
    switch (_language) {
      case AppLanguage.english:
        return const Locale('en');

      case AppLanguage.arabic:
        return const Locale('ar');

      case AppLanguage.device:
        if (deviceLocale.languageCode == 'ar') {
          return const Locale('ar');
        }
        return const Locale('en');
    }
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;

    _language = value;
    await _prefs?.setString(_languageKey, _toRaw(value));

    notifyListeners();
  }

  String _toRaw(AppLanguage value) {
    switch (value) {
      case AppLanguage.device:
        return 'device';

      case AppLanguage.english:
        return 'en';

      case AppLanguage.arabic:
        return 'ar';
    }
  }

  AppLanguage _fromRaw(String? raw) {
    switch (raw) {
      case 'en':
        return AppLanguage.english;

      case 'ar':
        return AppLanguage.arabic;

      case 'device':
      default:
        return AppLanguage.device;
    }
  }
}