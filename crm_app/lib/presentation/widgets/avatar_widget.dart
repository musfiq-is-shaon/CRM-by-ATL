import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

class AvatarWidget extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    this.name,
    this.imageUrl,
    this.size = AppSizes.avatarDefault,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitials(context),
        ),
      );
    }
    return _buildInitials(context);
  }

  Widget _buildInitials(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String initials = '?';
    if (name != null && name!.isNotEmpty) {
      final parts = name!.split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = name![0].toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
