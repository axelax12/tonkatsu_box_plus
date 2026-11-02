import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../shared/constants/platform_features.dart';

/// Local notifications for the fork: the running-session timer, loan
/// reminders and price drops. A no-op off mobile, so callers never branch.
class PlusNotifications {
  PlusNotifications._();

  static final PlusNotifications instance = PlusNotifications._();

  static final Logger _log = Logger('PlusNotifications');

  // Id ranges keep each kind addressable by its own row id.
  static const int _sessionBase = 1000000;
  static const int _loanBase = 2000000;
  static const int _dealBase = 3000000;
  static const int _releaseBase = 4000000;

  static const String _sessionChannel = 'plus_sessions';
  static const String _reminderChannel = 'plus_reminders';
  static const String _dealChannel = 'plus_deals';
  static const String _releaseChannel = 'plus_releases';

  /// Morning hour a loan reminder fires on its due day.
  static const int _reminderHour = 10;

  /// Release-day reminders fire a little earlier, before the day is planned.
  static const int _releaseHour = 9;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  Future<bool> _ensureReady() {
    return _ready ??= _init();
  }

  Future<bool> _init() async {
    if (!kIsMobile) return false;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      return true;
    } on Exception catch (e, stack) {
      _log.warning('Notifications unavailable', e, stack);
      return false;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks once on Android 13+; earlier versions grant it at install.
  Future<bool> requestPermission() async {
    if (!await _ensureReady()) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } on Exception catch (e, stack) {
      _log.info('Notification permission request failed', e, stack);
      return false;
    }
  }

  Future<void> showRunningSession({
    required int itemId,
    required String title,
    required String body,
    required DateTime startedAt,
  }) async {
    if (!await _ensureReady()) return;
    await requestPermission();
    await _run('running session', () async {
      await _plugin.show(
        id: _sessionBase + itemId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _sessionChannel,
            'Sessions',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: true,
            usesChronometer: true,
            when: startedAt.millisecondsSinceEpoch,
          ),
        ),
      );
    });
  }

  Future<void> cancelRunningSession(int itemId) async {
    if (!await _ensureReady()) return;
    await _run(
      'cancel session',
      () => _plugin.cancel(id: _sessionBase + itemId),
    );
  }

  Future<void> scheduleLoanReminder({
    required int copyId,
    required String title,
    required String body,
    required DateTime dueAt,
  }) async {
    if (!await _ensureReady()) return;
    final DateTime fireAt = DateTime(
      dueAt.year,
      dueAt.month,
      dueAt.day,
      _reminderHour,
    );
    if (fireAt.isBefore(DateTime.now())) return;
    await requestPermission();
    await _run('schedule loan reminder', () async {
      await _plugin.zonedSchedule(
        id: _loanBase + copyId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(_reminderChannel, 'Reminders'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });
  }

  Future<void> cancelLoanReminder(int copyId) async {
    if (!await _ensureReady()) return;
    await _run(
      'cancel loan reminder',
      () => _plugin.cancel(id: _loanBase + copyId),
    );
  }

  Future<void> showDeal({
    required int itemId,
    required String title,
    required String body,
  }) async {
    if (!await _ensureReady()) return;
    await _run('deal', () async {
      await _plugin.show(
        id: _dealBase + itemId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _dealChannel,
            'Deals',
            importance: Importance.defaultImportance,
          ),
        ),
      );
    });
  }

  /// Replaces every pending release reminder with [reminders]; ids are the
  /// item rows, so [previousItemIds] is enough to clear the old set.
  Future<void> replaceReleaseReminders({
    required Iterable<int> previousItemIds,
    required List<({int itemId, String title, String body, DateTime day})>
    reminders,
  }) async {
    if (!await _ensureReady()) return;
    for (final int id in previousItemIds) {
      await _run('cancel release', () => _plugin.cancel(id: _releaseBase + id));
    }
    if (reminders.isEmpty) return;
    await requestPermission();
    for (final ({int itemId, String title, String body, DateTime day}) r
        in reminders) {
      final DateTime fireAt = DateTime(
        r.day.year,
        r.day.month,
        r.day.day,
        _releaseHour,
      );
      if (fireAt.isBefore(DateTime.now())) continue;
      await _run('schedule release', () async {
        await _plugin.zonedSchedule(
          id: _releaseBase + r.itemId,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(_releaseChannel, 'Releases'),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      });
    }
  }

  // A notification is never worth crashing a save for.
  Future<void> _run(String what, Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (e, stack) {
      _log.warning('Notification failed: $what', e, stack);
    }
  }
}
