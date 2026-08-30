import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/main.dart';

void main() {
  testWidgets(
    'AutoCAD Google Earth app starts successfully',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const AutoCadGoogleEarthApp(),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('AutoCAD ↔ Google Earth'),
        findsWidgets,
      );
    },
  );
}
