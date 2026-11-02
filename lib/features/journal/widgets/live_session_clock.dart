import 'dart:async';

import 'package:core/plus/models/play_session.dart';
import 'package:flutter/material.dart';

import '../utils/journal_format.dart';

/// Ticks once a second while mounted; the elapsed time is always derived from
/// the stored start, so a killed app resumes at the right number.
class LiveSessionClock extends StatefulWidget {
  const LiveSessionClock({required this.session, this.style, super.key});

  final PlaySession session;
  final TextStyle? style;

  @override
  State<LiveSessionClock> createState() => _LiveSessionClockState();
}

class _LiveSessionClockState extends State<LiveSessionClock> {
  static const Duration _tick = Duration(seconds: 1);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (Timer _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatClock(widget.session.elapsed(DateTime.now())),
      style: widget.style?.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
