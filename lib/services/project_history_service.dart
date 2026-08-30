import '../models/map_project.dart';

class ProjectHistoryService {
  final int maxHistory;

  final List<MapProject> _undoStack = [];
  final List<MapProject> _redoStack = [];

  ProjectHistoryService({
    this.maxHistory = 100,
  });

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;

  int get redoCount => _redoStack.length;

  void record(MapProject projectBeforeChange) {
    _undoStack.add(projectBeforeChange);

    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }

    _redoStack.clear();
  }

  MapProject? undo(MapProject currentProject) {
    if (_undoStack.isEmpty) {
      return null;
    }

    _redoStack.add(currentProject);

    return _undoStack.removeLast();
  }

  MapProject? redo(MapProject currentProject) {
    if (_redoStack.isEmpty) {
      return null;
    }

    _undoStack.add(currentProject);

    return _redoStack.removeLast();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}