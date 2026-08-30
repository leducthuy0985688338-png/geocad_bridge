import '../models/map_project.dart';

class ProjectDirtyStateService {
  MapProject _savedRevision;

  ProjectDirtyStateService(MapProject initialProject)
    : _savedRevision = initialProject;

  MapProject get savedRevision => _savedRevision;

  bool isDirty(MapProject currentProject) =>
      !identical(currentProject, _savedRevision);

  void markSaved(MapProject project) {
    _savedRevision = project;
  }
}
