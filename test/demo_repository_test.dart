import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';

void main() {
  late DemoRepository repo;
  var now = DateTime(2026, 9, 22, 12);
  setUp(() {
    now = DateTime(2026, 9, 22, 12);
    repo = DemoRepository(clock: () => now, delay: Duration.zero);
  });
  Task task(String id) => repo.tasks.firstWhere((task) => task.id == id);

  test('requests require acceptance; decline returns to unclaimed', () async {
    expect(task('plants').ownerId, isNull);
    await expectLater(
      repo.act('plants', TaskAction.complete, 'me'),
      throwsA(isA<DemoException>()),
    );
    await repo.act('plants', TaskAction.decline, 'me');
    expect(task('plants').status, Responsibility.unclaimed);
    expect(task('plants').requestedId, isNull);
    await repo.act('plants', TaskAction.accept, 'me');
    await repo.act('plants', TaskAction.complete, 'me');
    expect(task('plants').isDone, isTrue);
    expect(task('plants').completedAt, now);
  });

  test('help offer keeps owner; only current owner confirms handoff', () async {
    await repo.act('groceries', TaskAction.offerHelp, 'me');
    expect(task('groceries').ownerId, 'sam');
    expect(task('groceries').offeredId, 'me');
    await expectLater(
      repo.act('groceries', TaskAction.confirmHandoff, 'me'),
      throwsA(isA<DemoException>()),
    );
    await repo.act('laundry', TaskAction.confirmHandoff, 'me');
    expect(task('laundry').ownerId, 'alex');
    expect(task('laundry').offeredId, isNull);
    await expectLater(
      repo.act('laundry', TaskAction.complete, 'me'),
      throwsA(isA<DemoException>()),
    );
  });

  test(
    'failed write leaves responsibility unchanged and permits retry',
    () async {
      repo.nextOutcome = DemoOutcome.failure;
      await expectLater(
        repo.act('dinner', TaskAction.complete, 'me'),
        throwsA(isA<DemoException>()),
      );
      expect(task('dinner').isDone, isFalse);
      await repo.act('dinner', TaskAction.complete, 'me');
      expect(task('dinner').isDone, isTrue);
    },
  );

  test(
    'claim conflict refreshes owner; duplicate actions cannot double-apply',
    () async {
      repo.nextOutcome = DemoOutcome.conflict;
      await expectLater(
        repo.act('recycling', TaskAction.accept, 'me'),
        throwsA(isA<DemoException>()),
      );
      expect(task('recycling').ownerId, 'alex');
      final first = repo.act('dinner', TaskAction.complete, 'me');
      await expectLater(
        repo.act('dinner', TaskAction.complete, 'me'),
        throwsA(isA<DemoException>()),
      );
      await first;
      expect(
        task('dinner').activity
            .where((entry) => entry.contains('marked'))
            .length,
        1,
      );
    },
  );

  test(
    'person filter includes requested ownership and event participation',
    () {
      expect(task('plants').matchesPerson('me'), isTrue);
      expect(task('walk').matchesPerson('me'), isTrue);
      expect(task('walk').matchesPerson('sam'), isFalse);
      expect(task('recycling').matchesPerson('me'), isFalse);
      expect(task('recycling').matchesPerson(null), isTrue);
    },
  );

  test('Basic keeps unfinished work and exactly four completion dates', () {
    expect(visibleToBasic(task('recycling'), now), isTrue);
    Task completed(DateTime at) => Task(
      id: 'history',
      spaceId: 'home',
      title: 'Old task',
      day: DateTime(2020),
      status: Responsibility.completed,
      completedAt: at,
    );
    expect(visibleToBasic(completed(DateTime(2026, 9, 19)), now), isTrue);
    expect(
      visibleToBasic(completed(DateTime(2026, 9, 18, 23, 59)), now),
      isFalse,
    );
  });

  test('simulated claim conflict stays within the task space', () async {
    final added = await repo.addTask('weekend', 'Pack a picnic', now, false);
    repo.nextOutcome = DemoOutcome.conflict;
    await expectLater(
      repo.act(added.id, TaskAction.accept, 'me'),
      throwsA(isA<DemoException>()),
    );
    expect(task(added.id).ownerId, 'lee');
  });

  test('moods are per space, editable, removable, and expire at midnight', () {
    repo.shareCheckIn('home', 'me', Mood.tired, '  Long day  ');
    expect(repo.checkIn('home', 'me')?.note, 'Long day');
    expect(repo.checkIn('weekend', 'me'), isNull);
    repo.shareCheckIn('home', 'me', Mood.calm, '');
    expect(repo.checkIn('home', 'me')?.mood, Mood.calm);
    now = DateTime(2026, 9, 23);
    expect(repo.checkIn('home', 'me'), isNull);
    repo.shareCheckIn('home', 'me', Mood.happy, '');
    repo.removeCheckIn('home', 'me');
    expect(repo.checkIn('home', 'me'), isNull);
  });
}
