import 'package:flutter/material.dart';

enum UnsavedChangesDecision { save, discard, cancel }

class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Project có thay đổi chưa lưu'),
      content: const Text(
        'Nếu tiếp tục, các thay đổi chưa lưu có thể bị mất. '
        'Bạn muốn lưu project trước không?',
      ),
      actions: [
        TextButton(
          key: const Key('unsaved-cancel'),
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.cancel),
          child: const Text('Hủy'),
        ),
        TextButton(
          key: const Key('unsaved-discard'),
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.discard),
          child: const Text('Không lưu'),
        ),
        FilledButton(
          key: const Key('unsaved-save'),
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.save),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
