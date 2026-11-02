import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/igdb/igdb_types.dart';
import 'package:tonkatsu_box/features/paths/providers/paths_providers.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SeriesTokenCache', () {
    late MockIgdbApi api;

    setUpAll(() => registerFallbackValue(<int>[]));
    setUp(() => api = MockIgdbApi());

    test('asks IGDB only for games it has not seen', () async {
      when(() => api.seriesTokensFor(any())).thenAnswer(
        (Invocation inv) async => <int, Set<String>>{
          for (final int id in inv.positionalArguments.first as List<int>)
            if (id == 1) id: <String>{'f:7'},
        },
      );
      final SeriesTokenCache cache = SeriesTokenCache();
      final Map<int, Set<String>> first = await cache.tokensFor(api, <int>[1, 2]);
      expect(first[1], <String>{'f:7'});
      expect(first[2], isEmpty, reason: 'a miss is remembered too');
      await cache.tokensFor(api, <int>[1, 2, 3]);
      final List<dynamic> calls = verify(
        () => api.seriesTokensFor(captureAny()),
      ).captured;
      expect(calls.last, <int>[3]);
    });

    test('a failed lookup is retried next time', () async {
      when(
        () => api.seriesTokensFor(any()),
      ).thenThrow(const IgdbApiException('API credentials not set'));
      final SeriesTokenCache cache = SeriesTokenCache();
      expect(await cache.tokensFor(api, <int>[5]), isEmpty);
      await cache.tokensFor(api, <int>[5]);
      verify(() => api.seriesTokensFor(<int>[5])).called(2);
    });
  });
}
