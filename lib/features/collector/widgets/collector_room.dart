import 'dart:math' as math;

import 'package:core/models/collection_item.dart';
import 'package:core/models/media_type.dart';
import 'package:core/plus/analytics/collector_insights.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/media_type_theme.dart';
import '../../../shared/constants/media_type_ui.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/media_detail/media_cover_image.dart';
import '../../collections/screens/item_detail_screen.dart';
import '../collector_format.dart';
import '../providers/collector_providers.dart';

/// Colors of one room style. The room ignores the app palette on purpose: it
/// is a scene to look at and share, not a screen of controls.
class RoomPalette {
  const RoomPalette({
    required this.wallTop,
    required this.wallBottom,
    required this.plankTop,
    required this.plankBottom,
    required this.label,
    required this.medal,
    required this.medalLocked,
    this.glow,
  });

  final Color wallTop;
  final Color wallBottom;
  final Color plankTop;
  final Color plankBottom;
  final Color label;
  final Color medal;
  final Color medalLocked;
  final Color? glow;

  static RoomPalette of(RoomTheme theme) {
    switch (theme) {
      case RoomTheme.wood:
        return const RoomPalette(
          wallTop: Color(0xFF3B2A20),
          wallBottom: Color(0xFF1E1511),
          plankTop: Color(0xFF9C6B3F),
          plankBottom: Color(0xFF5E3B1F),
          label: Color(0xFFF3E2C7),
          medal: Color(0xFFE8B94A),
          medalLocked: Color(0xFF6B5A4C),
        );
      case RoomTheme.midnight:
        return const RoomPalette(
          wallTop: Color(0xFF16213E),
          wallBottom: Color(0xFF0B1020),
          plankTop: Color(0xFF8E9AAF),
          plankBottom: Color(0xFF4A5468),
          label: Color(0xFFDCE3F0),
          medal: Color(0xFFC0D6F5),
          medalLocked: Color(0xFF39445C),
        );
      case RoomTheme.neon:
        return const RoomPalette(
          wallTop: Color(0xFF1A0B2E),
          wallBottom: Color(0xFF07030F),
          plankTop: Color(0xFFFF3EA5),
          plankBottom: Color(0xFF7A1E5E),
          label: Color(0xFF7DF9FF),
          medal: Color(0xFF7DF9FF),
          medalLocked: Color(0xFF3A2650),
          glow: Color(0xFFFF3EA5),
        );
    }
  }
}

class CollectorRoom extends StatelessWidget {
  const CollectorRoom({
    required this.items,
    required this.keepsakes,
    required this.theme,
    super.key,
  });

  final List<CollectionItem> items;
  final List<KeepsakeProgress> keepsakes;
  final RoomTheme theme;

