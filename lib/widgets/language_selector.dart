import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  static const Locale vietnameseLocale = Locale('vi');
  static const Locale laoLocale = Locale('lo');
  static const Locale englishLocale = Locale('en');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.selectLanguage,
      child: PopupMenuButton<Locale>(
        key: const Key('language-selector'),
        tooltip: l10n.selectLanguage,
        initialValue: locale,
        onSelected: onLocaleChanged,
        itemBuilder: (context) => const [
          PopupMenuItem<Locale>(
            value: vietnameseLocale,
            child: Text('Tiếng Việt'),
          ),
          PopupMenuItem<Locale>(value: laoLocale, child: Text('ລາວ')),
          PopupMenuItem<Locale>(value: englishLocale, child: Text('English')),
        ],
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 20),
                const SizedBox(width: 8),
                Text(
                  _currentLanguageLabel(),
                  key: const Key('current-language-label'),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _currentLanguageLabel() {
    switch (locale.languageCode) {
      case 'lo':
        return 'ລາວ';
      case 'en':
        return 'English';
      case 'vi':
      default:
        return 'Tiếng Việt';
    }
  }
}
