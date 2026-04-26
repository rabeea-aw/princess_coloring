import 'package:flutter/widgets.dart';

class AppTexts {
  final Locale locale;

  AppTexts(this.locale);

  static AppTexts of(BuildContext context) {
    return AppTexts(Localizations.localeOf(context));
  }

  bool get _isArabic => locale.languageCode.toLowerCase().startsWith('ar');

  String get appTitle => _isArabic ? 'تطبيق التلوين' : 'Coloring App';
  String get startColoring => _isArabic ? 'ابدأ التلوين' : 'Start Coloring';
  String get settingsTitle => _isArabic ? 'الإعدادات' : 'Settings';
  String get language => _isArabic ? 'اللغة' : 'Language';
  String get followDeviceLanguage =>
      _isArabic ? 'اتّباع لغة الجهاز' : 'Follow device language';
  String get english => _isArabic ? 'الإنجليزية' : 'English';
  String get arabic => _isArabic ? 'العربية' : 'Arabic';
  String get done => _isArabic ? 'تم' : 'Done';
}