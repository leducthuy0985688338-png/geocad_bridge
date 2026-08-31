import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

enum UnsavedChangesDecision { save, discard, cancel }

class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.unsavedChangesTitle),
      content: Text(l10n.unsavedChangesMessage),
      actions: [
        TextButton(
          key: const Key('unsaved-cancel'),
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.cancel),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('unsaved-discard'),
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.discard),
          child: Text(l10n.discardChanges),
        ),
        FilledButton(
          key: const Key('unsaved-save'),
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.save),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
