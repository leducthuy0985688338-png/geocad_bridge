import 'package:autocad_googleearth/l10n/generated/app_localizations.dart';
import 'package:autocad_googleearth/main.dart';
import 'package:autocad_googleearth/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization Foundation', () {
    test('supports Vietnamese Lao and English locales', () {
      expect(
        AppLocalizations.supportedLocales,
        containsAll(const [Locale('vi'), Locale('lo'), Locale('en')]),
      );

      expect(AppLocalizations.supportedLocales.length, 3);
    });

    testWidgets('uses Vietnamese as the default locale', (tester) async {
      await tester.pumpWidget(const AutoCadGoogleEarthApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LanguageSelector));

      expect(Localizations.localeOf(context).languageCode, 'vi');

      expect(find.byKey(const Key('current-language-label')), findsOneWidget);

      expect(find.text('Tiếng Việt'), findsOneWidget);
    });

    testWidgets('can start directly in Lao locale', (tester) async {
      await tester.pumpWidget(
        const AutoCadGoogleEarthApp(initialLocale: Locale('lo')),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LanguageSelector));

      expect(Localizations.localeOf(context).languageCode, 'lo');

      expect(find.text('ລາວ'), findsOneWidget);

      expect(AppLocalizations.of(context).language, 'ພາສາ');

      expect(AppLocalizations.of(context).selectLanguage, 'ເລືອກພາສາ');
    });

    testWidgets('can start directly in English locale', (tester) async {
      await tester.pumpWidget(
        const AutoCadGoogleEarthApp(initialLocale: Locale('en')),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LanguageSelector));

      expect(Localizations.localeOf(context).languageCode, 'en');

      expect(find.text('English'), findsOneWidget);

      expect(AppLocalizations.of(context).language, 'Language');

      expect(AppLocalizations.of(context).selectLanguage, 'Select language');
    });

    testWidgets('switches from Vietnamese to Lao at runtime', (tester) async {
      await tester.pumpWidget(const AutoCadGoogleEarthApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();

      expect(find.text('Tiếng Việt'), findsWidgets);
      expect(find.text('ລາວ'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('ລາວ'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LanguageSelector));

      expect(Localizations.localeOf(context).languageCode, 'lo');

      expect(find.text('ລາວ'), findsOneWidget);

      expect(AppLocalizations.of(context).selectLanguage, 'ເລືອກພາສາ');
    });

    testWidgets('switches from Vietnamese to English at runtime', (
      tester,
    ) async {
      await tester.pumpWidget(const AutoCadGoogleEarthApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LanguageSelector));

      expect(Localizations.localeOf(context).languageCode, 'en');

      expect(find.text('English'), findsOneWidget);

      expect(AppLocalizations.of(context).selectLanguage, 'Select language');
    });
  });
}
