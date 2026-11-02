import 'package:home_widget/home_widget.dart';
import 'package:logging/logging.dart';

import '../../shared/constants/platform_features.dart';

/// Pushes the session in progress and the year's goals to the Android
/// home-screen widget. A no-op off mobile.
abstract final class PlusHomeWidget {
  static final Logger _log = Logger('PlusHomeWidget');

  // The Kotlin class keeps upstream's package, not the fork's applicationId.
  static const String _provider =
      'com.hacan359.tonkatsubox.PlusSessionWidgetProvider';

  static Future<void> update({
    required String idleLabel,
    String? title,
    DateTime? startedAt,
    String? goals,
  }) async {
    if (!kIsMobile) return;
    try {
      await HomeWidget.saveWidgetData<String>('plus_title', title);
      await HomeWidget.saveWidgetData<String>(
        'plus_started_at',
        startedAt?.millisecondsSinceEpoch.toString(),
      );
      await HomeWidget.saveWidgetData<String>('plus_goals', goals);
      await HomeWidget.saveWidgetData<String>('plus_idle', idleLabel);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } on Exception catch (e, stack) {
      _log.info('Home widget update failed', e, stack);
    }
  }
}