  static const double coverWidth = 60;
  static const double _coverAspect = 1.5;
  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final RoomPalette palette = RoomPalette.of(theme);
    final Map<MediaType, List<CollectionItem>> byType =
        <MediaType, List<CollectionItem>>{};
    for (final CollectionItem item in items) {
      byType.putIfAbsent(item.mediaType, () => <CollectionItem>[]).add(item);
    }
    final List<MapEntry<MediaType, List<CollectionItem>>> groups =
        byType.entries.toList()..sort(
          (
            MapEntry<MediaType, List<CollectionItem>> a,
            MapEntry<MediaType, List<CollectionItem>> b,
          ) => b.value.length.compareTo(a.value.length),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.wallTop, palette.wallBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Plaque(text: l.roomKeepsakes, palette: palette),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final KeepsakeProgress k in keepsakes)
                _Medal(
                  key: ValueKey<Keepsake>(k.keepsake),
                  progress: k,
                  palette: palette,
                ),
            ],
          ),
          _Plank(palette: palette),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                l.roomEmpty,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: palette.label),
              ),
            ),
          for (final MapEntry<MediaType, List<CollectionItem>> group in groups)
            Padding(
              key: ValueKey<MediaType>(group.key),
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Plaque(
                    text:
                        '${group.key.localizedPluralLabel(l)} · '
                        '${group.value.length}',
                    icon: MediaTypeTheme.iconFor(group.key),
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int perShelf = math.max(
                        1,
                        ((c.maxWidth + _gap) / (coverWidth + _gap)).floor(),
                      );
                      final List<Widget> shelves = <Widget>[];
                      for (int i = 0; i < group.value.length; i += perShelf) {
                        final List<CollectionItem> row = group.value.sublist(
                          i,
                          i + perShelf > group.value.length
                              ? group.value.length
                              : i + perShelf,
                        );
                        shelves.add(
                          Column(
                            key: ValueKey<int>(i),
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  for (final CollectionItem item in row)
                                    Padding(
                                      key: ValueKey<int>(item.id),
                                      padding: const EdgeInsets.only(
                                        right: _gap,
                                      ),
                                      child: _ShelfCover(
                                        item: item,
                                        width: coverWidth,
                                        height: coverWidth * _coverAspect,
                                        palette: palette,
                                      ),
                                    ),
                                ],
                              ),
                              _Plank(palette: palette),
                            ],
                          ),
                        );
                      }
                      return Column(children: shelves);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Plaque extends StatelessWidget {
  const _Plaque({required this.text, required this.palette, this.icon});

  final String text;
  final RoomPalette palette;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData? icon = this.icon;
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 16, color: palette.label),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: palette.label,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              shadows: palette.glow == null
                  ? null
                  : <Shadow>[
                      Shadow(
                        color: palette.glow ?? Colors.transparent,
                        blurRadius: 8,
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Plank extends StatelessWidget {
  const _Plank({required this.palette});

  final RoomPalette palette;

  static const double _height = 10;

  @override
  Widget build(BuildContext context) {
    final Color? glow = palette.glow;
    return Container(
      height: _height,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxs),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.plankTop, palette.plankBottom],
        ),
        boxShadow: <BoxShadow>[
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 8,
            offset: Offset(0, 6),
          ),
          if (glow != null)
            BoxShadow(color: glow.withValues(alpha: 0.6), blurRadius: 12),
        ],
      ),
    );
  }
}

class _ShelfCover extends StatelessWidget {
  const _ShelfCover({
    required this.item,
    required this.width,
    required this.height,
    required this.palette,
  });

  final CollectionItem item;
  final double width;
  final double height;
  final RoomPalette palette;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.itemName,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => ItemDetailScreen(
              collectionId: item.collectionId,
              itemId: item.id,
              isEditable: true,
            ),
          ),
        ),
        child: Container(
          width: width,
          height: height,
          decoration: const BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 4,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxs),
            child: MediaCoverImage(
              coverUrl: item.thumbnailUrl ?? item.coverUrl,
              placeholderIcon: MediaTypeTheme.placeholderIconFor(
                item.mediaType,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.progress, required this.palette, super.key});

  final KeepsakeProgress progress;
  final RoomPalette palette;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool unlocked = progress.unlocked;
    final Color color = unlocked ? palette.medal : palette.medalLocked;
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message:
          '${keepsakeTitle(progress.keepsake, l)}\n'
          '${keepsakeHint(progress.keepsake, l)}\n'
          '${l.keepsakeProgress(progress.value, progress.keepsake.target)}',
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (!unlocked)
              SizedBox(
                width: _size,
                height: _size,
                child: CircularProgressIndicator(
                  value: progress.fraction,
                  strokeWidth: 3,
                  color: palette.medal.withValues(alpha: 0.6),
                  backgroundColor: palette.medalLocked,
                ),
              ),
            Container(
              width: _size - 8,
              height: _size - 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: unlocked ? 0.25 : 0.15),
                border: Border.all(color: color, width: unlocked ? 2 : 1),
                boxShadow: unlocked && palette.glow != null
                    ? <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.7),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                keepsakeIcon(progress.keepsake),
                size: 20,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
