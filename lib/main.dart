import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const AutoCadGoogleEarthApp());
}

class AutoCadGoogleEarthApp extends StatelessWidget {
  const AutoCadGoogleEarthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AutoCAD ↔ Google Earth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}