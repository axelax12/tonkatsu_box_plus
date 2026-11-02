import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// A big number with its caption; tiles sit two per row on a phone.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    super.key,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconData? icon = this.icon;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null)
            Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          if (icon != null) const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h2.copyWith(color: color),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays [tiles] out two per row, stretched to equal width.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  static const int _perRow = 2;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += _perRow) {
      final List<Widget> slice = tiles.sublist(
        i,
        i + _perRow > tiles.length ? tiles.length : i + _perRow,
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int j = 0; j < _perRow; j++) ...<Widget>[
                  if (j > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: j < slice.length ? slice[j] : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
