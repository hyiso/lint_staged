import 'dart:io';

import 'package:lint_staged/src/processes_pool.dart';
import 'package:test/test.dart';

void main() {
  group('CommandLineProcessesPool', () {
    const size = 4;
    const second = 2;
    const command = 'sleep';
    final task = ProcessTask(command, ['$second']);
    test('should be able to pass size parameter', () {
      ProcessesPool pool = ProcessesPool(size: size);
      expect(pool.size, size);
    });

    test('should be able to add one task', () {
      ProcessesPool pool = ProcessesPool(size: size);
      pool.addTask(task);
      expect(pool.tasksNumber, 1);
    });
    test('should be able to add multiple task', () {
      final List<ProcessTask> tasks =
          List.filled(Platform.numberOfProcessors, task);
      ProcessesPool pool = ProcessesPool(size: size);
      pool.addAll(tasks: tasks);
      expect(pool.tasksNumber, tasks.length);
    });
    test('should be able to run all tasks at the same time when size is null',
        () async {
      final List<ProcessTask> tasks =
          List.filled(Platform.numberOfProcessors, task);
      ProcessesPool pool = ProcessesPool();
      pool.addAll(tasks: tasks);
      Stopwatch stopwatch = Stopwatch()..start();
      await pool.start();
      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(second * 2));
    });
    test('should be able to limit running task if provided size', () async {
      final List<ProcessTask> tasks =
          List.filled(Platform.numberOfProcessors, task);
      ProcessesPool pool = ProcessesPool(size: size);
      pool.addAll(tasks: tasks);
      Stopwatch stopwatch = Stopwatch()..start();
      await pool.start();
      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds,
          lessThan(Platform.numberOfProcessors ~/ 2 + 1));
    });
  });
}
