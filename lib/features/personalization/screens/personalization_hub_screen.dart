import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../insights/screens/backlog_health_screen.dart';
import '../../insights/screens/goals_screen.dart';
import '../../insights/screens/year_review_screen.dart';
import '../../insights/widgets/hub_insights_previews.dart';
import '../../likes/screens/likes_screen.dart';
import '../../smart_lists/screens/smart_lists_screen.dart';
import '../../smart_lists/widgets/hub_smart_lists_preview.dart';
import '../../recommendations/screens/recommendations_screen.dart';
import '../../showcase/screens/showcase_screen.dart';
import '../../statistics/screens/statistics_screen.dart';
import '../widgets/hub_likes_preview.dart';
import '../widgets/hub_recommendations_preview.dart';
import '../widgets/hub_section_card.dart';
import '../widgets/hub_showcase_preview.dart';
import '../widgets/hub_stats_preview.dart';
import '../widgets/personalization_sub_screen.dart';

/// Landing page of the hub: one card per section with a live preview.
class PersonalizationHubScreen extends StatelessWidget {
  const PersonalizationHubScreen({super.key});

  static const double _wideBreakpoint = 800;
  static const double _maxContentWidth = 920;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return Material(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? _maxContentWidth : double.infinity,
          ),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? AppSpacing.lg : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.md,
                ),
                child: Text(l.personalizationTitle, style: AppTypography.h2),
              ),
              HubSectionCard(
                icon: Icons.insights_outlined,
                title: l.statsTabTitle,
                hint: l.personalizationStatsHint,
                preview: const HubStatsPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.statsTabTitle,
                  child: const StatisticsScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.auto_awesome_outlined,
                title: l.recommendationsTitle,
                hint: l.personalizationRecommendationsHint,
                preview: const HubRecommendationsPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.recommendationsTitle,
                  child: const RecommendationsScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.storefront_outlined,
                title: l.showcaseTitle,
                hint: l.showcaseHint,
                preview: const HubShowcasePreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.showcaseTitle,
                  child: const ShowcaseScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.favorite_border,
                title: l.likesTitle,
                hint: l.personalizationLikesHint,
                preview: const HubLikesPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.likesTitle,
                  child: const LikesScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.track_changes_outlined,
                title: l.insightsGoalsTitle,
                hint: l.insightsGoalsHint,
                preview: const HubGoalsPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.insightsGoalsTitle,
                  child: const GoalsScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.inventory_2_outlined,
                title: l.insightsBacklogTitle,
                hint: l.insightsBacklogHint,
                preview: const HubBacklogPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.insightsBacklogTitle,
                  child: const BacklogHealthScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.auto_graph_outlined,
                title: l.insightsYearTitle,
                hint: l.insightsYearHint,
                preview: const HubYearPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.insightsYearTitle,
                  child: const YearReviewScreen(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              HubSectionCard(
                icon: Icons.filter_list_alt,
                title: l.smartListsTitle,
                hint: l.smartListsHint,
                preview: const HubSmartListsPreview(),
                onTap: () => pushPersonalizationSection(
                  context,
                  title: l.smartListsTitle,
                  child: const SmartListsScreen(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
