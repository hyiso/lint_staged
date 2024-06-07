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

class ProcessesPool {
  final int? size;
  final Queue<ProcessTask> _tasks = Queue();
  final Map<ProcessTask, Future<ProcessResult>> _processes = {};
  final OnCompleted? onCompleted;

  ProcessesPool({
    required this.size,
    this.onCompleted,
  });

  Future<void> init({
    List<ProcessTask> tasks = const [],
    OnCompleted? onCompleted,
  }) async {
    _tasks.addAll(tasks);
  }

  Future<void> start({
    OnCompleted? onCompleted,
  }) async {
    if (size == null) {
      Future.wait(_tasks.map((task) async {
        await task.run();
        _tasks.remove(task);
      }).toList());
      return;
    }
    await Future.wait(List.generate(size!, (int index) {
      return runTask(onCompleted: onCompleted ?? this.onCompleted);
    }));
  }

  void addTask(ProcessTask task) {
    _tasks.add(task);
    if (size == null) {
      runTask(onCompleted: onCompleted);
    }
  }

  Future<ProcessResult> runTask({
    OnCompleted? onCompleted,
  }) {
    ProcessTask task = _tasks.removeFirst();
    Future<ProcessResult> process = task.run();
    _processes[task] = process;
    process.then((ProcessResult result) {
      _processes.remove(task);
      onCompleted?.call(result);
      runTask(onCompleted: onCompleted);
    });
    return process;
  }

  void close() {
    _tasks.clear();
    _processes.clear(); // Process.run does not return process instance
  }
}
