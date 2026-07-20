import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'loading_widget.dart';

/// Network image with placeholder, fade-in, error fallback, and fixed size.
class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.errorIcon = Icons.broken_image_outlined,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final IconData errorIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = width ?? double.infinity;
    final h = height ?? 120.0;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: w,
      height: h,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => ImageSkeleton(
        width: w.isFinite ? w : double.infinity,
        height: h,
        borderRadius: borderRadius,
      ),
      errorWidget: (_, _, _) => Container(
        width: w.isFinite ? w : null,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(errorIcon, color: cs.onSurfaceVariant, size: 28),
      ),
    );

    if (borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return SizedBox(width: width, height: height, child: image);
  }
}
