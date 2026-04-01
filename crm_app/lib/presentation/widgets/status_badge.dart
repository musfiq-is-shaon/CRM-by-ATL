import 'package:flutter/material.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/color_scheme_semantics.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String type; // 'task', 'sale', 'category', 'expense', or 'leave'

  const StatusBadge({super.key, required this.status, required this.type});

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColor(context);
    final fg = _foregroundColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getDisplayText(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  Color _foregroundColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case 'task':
        switch (status.toLowerCase()) {
          case 'pending':
            return cs.secondary;
          case 'in_progress':
            return cs.primary;
          case 'completed':
            return cs.tertiary;
          case 'cancelled':
            return cs.outline;
          default:
            return cs.onSurfaceVariant;
        }
      case 'sale':
        switch (status.toLowerCase()) {
          case 'lead':
            return cs.primary;
          case 'prospect':
            return cs.tertiary;
          case 'proposal':
            return cs.secondary;
          case 'negotiation':
            return cs.primary;
          case 'closed':
          case 'closed_won':
            return cs.tertiary;
          case 'closed_lost':
            return cs.error;
          case 'disqualified':
            return cs.onSurfaceVariant;
          default:
            return cs.onSurfaceVariant;
        }
      case 'category':
        switch (status.toLowerCase()) {
          case 'hot':
            return cs.error;
          case 'warm':
            return cs.secondary;
          case 'cold':
            return cs.tertiary;
          default:
            return cs.onSurfaceVariant;
        }
      case 'expense':
        switch (status.toLowerCase()) {
          case 'unpaid':
            return AppThemeColors.expenseUnpaidColor(context);
          case 'paid':
            return AppThemeColors.expensePaidColor(context);
          default:
            return cs.onSurfaceVariant;
        }
      case 'leave':
        switch (status.toLowerCase()) {
          case 'approved':
          case 'accept':
            return cs.tertiary;
          case 'rejected':
          case 'denied':
            return cs.error;
          case 'pending':
          case 'submitted':
            return cs.secondary;
          case 'cancelled':
          case 'canceled':
            return cs.outline;
          default:
            return cs.onSurfaceVariant;
        }
      default:
        return cs.onSurfaceVariant;
    }
  }

  Color _backgroundColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (type == 'expense') {
      switch (status.toLowerCase()) {
        case 'unpaid':
          return AppThemeColors.expenseUnpaidBackgroundColor(context);
        case 'paid':
          return AppThemeColors.expensePaidBackgroundColor(context);
        default:
          return cs.onSurfaceVariant.withValues(alpha: 0.12);
      }
    }
    return cs.tonalChipBackground(_foregroundColor(context));
  }

  String _getDisplayText() {
    if (type == 'leave') {
      switch (status.toLowerCase()) {
        case 'approved':
        case 'accept':
          return 'Approved';
        case 'rejected':
        case 'denied':
          return 'Rejected';
        case 'submitted':
          return 'Submitted';
        case 'pending':
          return 'Pending';
        case 'cancelled':
        case 'canceled':
          return 'Cancelled';
        default:
          if (status.isEmpty) return status;
          return status[0].toUpperCase() + status.substring(1).toLowerCase();
      }
    }
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'closed_won':
        return 'Closed Won';
      case 'closed_lost':
        return 'Closed Lost';
      default:
        return status.substring(0, 1).toUpperCase() + status.substring(1);
    }
  }
}
