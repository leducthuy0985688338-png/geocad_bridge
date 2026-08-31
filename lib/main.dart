import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/home_screen.dart';
import 'widgets/language_selector.dart';

void main() {
  runApp(const AutoCadGoogleEarthApp());
}

class AutoCadGoogleEarthApp extends StatefulWidget {
  const AutoCadGoogleEarthApp({
    super.key,
    this.initialLocale = const Locale('vi'),
  });

  final Locale initialLocale;

  @override
  State<AutoCadGoogleEarthApp> createState() => _AutoCadGoogleEarthAppState();
}

class _AutoCadGoogleEarthAppState extends State<AutoCadGoogleEarthApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void _changeLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }

    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: _LocalizedHome(locale: _locale, onLocaleChanged: _changeLocale),
    );
  }
}

class _LocalizedHome extends StatelessWidget {
  const _LocalizedHome({required this.locale, required this.onLocaleChanged});

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          const HomeScreen(),
          Positioned(
            top: 8,
            right: 12,
            child: SafeArea(
              child: LanguageSelector(
                locale: locale,
                onLocaleChanged: onLocaleChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
