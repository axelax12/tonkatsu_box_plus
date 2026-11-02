import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../shared/constants/platform_features.dart';

final Logger _log = Logger('CoverAccent');

/// The cover's dominant colour, tuned for the dark theme: works that are
/// mostly red read red, and a pale cover never turns text unreadable.
final FutureProviderFamily<Color?, String> coverAccentProvider =
    FutureProvider.family<Color?, String>((Ref ref, String url) async {
      if (!kIsMobile || url.isEmpty) return null;
      try {
        final ColorScheme scheme = await ColorScheme.fromImageProvider(
          provider: ResizeImage(NetworkImage(url), width: _sampleWidth),
          brightness: Brightness.dark,
        );
        return scheme.primary;
      } on Exception catch (e, stack) {
        _log.fine('No accent for $url', e, stack);
        return null;
      }
    });

/// Small enough to quantise in a few milliseconds; colour, not detail.
const int _sampleWidth = 96;
