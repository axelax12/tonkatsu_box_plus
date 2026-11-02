import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/models/smart_list.dart';

import '../../l10n/app_localizations.dart';

class SmartListTemplate {
  const SmartListTemplate({required this.name, required this.rules});

  final String name;
  final SmartListRules rules;
}

const Set<ItemStatus> _waiting = <ItemStatus>{
  ItemStatus.notStarted,
  ItemStatus.planned,
};

const int _minutesPerHour = 60;
const int _shortGameHours = 10;
const int _movieNightHours = 2;
const int _almostDoneUnits = 5;
const int _forgottenDays = 365;
const double _greatRating = 8;

/// Ready-made lists offered on the smart lists screen; one tap saves a copy
/// the user can then edit.
List<SmartListTemplate> smartListTemplates(S l) => <SmartListTemplate>[
  SmartListTemplate(
    name: l.smartTemplateShortGames,
    rules: const SmartListRules(
      mediaTypes: <MediaType>{MediaType.game},
      statuses: _waiting,
      maxMinutes: _shortGameHours * _minutesPerHour,
      sort: SmartListSort.shortestFirst,
    ),
  ),
  SmartListTemplate(
    name: l.smartTemplateAlmostDone,
    rules: const SmartListRules(
      statuses: <ItemStatus>{ItemStatus.inProgress, ItemStatus.dropped},
      maxUnitsLeft: _almostDoneUnits,
      sort: SmartListSort.addedOldest,
    ),
  ),
  SmartListTemplate(
    name: l.smartTemplateForgotten,
    rules: const SmartListRules(
      statuses: _waiting,
      minAgeDays: _forgottenDays,
      sort: SmartListSort.addedOldest,
    ),
  ),
  SmartListTemplate(
    name: l.smartTemplateMovieNight,
    rules: const SmartListRules(
      mediaTypes: <MediaType>{MediaType.movie, MediaType.animation},
      statuses: _waiting,
      maxMinutes: _movieNightHours * _minutesPerHour,
      sort: SmartListSort.shortestFirst,
    ),
  ),
  SmartListTemplate(
    name: l.smartTemplateFavoritesToStart,
    rules: const SmartListRules(favoritesOnly: true, neverStarted: true),
  ),
  SmartListTemplate(
    name: l.smartTemplateBestRated,
    rules: const SmartListRules(
      minRating: _greatRating,
      sort: SmartListSort.ratingHighest,
    ),
  ),
];
