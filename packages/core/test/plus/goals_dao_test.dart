import 'package:core/models/media_type.dart';
import 'package:core/plus/database/goals_dao.dart';
import 'package:core/plus/models/yearly_goal.dart';
import 'package:test/test.dart';

import 'plus_test_db.dart';

void main() {
  late PlusTestDb t;
  late GoalsDao dao;
  final DateTime t0 = DateTime(2026, 1, 3);

  setUp(() async {
    t = await PlusTestDb.open();
    dao = GoalsDao(() async => t.db);
  });
  tearDown(() async => t.close());

  YearlyGoal draft(GoalMetric metric, int target, {MediaType? type}) =>
      YearlyGoal(
        id: 0,
        year: 2026,
        metric: metric,
        mediaType: type,
        target: target,
        createdAt: t0,
        updatedAt: t0,
      );

  group('GoalsDao', () {
    group('goals', () {
      test('saves, lists by year and deletes', () async {
        final YearlyGoal saved = await dao.saveGoal(
          draft(GoalMetric.completed, 30),
        );
        expect(saved.id, isNot(0));
        expect(await dao.getGoals(2026), hasLength(1));
        expect(await dao.getGoals(2025), isEmpty);

        await dao.deleteGoal(saved.id);
        expect(await dao.getGoals(2026), isEmpty);
      });

      test('a new goal replaces the same year, metric and type', () async {
        await dao.saveGoal(draft(GoalMetric.completed, 30));
        await dao.saveGoal(
          draft(GoalMetric.completed, 10, type: MediaType.book),
        );
        await dao.saveGoal(draft(GoalMetric.completed, 40));

        final List<YearlyGoal> goals = await dao.getGoals(2026);
        expect(goals, hasLength(2));
        expect(
          goals.firstWhere((YearlyGoal g) => g.mediaType == null).target,
          40,
        );
      });

      test('editing keeps the id', () async {
        final YearlyGoal saved = await dao.saveGoal(
          draft(GoalMetric.hours, 50),
        );
        await dao.saveGoal(saved.copyWith(target: 80));
        final YearlyGoal reloaded = (await dao.getGoals(2026)).single;
        expect(reloaded.id, saved.id);
        expect(reloaded.target, 80);
      });

      test('a target below one is stored as one', () async {
        await dao.saveGoal(draft(GoalMetric.completed, 0));
        expect((await dao.getGoals(2026)).single.target, YearlyGoal.minTarget);
      });
    });

    group('time to beat cache', () {
      test('stores answers, remembers misses and expires', () async {
        await dao.saveTimeToBeat(
          requested: <int>[1, 2],
          found: <int, ({int? hastily, int? normally, int? completely})>{
            1: (hastily: 3600, normally: 7200, completely: null),
          },
          now: t0,
        );

        expect(await dao.getTimeToBeat(<int>[1, 2, 3]), <int, int>{1: 7200});
        expect(
          await dao.idsNeedingTimeToBeat(<int>[
            1,
            2,
            3,
          ], staleBefore: t0.subtract(const Duration(days: 1))),
          <int>[3],
        );
        expect(
          await dao.idsNeedingTimeToBeat(<int>[
            1,
            2,
            3,
          ], staleBefore: t0.add(const Duration(days: 1))),
          containsAll(<int>[1, 2, 3]),
        );
      });

      test('falls back to rushed then completionist time', () async {
        await dao.saveTimeToBeat(
          requested: <int>[5, 6],
          found: <int, ({int? hastily, int? normally, int? completely})>{
            5: (hastily: 100, normally: null, completely: 900),
            6: (hastily: null, normally: null, completely: 900),
          },
          now: t0,
        );
        expect(await dao.getTimeToBeat(<int>[5, 6]), <int, int>{
          5: 100,
          6: 900,
        });
      });

      test('empty input does nothing', () async {
        expect(await dao.getTimeToBeat(<int>[]), isEmpty);
        expect(
          await dao.idsNeedingTimeToBeat(<int>[], staleBefore: t0),
          isEmpty,
        );
        await dao.saveTimeToBeat(
          requested: <int>[],
          found:
              const <int, ({int? hastily, int? normally, int? completely})>{},
          now: t0,
        );
      });
    });
  });
}
