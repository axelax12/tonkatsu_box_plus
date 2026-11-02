import 'package:core/models/item_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonkatsu_box/features/quick_add/quick_status.dart';
import 'package:tonkatsu_box/features/settings/providers/settings_provider.dart';

void main() {
  Future<ProviderContainer> container(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('NewItemStatusNotifier', () {
    test('defaults to not started and ignores unknown values', () async {
      expect(
        (await container(<String, Object>{})).read(newItemStatusProvider),
        ItemStatus.notStarted,
      );
      expect(
        (await container(<String, Object>{
          NewItemStatusNotifier.prefsKey: 'dropped',
        })).read(newItemStatusProvider),
        ItemStatus.notStarted,
        reason: 'only the quick statuses can be a default',
      );
    });

    test('persists the chosen default', () async {
      final ProviderContainer c = await container(<String, Object>{});
      await c.read(newItemStatusProvider.notifier).select(ItemStatus.planned);
      expect(c.read(newItemStatusProvider), ItemStatus.planned);
      final SharedPreferences prefs = c.read(sharedPreferencesProvider);
      expect(
        prefs.getString(NewItemStatusNotifier.prefsKey),
        ItemStatus.planned.value,
      );
    });
  });
}
