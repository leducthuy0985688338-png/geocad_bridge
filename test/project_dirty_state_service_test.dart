import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/services/project_dirty_state_service.dart';

void main() {
  const initial = MapProject(id: 'initial', name: 'Initial');

  test('initial and explicitly saved project revisions are clean', () {
    final tracker = ProjectDirtyStateService(initial);
    expect(tracker.isDirty(initial), isFalse);

    final edited = initial.copyWith(name: 'Edited');
    tracker.markSaved(edited);
    expect(tracker.isDirty(edited), isFalse);
  });

  test('a different root project revision is dirty', () {
    final tracker = ProjectDirtyStateService(initial);
    final edited = initial.copyWith(name: 'Edited');
    expect(tracker.isDirty(edited), isTrue);
  });

  test('undo and redo use saved revision identity semantics', () {
    final revisionA = initial;
    final revisionB = revisionA.copyWith(name: 'B');
    final revisionC = revisionB.copyWith(name: 'C');
    final tracker = ProjectDirtyStateService(revisionB);

    expect(tracker.isDirty(revisionC), isTrue);
    expect(tracker.isDirty(revisionB), isFalse);
    expect(tracker.isDirty(revisionA), isTrue);
    expect(tracker.isDirty(revisionB), isFalse);
  });
}
