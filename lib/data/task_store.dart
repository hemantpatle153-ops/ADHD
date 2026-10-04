import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/task.dart';

/// Persists every task. Implementations must be safe to call repeatedly.
abstract class TaskStore {
  Future<List<PlannerTask>> loadAll();
  Future<void> saveAll(List<PlannerTask> tasks);
}

/// Stores tasks as one JSON document on the device.
///
/// Writes go to a temporary file first and are then renamed over the real
/// file, so a crash mid-write never leaves a half-written plan behind.
class JsonFileTaskStore implements TaskStore {
  JsonFileTaskStore(this.directory);

  final Directory directory;
  static const _fileName = 'tasks.json';
  static const _schemaVersion = 1;

  File get _file => File('${directory.path}/$_fileName');

  // Serialises writes so two quick saves can't interleave.
  Future<void> _pending = Future.value();

  @override
  Future<List<PlannerTask>> loadAll() async {
    final file = _file;
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString());
      final list = raw is Map ? raw['tasks'] as List? : raw as List?;
      return (list ?? const [])
          .map((e) => PlannerTask.fromJson((e as Map).cast<String, Object?>()))
          .toList();
    } catch (e, st) {
      // Keep the unreadable file for recovery instead of overwriting it.
      debugPrint('Could not read tasks: $e\n$st');
      final backup = File(
        '${directory.path}/tasks.corrupt-${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.copy(backup.path);
      return [];
    }
  }

  @override
  Future<void> saveAll(List<PlannerTask> tasks) {
    final payload = jsonEncode({
      'version': _schemaVersion,
      'tasks': tasks.map((t) => t.toJson()).toList(),
    });
    return _pending = _pending.then((_) async {
      await directory.create(recursive: true);
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(_file.path);
    });
  }
}

/// In-memory store for tests and previews.
class MemoryTaskStore implements TaskStore {
  MemoryTaskStore([List<PlannerTask>? initial]) : _tasks = [...?initial];

  List<PlannerTask> _tasks;
  int saves = 0;

  @override
  Future<List<PlannerTask>> loadAll() async => [..._tasks];

  @override
  Future<void> saveAll(List<PlannerTask> tasks) async {
    saves++;
    _tasks = [...tasks];
  }
}
