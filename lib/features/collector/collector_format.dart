import 'package:core/plus/analytics/collector_insights.dart';
import 'package:core/plus/models/owned_copy.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

String copyConditionLabel(CopyCondition condition, S l) {
  switch (condition) {
    case CopyCondition.sealed:
      return l.conditionSealed;
    case CopyCondition.mint:
      return l.conditionMint;
    case CopyCondition.good:
      return l.conditionGood;
    case CopyCondition.fair:
      return l.conditionFair;
    case CopyCondition.poor:
      return l.conditionPoor;
  }
}

String copyFormatLabel(CopyFormat format, S l) =>
    format == CopyFormat.physical ? l.copyPhysical : l.copyDigital;

IconData copyFormatIcon(CopyFormat format) => format == CopyFormat.physical
    ? Icons.album_outlined
    : Icons.cloud_download_outlined;

/// "59.90 EUR"; a price without a currency shows the bare number.
String formatPrice(double price, String? currency) {
  final String amount = price.toStringAsFixed(2);
  final String code = currency?.trim() ?? '';
  return code.isEmpty ? amount : '$amount $code';
}

String keepsakeTitle(Keepsake k, S l) {
  switch (k) {
    case Keepsake.firstFinish:
      return l.keepsakeFirstFinish;
    case Keepsake.tenFinished:
      return l.keepsakeTenFinished;
    case Keepsake.fiftyFinished:
      return l.keepsakeFiftyFinished;
    case Keepsake.hundredFinished:
      return l.keepsakeHundredFinished;
    case Keepsake.polymath:
      return l.keepsakePolymath;
    case Keepsake.marathon:
      return l.keepsakeMarathon;
    case Keepsake.hundredHours:
      return l.keepsakeHundredHours;
    case Keepsake.weekStreak:
      return l.keepsakeWeekStreak;
    case Keepsake.journalist:
      return l.keepsakeJournalist;
    case Keepsake.shelfBuilder:
      return l.keepsakeShelfBuilder;
    case Keepsake.backlogBuster:
      return l.keepsakeBacklogBuster;
    case Keepsake.critic:
      return l.keepsakeCritic;
  }
}

String keepsakeHint(Keepsake k, S l) {
  switch (k) {
    case Keepsake.firstFinish:
      return l.keepsakeFirstFinishHint;
    case Keepsake.tenFinished:
      return l.keepsakeTenFinishedHint;
    case Keepsake.fiftyFinished:
      return l.keepsakeFiftyFinishedHint;
    case Keepsake.hundredFinished:
      return l.keepsakeHundredFinishedHint;
    case Keepsake.polymath:
      return l.keepsakePolymathHint;
    case Keepsake.marathon:
      return l.keepsakeMarathonHint;
    case Keepsake.hundredHours:
      return l.keepsakeHundredHoursHint;
    case Keepsake.weekStreak:
      return l.keepsakeWeekStreakHint;
    case Keepsake.journalist:
      return l.keepsakeJournalistHint;
    case Keepsake.shelfBuilder:
      return l.keepsakeShelfBuilderHint;
    case Keepsake.backlogBuster:
      return l.keepsakeBacklogBusterHint;
    case Keepsake.critic:
      return l.keepsakeCriticHint;
  }
}

IconData keepsakeIcon(Keepsake k) {
  switch (k) {
    case Keepsake.firstFinish:
      return Icons.flag;
    case Keepsake.tenFinished:
      return Icons.looks_one;
    case Keepsake.fiftyFinished:
      return Icons.military_tech;
    case Keepsake.hundredFinished:
      return Icons.workspace_premium;
    case Keepsake.polymath:
      return Icons.diversity_3;
    case Keepsake.marathon:
      return Icons.directions_run;
    case Keepsake.hundredHours:
      return Icons.hourglass_full;
    case Keepsake.weekStreak:
      return Icons.local_fire_department;
    case Keepsake.journalist:
      return Icons.history_edu;
    case Keepsake.shelfBuilder:
      return Icons.shelves;
    case Keepsake.backlogBuster:
      return Icons.inventory;
    case Keepsake.critic:
      return Icons.rate_review;
  }
}
