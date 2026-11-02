import 'package:core/models/media_type.dart';
import 'package:core/models/profile.dart';
import 'package:core/plus/analytics/group_pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../../insights/utils/insights_format.dart';
import '../../settings/providers/profile_provider.dart';
import '../providers/together_providers.dart';

/// Who votes, what kind of work and how long it may run.
class TogetherSetup extends ConsumerWidget {
  const TogetherSetup({super.key});

  /// From a short episode to a game for the coming weeks.
  static const List<int?> timeOptions = <int?>[
    null,
    30,
    60,
    120,
    180,
    240,
    720,
    3600,
  ];

  Future<void> _addGuest(BuildContext context, WidgetRef ref) async {
    final S l = S.of(context);
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l.togetherAddGuest),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: l.togetherGuestName),
            onSubmitted: (String v) => Navigator.of(dialogContext).pop(v),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l.add),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) ref.read(togetherProvider.notifier).addGuest(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final TogetherState state = ref.watch(togetherProvider);
    final TogetherController controller = ref.read(togetherProvider.notifier);
    final ProfilesData profiles = ref.watch(profilesDataProvider);
    final Profile me = profiles.currentProfile;
    final List<Profile> others = <Profile>[
      for (final Profile p in profiles.profiles)
        if (p.id != me.id) p,
    ];
    final AsyncValue<TogetherPool> poolAsync = ref.watch(togetherPoolProvider);
    final TogetherPool? pool = poolAsync.valueOrNull;
    final PickFilters filters = state.filters;

    String? accessNote(String id) => switch (pool?.access[id]) {
      LibraryAccess.outdated => l.togetherProfileOutdated,
      LibraryAccess.missing ||
      LibraryAccess.failed => l.togetherProfileUnavailable,
      LibraryAccess.ready || null => null,
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Text(l.togetherWho, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            FilterChip(
              label: Text(l.togetherMe(me.name)),
              selected: true,
              onSelected: null,
            ),
            for (final Profile p in others)
              FilterChip(
                key: ValueKey<String>(p.id),
                label: Text(p.name),
                avatar:
                    state.profileIds.contains(p.id) && accessNote(p.id) != null
                    ? Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppColors.warning,
                      )
                    : null,
                tooltip: accessNote(p.id),
                selected: state.profileIds.contains(p.id),
                onSelected: (_) => controller.toggleProfile(p.id),
              ),
            for (int i = 0; i < state.guests.length; i++)
              InputChip(
                key: ValueKey<String>('guest-$i'),
                avatar: const Icon(Icons.person_outline, size: 16),
                label: Text(state.guests[i]),
                onDeleted: () => controller.removeGuest(i),
              ),
            if (state.guests.length < TogetherController.maxGuests)
              ActionChip(
                avatar: const Icon(Icons.person_add_alt, size: 16),
                label: Text(l.togetherAddGuest),
                onPressed: () => _addGuest(context, ref),
              ),
          ],
        ),
        for (final String id in state.profileIds)
          if (accessNote(id) case final String note)
            Padding(
              key: ValueKey<String>('note-$id'),
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${others.where((Profile p) => p.id == id).firstOrNull?.name ?? ''}: $note',
                style: AppTypography.caption.copyWith(color: AppColors.warning),
              ),
            ),
        if (others.isEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.togetherNoProfiles,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(l.togetherWhat, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final MediaType type in MediaType.values)
              if (pool?.availableTypes.contains(type) ?? false)
                FilterChip(
                  key: ValueKey<MediaType>(type),
                  avatar: Icon(MediaTypeTheme.iconFor(type), size: 16),
                  label: Text(mediaScopeLabel(type, l)),
                  selected: filters.types.contains(type),
                  onSelected: (bool on) {
                    final Set<MediaType> types = Set<MediaType>.of(
                      filters.types,
                    );
                    if (on) {
                      types.add(type);
                    } else {
                      types.remove(type);
                    }
                    controller.setFilters(
                      PickFilters(
                        types: types,
                        maxMinutes: filters.maxMinutes,
                        includeUnknownLength: filters.includeUnknownLength,
                      ),
                    );
                  },
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.togetherTime, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final int? minutes in timeOptions)
              ChoiceChip(
                key: ValueKey<int?>(minutes),
                label: Text(
                  minutes == null
                      ? l.togetherAnyTime
                      : formatMinutes(minutes, l),
                ),
                selected: filters.maxMinutes == minutes,
                onSelected: (_) => controller.setFilters(
                  PickFilters(
                    types: filters.types,
                    maxMinutes: minutes,
                    includeUnknownLength: filters.includeUnknownLength,
                  ),
                ),
              ),
          ],
        ),
        if (filters.maxMinutes != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.togetherUnknownLength),
            value: filters.includeUnknownLength,
            onChanged: (bool v) => controller.setFilters(
              PickFilters(
                types: filters.types,
                maxMinutes: filters.maxMinutes,
                includeUnknownLength: v,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (pool == null)
          const Center(child: CircularProgressIndicator())
        else ...<Widget>[
          Text(
            l.togetherPoolCount(pool.pool.length),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: pool.pool.isEmpty
                ? null
                : () => controller.start(pool.pool),
            icon: const Icon(Icons.how_to_vote_outlined),
            label: Text(l.togetherStart),
          ),
        ],
      ],
    );
  }
}
