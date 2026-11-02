import 'package:core/plus/models/resume_bookmark.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// "Where was I?" at a glance; the whole card opens the editor.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    required this.bookmark,
    required this.accentColor,
    this.onTap,
    super.key,
  });

  final ResumeBookmark? bookmark;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final ResumeBookmark? b = bookmark;
    final List<(IconData, String, String)> rows = <(IconData, String, String)>[
      if (b?.position != null)
        (Icons.place_outlined, l.journalResumePosition, b?.position ?? ''),
      if (b?.objective != null)
        (Icons.flag_outlined, l.journalResumeObjective, b?.objective ?? ''),
      if (b?.reminders != null)
        (
          Icons.sports_esports_outlined,
          l.journalResumeReminders,
          b?.reminders ?? '',
        ),
      if (b?.characters != null)
        (Icons.people_outline, l.journalResumeCharacters, b?.characters ?? ''),
      if (b?.notes != null) (Icons.notes, l.journalResumeNotes, b?.notes ?? ''),
    ];

    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.bookmark_outline, size: 18, color: accentColor),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.journalResumeTitle,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (rows.isEmpty)
                Text(
                  l.journalResumeEmpty,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                )
              else
                for (final (IconData icon, String label, String value) in rows)
                  Padding(
                    key: ValueKey<String>(label),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(icon, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                label,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textTertiary),
                              ),
                              Text(value, style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              if (b != null && rows.isNotEmpty)
                Text(
                  l.journalResumeUpdated(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(b.updatedAt),
                  ),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
