import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import 'persistent_settings_provider.dart';

// Locale notifier for better state management
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._ref) : super(const Locale('en', 'US')) {
    // Listen to language changes and update locale
    _ref.listen(languageProvider, (previous, next) {
      state = AppLocalizations.getLocaleFromLanguageName(next);
    });

    // Initialize with current language
    final currentLanguage = _ref.read(languageProvider);
    state = AppLocalizations.getLocaleFromLanguageName(currentLanguage);
  }

  final Ref _ref;

  void changeLanguage(String languageName) {
    // Update the language provider which will trigger locale change
    _ref.read(languageProvider.notifier).state = languageName;
    // Update the locale state
    state = AppLocalizations.getLocaleFromLanguageName(languageName);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref);
});

// Helper function to get translations
String tr(String key, WidgetRef ref) {
  final locale = ref.watch(localeProvider);
  return AppLocalizations.translate(key, locale);
}
