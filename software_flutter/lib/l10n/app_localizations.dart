import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'history_title': 'Medication History',
      'profile': 'Profile',
      'language': 'Language',
      'taken': 'Taken',
      'missed': 'Missed',
      'all': 'All',
      'select_language': 'Select Language',
      'unknown': 'Unknown',
      'today': 'Today',
    },
    'ms': {
      'history_title': 'Sejarah Perubatan',
      'profile': 'Profil',
      'language': 'Bahasa',
      'taken': 'Diambil',
      'missed': 'Terlepas',
      'all': 'Semua',
      'select_language': 'Pilih Bahasa',
      'unknown': 'Tidak diketahui',
      'today': 'Hari Ini',
    },
    'zh': {
      'history_title': '用药历史',
      'profile': '个人资料',
      'language': '语言',
      'taken': '已服用',
      'missed': '未服用',
      'all': '全部',
      'select_language': '选择语言',
      'unknown': '未知',
      'today': '今天',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ms', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
