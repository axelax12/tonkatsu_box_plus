import 'package:core/models/collection_item.dart';
import 'package:core/plus/analytics/release_reminders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/constants/platform_features.dart';
import '../insights/providers/insights_providers.dart';
import '../settings/providers/settings_provider.dart';
import 'plus_notifications.dart';

const String _signatureKey = 'plus_release_reminders_signature';
const String _idsKey = 'plus_release_reminders_ids';

/// Keeps one release-day reminder per dated work on the list, rescheduling
/// only when the plan changes; returns how many are pending.
final FutureProvider<int> releaseRemindersProvider = FutureProvider<int>((
  Ref ref,
) async {
  if (!kIsMobile) return 0;
  final List<CollectionItem> items = await ref.watch(
    libraryItemsProvider.future,
  );
  final String language = ref.watch(
    settingsNotifierProvider.select((SettingsState s) => s.appLanguage),
  );
  final List<ReleaseReminder> plan = ReleaseReminders.plan(
    items,
    DateTime.now(),
  );
  final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
  final String signature = '$language|${ReleaseReminders.signature(plan)}';
  if (prefs.getString(_signatureKey) == signature) return plan.length;

  final S l = lookupS(Locale(language));
  final List<int> previous = <int>[
    for (final String id in prefs.getStringList(_idsKey) ?? const <String>[])
      ?int.tryParse(id),
  ];
  await PlusNotifications.instance.replaceReleaseReminders(
    previousItemIds: previous,
    reminders: <({int itemId, String title, String body, DateTime day})>[
      for (final ReleaseReminder r in plan)
        (
          itemId: r.itemId,
          title: l.releaseReminderTitle(r.title),
          body: l.releaseReminderBody,
          day: r.releaseDay,
        ),
    ],
  );
  await prefs.setStringList(_idsKey, <String>[
    for (final ReleaseReminder r in plan) '${r.itemId}',
  ]);
  await prefs.setString(_signatureKey, signature);
  return plan.length;
});
