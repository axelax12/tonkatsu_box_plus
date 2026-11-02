import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../gyroscope_parallax_image.dart';

/// Full-bleed backdrop image with a darkening gradient under [child].
class MediaDetailBackdrop extends StatelessWidget {
  const MediaDetailBackdrop({
    required this.imageUrl,
    required this.child,
    this.blurred = false,
    super.key,
  });

  final String imageUrl;
  final Widget child;

  /// For a cover standing in for missing artwork: sharp, it would read as a
  /// stretched poster rather than a backdrop.
  final bool blurred;

  static const double _blurSigma = 32;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: blurred
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _blurSigma,
                    sigmaY: _blurSigma,
                  ),
                  child: GyroscopeParallaxImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                )
              : GyroscopeParallaxImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.background.withAlpha(120),
                  AppColors.background.withAlpha(200),
                  AppColors.background,
                ],
                stops: const <double>[0.0, 0.35, 0.6],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
