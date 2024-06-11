import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

typedef OnCompleted = void Function(ProcessResult result);

class ProcessTask {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final bool includeParentEnvironment;
  final bool runInShell;
  final Encoding? stdoutEncoding;
  final Encoding? stderrEncoding;
  final OnCompleted? onCompleted;

  /// The copy of the parameter of Process.run()
  const ProcessTask(
    this.executable,
    this.arguments, {
    this.workingDirectory,
    this.environment,
    this.includeParentEnvironment = true,
    this.runInShell = false,
    this.stdoutEncoding = systemEncoding,
    this.stderrEncoding = systemEncoding,
    this.onCompleted,
  });

  Future<ProcessResult> run() async {
    ProcessResult result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
    Process.killPid(result.pid);
    return result;
  }
}

class ProcessEntity {
  final ProcessTask task;
  final Future<ProcessResult> process;
  const ProcessEntity({
    required this.task,
    required this.process,
  });
}

class ProcessesPool {
  final int? size;
  final Queue<ProcessTask> _tasks = Queue();
  final List<ProcessEntity?> _processes = [];
  bool isStarted = false;

  int get tasksNumber => _tasks.length;

  ProcessesPool({
    this.size,
  });

  void addAll({
    List<ProcessTask> tasks = const [],
  }) async {
    _tasks.addAll(tasks);
  }

  void addTask(ProcessTask task) {
    _tasks.add(task);
  }

  Future<void> start({
    OnCompleted? onCompleted,
  }) async {
    if (isStarted) {
      throw Exception('You have already started');
    }
    isStarted = true;
    if (size == null) {
      await Future.wait(_tasks.map((task) async {
        ProcessResult result = await task.run();
        (onCompleted ?? task.onCompleted)?.call(result);
        _tasks.remove(task);
      }).toList());
      isStarted = false;
      return;
    }
    _processes.addAll(List.filled(size!, null));
    await Future.wait(List.generate(size!, (int index) async {
      return _runTaskSync(
        index: index,
        onCompleted: onCompleted,
      );
    }));
    isStarted = false;
  }

  Future<ProcessResult?> _runTaskSync({
    required int index,
    OnCompleted? onCompleted,
  }) async {
    if (_tasks.isEmpty) return null;
    ProcessTask task = _tasks.removeFirst();
    Future<ProcessResult> process = task.run();
    ProcessEntity entity = ProcessEntity(process: process, task: task);
    _processes[index] = entity;
    ProcessResult result = await process;
    _processes[index] = null;
    (onCompleted ?? task.onCompleted)?.call(result);

    return _runTaskSync(
      index: index,
      onCompleted: onCompleted ?? task.onCompleted,
    );
  }

  void close() {
    _tasks.clear();
    _processes.clear(); // Process.run does not return process instance
  }
}
