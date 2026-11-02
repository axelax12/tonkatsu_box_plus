import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/together_providers.dart';
import '../widgets/together_results.dart';
import '../widgets/together_setup.dart';
import '../widgets/together_vote.dart';

/// "Pick together": set up the group, pass the phone, read the verdict.
class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TogetherStep step = ref.watch(
      togetherProvider.select((TogetherState s) => s.step),
    );
    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      child: switch (step) {
        TogetherStep.setup => const TogetherSetup(key: ValueKey<int>(0)),
        TogetherStep.handoff => const TogetherHandoff(key: ValueKey<int>(1)),
        TogetherStep.voting => const TogetherBallotCard(key: ValueKey<int>(2)),
        TogetherStep.results => const TogetherResults(key: ValueKey<int>(3)),
      },
    );
  }
}
