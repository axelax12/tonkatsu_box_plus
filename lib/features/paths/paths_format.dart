import 'package:core/plus/analytics/theme_index.dart';
import 'package:core/plus/models/media_path.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

String pathKindLabel(PathKind kind, S l) => switch (kind) {
  PathKind.universe => l.pathKindUniverse,
  PathKind.theme => l.pathKindTheme,
};

IconData pathKindIcon(PathKind kind) => switch (kind) {
  PathKind.universe => Icons.public,
  PathKind.theme => Icons.route_outlined,
};

String pathOrderLabel(PathOrder order, S l) => switch (order) {
  PathOrder.release => l.pathOrderRelease,
  PathOrder.chronological => l.pathOrderChrono,
  PathOrder.recommended => l.pathOrderRecommended,
};

String aspectLabel(PathAspect aspect, S l) => switch (aspect) {
  PathAspect.atmosphere => l.aspectAtmosphere,
  PathAspect.setting => l.aspectSetting,
  PathAspect.themes => l.aspectThemes,
  PathAspect.structure => l.aspectStructure,
};

IconData aspectIcon(PathAspect aspect) => switch (aspect) {
  PathAspect.atmosphere => Icons.cloud_outlined,
  PathAspect.setting => Icons.landscape_outlined,
  PathAspect.themes => Icons.lightbulb_outline,
  PathAspect.structure => Icons.account_tree_outlined,
};

String builtInThemeLabel(BuiltInTheme theme, S l) => switch (theme) {
  BuiltInTheme.dark => l.themeDark,
  BuiltInTheme.tense => l.themeTense,
  BuiltInTheme.lighthearted => l.themeLighthearted,
  BuiltInTheme.cozy => l.themeCozy,
  BuiltInTheme.emotional => l.themeEmotional,
  BuiltInTheme.surreal => l.themeSurreal,
  BuiltInTheme.space => l.themeSpace,
  BuiltInTheme.fantasyWorlds => l.themeFantasyWorlds,
  BuiltInTheme.historical => l.themeHistorical,
  BuiltInTheme.dystopia => l.themeDystopia,
  BuiltInTheme.school => l.themeSchool,
  BuiltInTheme.supernatural => l.themeSupernatural,
  BuiltInTheme.love => l.themeLove,
  BuiltInTheme.war => l.themeWar,
  BuiltInTheme.mind => l.themeMind,
  BuiltInTheme.crime => l.themeCrime,
  BuiltInTheme.comingOfAge => l.themeComingOfAge,
  BuiltInTheme.machines => l.themeMachines,
  BuiltInTheme.competition => l.themeCompetition,
  BuiltInTheme.mystery => l.themeMystery,
  BuiltInTheme.journey => l.themeJourney,
  BuiltInTheme.action => l.themeAction,
  BuiltInTheme.strategy => l.themeStrategy,
  BuiltInTheme.rolePlaying => l.themeRolePlaying,
  BuiltInTheme.trueStories => l.themeTrueStories,
};

String themeKeyLabel(ThemeKey key, S l) {
  final BuiltInTheme? builtIn = key.builtIn;
  return builtIn != null ? builtInThemeLabel(builtIn, l) : key.label ?? '';
}
