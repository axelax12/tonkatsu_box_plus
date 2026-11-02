import 'dart:convert';

import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/path_exchange.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:core/testing/builders.dart';
import 'package:test/test.dart';

void main() {
  final DateTime t0 = DateTime(2026, 10, 1);

  CollectionItem game(int rowId, int igdbId, String name) =>
      createTestCollectionItem(
        id: rowId,
        externalId: igdbId,
        game: createTestGame(id: igdbId, name: name),
      );

  final MediaPath path = MediaPath(
    id: 3,
    name: 'Zelda',
    kind: PathKind.universe,
    description: 'Hyrule',
    defaultOrder: PathOrder.chronological,
    createdAt: t0,
    updatedAt: t0,
  );

  group('PathExchange', () {
    test('round-trips a path and matches it against another library', () {
      final List<PathEntry> entries = <PathEntry>[
        const PathEntry(
          id: 1,
          pathId: 3,
          itemId: 10,
          releasePos: 0,
          chronoPos: 1,
          recommendedPos: 0,
          note: 'start here',
        ),
        const PathEntry(
          id: 2,
          pathId: 3,
          itemId: 11,
          releasePos: 1,
          chronoPos: 0,
          recommendedPos: 1,
          optional: true,
          spoiler: true,
          aspect: PathAspect.setting,
        ),
        const PathEntry(
          id: 3,
          pathId: 3,
          itemId: 99,
          releasePos: 2,
          chronoPos: 2,
          recommendedPos: 2,
        ),
      ];
      final String text = PathExchange.encode(
        path,
        entries,
        <int, CollectionItem>{
          10: game(10, 500, 'Ocarina'),
          11: game(11, 501, 'Skyward'),
        },
      );
      final SharedPath shared = PathExchange.decode(text);
      expect(shared.name, 'Zelda');
      expect(shared.description, 'Hyrule');
      expect(shared.defaultOrder, PathOrder.chronological);
      expect(shared.stops, hasLength(2), reason: 'unknown rows are dropped');
      expect(shared.stops.last.optional, isTrue);
      expect(shared.stops.last.spoiler, isTrue);
      expect(shared.stops.last.aspect, PathAspect.setting);
      expect(shared.stops.first.note, 'start here');

      final PathMatch match = PathExchange.match(shared, <CollectionItem>[
        game(70, 501, 'Skyward'),
        game(71, 501, 'Skyward (2nd copy)'),
        createTestCollectionItem(
          id: 72,
          externalId: 500,
          mediaType: MediaType.movie,
          movie: createTestMovie(tmdbId: 500),
        ),
      ]);
      expect(match.found.single.item.id, 70);
      expect(match.missing.single.title, 'Ocarina');
    });

    test('rejects text that is not a shared path', () {
      expect(
        () => PathExchange.decode('hello'),
        throwsA(isA<PathExchangeException>()),
      );
      expect(
        () => PathExchange.decode(jsonEncode(<String, Object>{'format': 'x'})),
        throwsA(isA<PathExchangeException>()),
      );
      expect(
        () => PathExchange.decode(
          jsonEncode(<String, Object>{
            'format': PathExchange.format,
            'version': PathExchange.version + 1,
            'name': 'n',
          }),
        ),
        throwsA(isA<PathExchangeException>()),
      );
      expect(
        () => PathExchange.decode(
          jsonEncode(<String, Object>{
            'format': PathExchange.format,
            'name': ' ',
          }),
        ),
        throwsA(isA<PathExchangeException>()),
      );
      final SharedPath lenient = PathExchange.decode(
        jsonEncode(<String, Object>{
          'format': PathExchange.format,
          'name': 'Mixed',
          'stops': <Object>[
            'junk',
            <String, Object>{'type': 'nope', 'id': 1},
            <String, Object>{'type': 'movie', 'id': 2},
          ],
        }),
      );
      expect(lenient.stops.single.mediaType, MediaType.movie);
      expect(lenient.kind, PathKind.universe);
      expect(const PathExchangeException('x').toString(), contains('x'));
    });
  });
}
