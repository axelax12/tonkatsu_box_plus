import '../../models/collection_item.dart';
import '../../models/media_type.dart';
import '../models/owned_copy.dart';
import '../models/play_session.dart';
import 'time_estimator.dart';
import 'year_review.dart';

enum Keepsake {
  firstFinish(1),
  tenFinished(10),
  fiftyFinished(50),
  hundredFinished(100),
  polymath(4),
  marathon(1),
  hundredHours(100),
  weekStreak(7),
  journalist(25),
  shelfBuilder(25),
  backlogBuster(10),
  critic(50);

  const Keepsake(this.target);

  /// The count at which the keepsake unlocks.
  final int target;
}

class KeepsakeProgress {
  const KeepsakeProgress(this.keepsake, this.value);

  final Keepsake keepsake;
  final int value;

  bool get unlocked => value >= keepsake.target;

  double get fraction {
    final double f = value / keepsake.target;
    return f > 1 ? 1 : f;
  }
}

/// Small trophies for the collector's room, earned by finishing things rather
/// than by buying them: only one of them counts copies at all.
abstract final class Keepsakes {
  static const int marathonSeconds = 4 * 3600;
  static const int _secondsPerHour = 3600;
  static const int _backlogWaitDays = 365;

  static List<KeepsakeProgress> compute({
    required List<CollectionItem> items,
    required List<PlaySession> sessions,
    required int journalEntryCount,
    required List<OwnedCopy> copies,
  }) {
    final List<CollectionItem> finished = items
        .where(
          (CollectionItem i) =>
              isFinishedStatus(i.status) && i.completedAt != null,
        )
        .toList();
    final Set<MediaType> finishedTypes = <MediaType>{
      for (final CollectionItem i in finished) i.mediaType,
    };
    final List<PlaySession> done = sessions
        .where((PlaySession s) => !s.isRunning)
        .toList();
    final int totalSeconds = done.fold<int>(
      0,
      (int sum, PlaySession s) => sum + s.durationSeconds,
    );
    final bool hadMarathon = done.any(
      (PlaySession s) => s.durationSeconds >= marathonSeconds,
    );
    final int streak = YearReview.longestStreak(<DateTime>{
      for (final PlaySession s in done)
        DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
    });
    final int physical = copies
        .where((OwnedCopy c) => c.format == CopyFormat.physical)
        .length;
    final int busted = finished.where((CollectionItem i) {
      final DateTime? completed = i.completedAt;
      return completed != null &&
          completed.difference(i.addedAt).inDays >= _backlogWaitDays;
    }).length;
    final int rated = items
        .where((CollectionItem i) => i.userRating != null)
        .length;

    int valueFor(Keepsake k) {
      switch (k) {
        case Keepsake.firstFinish:
        case Keepsake.tenFinished:
        case Keepsake.fiftyFinished:
        case Keepsake.hundredFinished:
          return finished.length;
        case Keepsake.polymath:
          return finishedTypes.length;
        case Keepsake.marathon:
          return hadMarathon ? 1 : 0;
        case Keepsake.hundredHours:
          return totalSeconds ~/ _secondsPerHour;
        case Keepsake.weekStreak:
          return streak;
        case Keepsake.journalist:
          return journalEntryCount;
        case Keepsake.shelfBuilder:
          return physical;
        case Keepsake.backlogBuster:
          return busted;
        case Keepsake.critic:
          return rated;
      }
    }

    return <KeepsakeProgress>[
      for (final Keepsake k in Keepsake.values)
        KeepsakeProgress(k, valueFor(k)),
    ];
  }
}

/// What the shelves hold and what they cost, with totals kept per currency
/// because nobody wants yen silently added to euros.
class CollectionValue {
  const CollectionValue({
    required this.physicalCount,
    required this.digitalCount,
    required this.spentByCurrency,
    required this.activeLoans,
    required this.overdueLoans,
  });

  factory CollectionValue.compute(List<OwnedCopy> copies, DateTime now) {
    final Map<String, double> spent = <String, double>{};
    for (final OwnedCopy c in copies) {
      final double? price = c.pricePaid;
      if (price == null || price <= 0) continue;
      final String currency = (c.currency?.trim().isNotEmpty ?? false)
          ? (c.currency ?? '').trim().toUpperCase()
          : unknownCurrency;
      spent[currency] = (spent[currency] ?? 0) + price;
    }
    return CollectionValue(
      physicalCount: copies
          .where((OwnedCopy c) => c.format == CopyFormat.physical)
          .length,
      digitalCount: copies
          .where((OwnedCopy c) => c.format == CopyFormat.digital)
          .length,
      spentByCurrency: spent,
      activeLoans: copies.where((OwnedCopy c) => c.isLoaned).length,
      overdueLoans: copies.where((OwnedCopy c) => c.isOverdue(now)).length,
    );
  }

  static const String unknownCurrency = '';

  final int physicalCount;
  final int digitalCount;
  final Map<String, double> spentByCurrency;
  final int activeLoans;
  final int overdueLoans;
}
