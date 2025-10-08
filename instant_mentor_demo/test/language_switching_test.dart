import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instant_mentor_demo/core/providers/locale_provider.dart';
import 'package:instant_mentor_demo/core/localization/app_localizations.dart';

void main() {
  group('Language Switching Tests', () {
    testWidgets('Locale provider changes language correctly',
        (WidgetTester tester) async {
      final container = ProviderContainer();

      // Initial locale should be English (US)
      expect(container.read(localeProvider), const Locale('en', 'US'));

      // Change to Hindi
      container.read(localeProvider.notifier).changeLanguage('Hindi');
      expect(container.read(localeProvider), const Locale('hi', 'IN'));

      // Change to Tamil
      container.read(localeProvider.notifier).changeLanguage('Tamil');
      expect(container.read(localeProvider), const Locale('ta', 'IN'));

      // Change back to English
      container.read(localeProvider.notifier).changeLanguage('English');
      expect(container.read(localeProvider), const Locale('en', 'US'));

      container.dispose();
    });

    testWidgets('App localizations work for different languages',
        (WidgetTester tester) async {
      // Test English translations
      const englishLocale = Locale('en');
      expect(AppLocalizations.translate('settings', englishLocale), 'Settings');
      expect(AppLocalizations.translate('home', englishLocale), 'Home');
      expect(AppLocalizations.translate('profile', englishLocale), 'Profile');

      // Test Hindi translations
      const hindiLocale = Locale('hi');
      expect(AppLocalizations.translate('settings', hindiLocale), 'सेटिंग्स');
      expect(AppLocalizations.translate('home', hindiLocale), 'होम');
      expect(AppLocalizations.translate('profile', hindiLocale), 'प्रोफाइल');

      // Test Tamil translations
      const tamilLocale = Locale('ta');
      expect(AppLocalizations.translate('settings', tamilLocale), 'அமைப்புகள்');
      expect(AppLocalizations.translate('home', tamilLocale), 'முகப்பு');
      expect(AppLocalizations.translate('profile', tamilLocale), 'சுயவிவரம்');

      // Test Spanish translations
      const spanishLocale = Locale('es');
      expect(AppLocalizations.translate('settings', spanishLocale),
          'Configuración');
      expect(AppLocalizations.translate('home', spanishLocale), 'Inicio');
      expect(AppLocalizations.translate('profile', spanishLocale), 'Perfil');

      // Test French translations
      const frenchLocale = Locale('fr');
      expect(
          AppLocalizations.translate('settings', frenchLocale), 'Paramètres');
      expect(AppLocalizations.translate('home', frenchLocale), 'Accueil');
      expect(AppLocalizations.translate('profile', frenchLocale), 'Profil');
    });

    testWidgets('Language translations work correctly',
        (WidgetTester tester) async {
      // Test all supported languages have translations
      final supportedLanguages = ['en', 'hi', 'ta', 'te', 'bn', 'es', 'fr'];

      for (final languageCode in supportedLanguages) {
        final locale = Locale(languageCode);
        final settingsText = AppLocalizations.translate('settings', locale);
        final homeText = AppLocalizations.translate('home', locale);

        // Make sure translations exist and are not just fallback keys
        expect(settingsText, isNotEmpty);
        expect(homeText, isNotEmpty);
        expect(settingsText, isNot('settings')); // Should not be the key itself
        expect(homeText, isNot('home')); // Should not be the key itself
      }
    });
  });
}
