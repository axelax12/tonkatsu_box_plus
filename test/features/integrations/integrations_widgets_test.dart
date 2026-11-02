import 'package:core/models/collection_item.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/tracker_achievement.dart';
import 'package:core/models/tracker_profile.dart';
import 'package:core/plus/models/price_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/integrations/providers/integrations_providers.dart';
import 'package:tonkatsu_box/features/integrations/screens/deals_screen.dart';
import 'package:tonkatsu_box/features/integrations/widgets/deal_section.dart';
import 'package:tonkatsu_box/features/integrations/widgets/steam_achievements_section.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final DateTime t0 = DateTime(2026, 4, 1);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('DealSummary', () {
    testWidgets('shows price, discount and the historic low', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        DealSummary(
          snapshot: PriceSnapshot(
            itemId: 1,
            itadId: 'x',
            price: 9.99,
            regular: 39.99,
            cut: 75,
            currency: 'EUR',
            shop: 'Steam',
            lowPrice: 7.49,
            checkedAt: t0,
          ),
          accentColor: Colors.orange,
        ),
        wrapInScaffold: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('9.99 EUR'), findsOneWidget);
      expect(find.text('-75%'), findsOneWidget);
      expect(find.text('Steam'), findsOneWidget);
    });

    testWidgets('says when no store lists the game', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        DealSummary(
          snapshot: PriceSnapshot(itemId: 1, checkedAt: t0),
          accentColor: Colors.orange,
        ),
        wrapInScaffold: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });
  });

  group('DealsScreen', () {
    testWidgets('asks to connect without a key', (WidgetTester tester) async {
      phone(tester);
      await tester.pumpApp(
        const DealsScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          itadSettingsProvider.overrideWithValue(null),
          watchedGamesProvider.overrideWith(
            (Ref ref) async => <CollectionItem>[],
          ),
          allPricesProvider.overrideWith((Ref ref) async => <PriceSnapshot>[]),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('lists watched games with their prices', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const DealsScreen(),
        wrapInScaffold: true,
        overrides: <Override>[
          itadSettingsProvider.overrideWithValue((apiKey: 'k', country: 'IT')),
          watchedGamesProvider.overrideWith(
            (Ref ref) async => <CollectionItem>[
              createTestCollectionItem(id: 1, status: ItemStatus.planned),
            ],
          ),
          allPricesProvider.overrideWith(
            (Ref ref) async => <PriceSnapshot>[
              PriceSnapshot(
                itemId: 1,
                itadId: 'x',
                price: 5,
                currency: 'EUR',
                lowPrice: 5,
                checkedAt: t0,
              ),
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DealSummary), findsOneWidget);
    });
  });

  group('SteamAchievementsSection', () {
    testWidgets('stays hidden for a game without a Steam page', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const SteamAchievementsSection(igdbId: 1, accentColor: Colors.blue),
        wrapInScaffold: true,
        overrides: <Override>[
          steamAppProvider(1).overrideWith((Ref ref) async => null),
        ],
      );
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
    });

    testWidgets('shows progress for synced achievements', (
      WidgetTester tester,
    ) async {
      phone(tester);
      await tester.pumpApp(
        const SingleChildScrollView(
          child: SteamAchievementsSection(igdbId: 1, accentColor: Colors.blue),
        ),
        wrapInScaffold: true,
        overrides: <Override>[
          steamAppProvider(1).overrideWith((Ref ref) async => '570'),
          steamCredentialsProvider.overrideWithValue((
            apiKey: 'k',
            steamId: '1',
          )),
          steamSyncProvider('570').overrideWith(
            (Ref ref) async => (earned: 1, total: 2, syncedAt: DateTime.now()),
          ),
          steamAchievementsProvider('570').overrideWith(
            (Ref ref) async => <TrackerAchievement>[
              for (int i = 0; i < 2; i++)
                TrackerAchievement(
                  id: i + 1,
                  trackerType: TrackerType.steam,
                  trackerGameId: '570',
                  achievementId: 'a$i',
                  title: 'Achievement $i',
                  displayOrder: i,
                  earned: i == 0,
                  earnedAt: i == 0 ? 1700000000 : null,
                ),
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Achievement 0'), findsOneWidget);
    });
  });
}
