import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/features/calendar/calendar_state.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';

void main() {
  late CalendarRepository repo;
  setUp(
    () => repo = CalendarRepository(
      DemoRepository().spaces,
      clock: () => DateTime(2026, 9, 22),
    ),
  );

  CalendarPlan save({
    String? id,
    String actor = 'me',
    String space = 'home',
    List<String> participants = const [],
    bool allDay = true,
    DateTime? start,
    DateTime? end,
  }) => repo.save(
    id: id,
    spaceId: space,
    actorId: actor,
    title: ' Shared plan ',
    participants: participants,
    start: start ?? DateTime(2028, 2, 28),
    end: end ?? DateTime(2028, 3, 1),
    allDay: allDay,
  );

  test('all-day spans leap day and excludes its end date', () {
    final plan = save();
    expect(plan.occursOn(DateTime(2028, 2, 28)), isTrue);
    expect(plan.occursOn(DateTime(2028, 2, 29)), isTrue);
    expect(plan.occursOn(DateTime(2028, 3, 1)), isFalse);
    expect(plan.occursOn(DateTime(2028, 2, 27)), isFalse);
    expect(plan.start.isUtc, isFalse);
  });

  test(
    'timed plans store UTC and intersect both local dates across midnight',
    () {
      final plan = save(
        allDay: false,
        start: DateTime(2026, 12, 31, 23),
        end: DateTime(2027, 1, 1, 1),
      );
      expect(plan.start.isUtc, isTrue);
      expect(plan.localStart, DateTime(2026, 12, 31, 23));
      expect(plan.occursOn(DateTime(2026, 12, 31)), isTrue);
      expect(plan.occursOn(DateTime(2027, 1, 1)), isTrue);
      expect(plan.occursOn(DateTime(2027, 1, 2)), isFalse);
    },
  );

  test(
    'Everyone deduplicates participants and person/space filters stay scoped',
    () {
      final plan = save(participants: ['alex', 'alex', 'jo']);
      final state = CalendarState(
        repo.plans,
        DateTime(2028, 2),
        DateTime(2028, 2, 29),
      );
      expect(plan.participants, ['alex', 'jo']);
      expect(state.forDay('home', null, state.selectedDay).map((p) => p.id), [
        plan.id,
      ]);
      for (final person in ['me', 'alex', 'jo']) {
        expect(state.forDay('home', person, state.selectedDay).length, 1);
      }
      expect(state.forDay('home', 'sam', state.selectedDay), isEmpty);
      expect(state.forDay('weekend', null, state.selectedDay), isEmpty);
    },
  );

  test('author edits preserve identity and others cannot edit or remove', () {
    final plan = save();
    expect(() => save(id: plan.id, actor: 'alex'), throwsStateError);
    expect(() => repo.remove(plan.id, 'alex'), throwsStateError);
    expect(() => save(id: plan.id, space: 'weekend'), throwsStateError);
    final updated = save(id: plan.id, participants: ['jo']);
    expect(updated.ownerId, 'me');
    expect(repo.plans.where((p) => p.id == plan.id).length, 1);
    repo.remove(plan.id, 'me');
    expect(repo.plans.any((p) => p.id == plan.id), isFalse);
  });

  test('invalid dates, outsiders and unknown participants are rejected', () {
    expect(() => save(end: DateTime(2028, 2, 28)), throwsArgumentError);
    expect(() => save(end: DateTime(2028, 2, 27)), throwsArgumentError);
    expect(() => save(actor: 'outsider'), throwsStateError);
    expect(() => save(participants: ['outsider']), throwsArgumentError);
  });

  test(
    'month lengths and December rollover leave stored schedules untouched',
    () {
      for (final sample in [
        (2027, 2, 28),
        (2028, 2, 29),
        (2026, 4, 30),
        (2026, 12, 31),
      ]) {
        final plan = save(
          start: DateTime(sample.$1, sample.$2, 1),
          end: DateTime(sample.$1, sample.$2 + 1, 1),
        );
        final days = List.generate(
          sample.$3 + 1,
          (i) => DateTime(sample.$1, sample.$2, i + 1),
        );
        expect(days.where(plan.occursOn).length, sample.$3);
      }
    },
  );
}
