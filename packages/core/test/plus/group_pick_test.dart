import 'dart:math';

import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/group_pick.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

void main() {
  CollectionItem movie(
    int rowId,
    int externalId,
    ItemStatus status, {
    int? runtime,
  }) => createTestCollectionItem(
    id: rowId,
    mediaType: MediaType.movie,
    externalId: externalId,
    status: status,
    movie: createTestMovie(tmdbId: externalId, runtime: runtime),
  );

  CollectionItem game(int rowId, int externalId) => createTestCollectionItem(
    id: rowId,
    externalId: externalId,
    status: ItemStatus.planned,
    game: createTestGame(id: externalId),
  );

  group('GroupPick.candidates', () {
    test('merges libraries and drops what anyone has already seen', () {
      final List<PickCandidate> pool = GroupPick.candidates(
        libraries: <String, List<CollectionItem>>{
          'me': <CollectionItem>[
            movie(1, 10, ItemStatus.planned, runtime: 90),
            movie(2, 20, ItemStatus.notStarted, runtime: 200),
            movie(3, 30, ItemStatus.planned),
          ],
          'ada': <CollectionItem>[
            movie(11, 10, ItemStatus.notStarted, runtime: 90),
            movie(7, 30, ItemStatus.completed),
            movie(8, 40, ItemStatus.dropped),
            movie(9, 50, ItemStatus.planned, runtime: 100),
          ],
          'guest': const <CollectionItem>[],
        },
      );
      final Map<String, PickCandidate> byKey = <String, PickCandidate>{
        for (final PickCandidate c in pool) c.key: c,
      };
      expect(byKey.keys.toSet(), <String>{
        GroupPick.keyOf(movie(0, 10, ItemStatus.planned)),
        GroupPick.keyOf(movie(0, 20, ItemStatus.planned)),
        GroupPick.keyOf(movie(0, 50, ItemStatus.planned)),
      });
      final PickCandidate? shared =
          byKey[GroupPick.keyOf(movie(0, 10, ItemStatus.planned))];
      expect(shared?.owners, <String>{'me', 'ada'});
      expect(shared?.item.id, 1, reason: 'the first library wins');
      expect(shared?.minutes, 90);
    });

    test('filters by type and by the time available', () {
      final Map<String, List<CollectionItem>> libraries =
          <String, List<CollectionItem>>{
            'me': <CollectionItem>[
              movie(1, 10, ItemStatus.planned, runtime: 90),
              movie(2, 20, ItemStatus.planned, runtime: 200),
              game(3, 99),
              game(4, 98),
            ],
          };
      expect(
        GroupPick.candidates(
          libraries: libraries,
          filters: const PickFilters(types: <MediaType>{MediaType.game}),
        ),
        hasLength(2),
      );
      final List<PickCandidate> evening = GroupPick.candidates(
        libraries: libraries,
        filters: const PickFilters(maxMinutes: 120),
        gameSecondsById: const <int, int>{99: 3600},
      );
      expect(evening.map((PickCandidate c) => c.item.id).toSet(), <int>{
        1,
        3,
        4,
      });
      final List<PickCandidate> known = GroupPick.candidates(
        libraries: libraries,
        filters: const PickFilters(
          maxMinutes: 120,
          includeUnknownLength: false,
        ),
        gameSecondsById: const <int, int>{99: 3600},
      );
      expect(known.map((PickCandidate c) => c.item.id).toSet(), <int>{1, 3});
    });
  });

  group('GroupPick.ballot', () {
    test('puts shared works first and caps the size', () {
      final List<PickCandidate> pool = <PickCandidate>[
        for (int i = 0; i < 6; i++)
          PickCandidate(
            key: 'k$i',
            item: movie(i, i, ItemStatus.planned),
            owners: i == 4 ? <String>{'a', 'b'} : <String>{'a'},
            minutes: null,
          ),
      ];
      final List<PickCandidate> ballot = GroupPick.ballot(
        pool,
        size: 3,
        random: Random(1),
      );
      expect(ballot, hasLength(3));
      expect(ballot.first.key, 'k4');
      expect(GroupPick.ballot(pool, size: 10), hasLength(6));
    });
  });

  group('GroupPick.tally', () {
    PickCandidate c(String key, int? minutes) => PickCandidate(
      key: key,
      item: movie(1, 1, ItemStatus.planned),
      owners: const <String>{'a'},
      minutes: minutes,
    );

    test('ranks by points, then yeses, noes and length', () {
      final List<PickCandidate> ballot = <PickCandidate>[
        c('a', 100),
        c('b', 90),
        c('c', null),
        c('d', 80),
        c('e', 70),
      ];
      final List<PickResult> results = GroupPick.tally(
        ballot,
        <String, Map<String, Vote>>{
          'x': <String, Vote>{
            'a': Vote.yes,
            'b': Vote.maybe,
            'c': Vote.maybe,
            'd': Vote.no,
            'e': Vote.maybe,
          },
          'y': <String, Vote>{
            'a': Vote.no,
            'b': Vote.maybe,
            'c': Vote.maybe,
            'd': Vote.yes,
          },
        },
      );
      expect(results.map((PickResult r) => r.candidate.key), <String>[
        'd',
        'a',
        'b',
        'c',
        'e',
      ]);
      expect(results.first.points, 2);
      expect(results.first.yes, 1);
      expect(results.first.no, 1);
      expect(results.first.unanimousFor(2), isFalse);
      expect(
        PickResult(
          candidate: c('z', 1),
          points: 4,
          yes: 2,
          no: 0,
        ).unanimousFor(2),
        isTrue,
      );
      expect(
        PickResult(
          candidate: c('z', 1),
          points: 0,
          yes: 0,
          no: 0,
        ).unanimousFor(0),
        isFalse,
      );
    });
  });
}
