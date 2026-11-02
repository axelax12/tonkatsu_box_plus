import 'package:core/plus/models/journal_entry.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../utils/journal_format.dart';

/// One diary entry. Spoilers stay blurred behind a tap, every time the tile is
/// built, so scrolling past an old entry never ruins anything by accident.
class JournalEntryTile extends StatefulWidget {
  const JournalEntryTile({
    required this.entry,
    required this.accentColor,
    this.onTap,
    super.key,
  });

  final JournalEntry entry;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  State<JournalEntryTile> createState() => _JournalEntryTileState();
}

class _JournalEntryTileState extends State<JournalEntryTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final JournalEntry entry = widget.entry;
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final bool hidden = entry.isSpoiler && !_revealed;
    final bool isQuote = entry.kind == JournalEntryKind.quote;
    final String? progress = entry.progressLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: hidden ? () => setState(() => _revealed = true) : widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              journalKindIcon(entry.kind),
              size: 20,
              color: widget.accentColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    <String>[
                      journalKindLabel(entry.kind, l),
                      material.formatMediumDate(entry.occurredAt),
                      if (progress != null && progress.isNotEmpty) progress,
                    ].join(' · '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (hidden)
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            l.journalSpoilerHidden,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      isQuote ? '“${entry.body ?? ''}”' : entry.body ?? '',
                      style: AppTypography.body.copyWith(
                        fontStyle: isQuote ? FontStyle.italic : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
