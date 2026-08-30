import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/widgets/unsaved_changes_dialog.dart';

void main() {
  Future<UnsavedChangesDecision?> openAndChoose(
    WidgetTester tester,
    Key actionKey,
  ) async {
    UnsavedChangesDecision? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<UnsavedChangesDecision>(
                context: context,
                builder: (_) => const UnsavedChangesDialog(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Project có thay đổi chưa lưu'), findsOneWidget);
    expect(find.byKey(const Key('unsaved-save')), findsOneWidget);
    expect(find.byKey(const Key('unsaved-discard')), findsOneWidget);
    expect(find.byKey(const Key('unsaved-cancel')), findsOneWidget);
    await tester.tap(find.byKey(actionKey));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('returns Save decision', (tester) async {
    expect(
      await openAndChoose(tester, const Key('unsaved-save')),
      UnsavedChangesDecision.save,
    );
  });

  testWidgets('returns Discard decision', (tester) async {
    expect(
      await openAndChoose(tester, const Key('unsaved-discard')),
      UnsavedChangesDecision.discard,
    );
  });

  testWidgets('returns Cancel decision', (tester) async {
    expect(
      await openAndChoose(tester, const Key('unsaved-cancel')),
      UnsavedChangesDecision.cancel,
    );
  });
}
