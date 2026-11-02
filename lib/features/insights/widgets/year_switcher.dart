import 'package:flutter/material.dart';

import '../../../shared/theme/app_typography.dart';

/// ‹ 2026 › — never past the current year.
class YearSwitcher extends StatelessWidget {
  const YearSwitcher({required this.year, required this.onChanged, super.key});

  final int year;
  final ValueChanged<int> onChanged;

  static const int firstYear = 2000;

  @override
  Widget build(BuildContext context) {
    final int current = DateTime.now().year;
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: material.previousPageTooltip,
          onPressed: year > firstYear ? () => onChanged(year - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$year', style: AppTypography.h2),
        IconButton(
          tooltip: material.nextPageTooltip,
          onPressed: year < current ? () => onChanged(year + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
