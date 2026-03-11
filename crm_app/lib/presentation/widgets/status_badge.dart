import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String type; // 'task', 'sale', 'category', or 'expense'

  const StatusBadge({super.key, required this.status, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getDisplayText(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _getTextColor(),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case 'task':
        switch (status.toLowerCase()) {
          case 'pending':
            return AppColors.taskPending.withOpacity(0.1);
          case 'in_progress':
            return AppColors.taskInProgress.withOpacity(0.1);
          case 'completed':
            return AppColors.taskCompleted.withOpacity(0.1);
          case 'cancelled':
            return AppColors.taskCancelled.withOpacity(0.1);
          default:
            return AppColors.textTertiary.withOpacity(0.1);
        }
      case 'sale':
        switch (status.toLowerCase()) {
          case 'lead':
            return AppColors.lead.withOpacity(0.1);
          case 'prospect':
            return AppColors.prospect.withOpacity(0.1);
          case 'proposal':
            return AppColors.proposal.withOpacity(0.1);
          case 'negotiation':
            return AppColors.negotiation.withOpacity(0.1);
          case 'closed':
          case 'closed_won':
            return AppColors.closedWon.withOpacity(0.1);
          case 'closed_lost':
            return AppColors.closedLost.withOpacity(0.1);
          case 'disqualified':
            return AppColors.disqualified.withOpacity(0.1);
          default:
            return AppColors.textTertiary.withOpacity(0.1);
        }
      case 'category':
        switch (status.toLowerCase()) {
          case 'hot':
            return AppColors.hot.withOpacity(0.1);
          case 'warm':
            return AppColors.warm.withOpacity(0.1);
          case 'cold':
            return AppColors.cold.withOpacity(0.1);
          default:
            return AppColors.textTertiary.withOpacity(0.1);
        }
      case 'expense':
        switch (status.toLowerCase()) {
          case 'unpaid':
            return Colors.orange.withOpacity(0.1);
          case 'paid':
            return Colors.green.withOpacity(0.1);
          default:
            return AppColors.textTertiary.withOpacity(0.1);
        }
      default:
        return AppColors.textTertiary.withOpacity(0.1);
    }
  }

  Color _getTextColor() {
    switch (type) {
      case 'task':
        switch (status.toLowerCase()) {
          case 'pending':
            return AppColors.taskPending;
          case 'in_progress':
            return AppColors.taskInProgress;
          case 'completed':
            return AppColors.taskCompleted;
          case 'cancelled':
            return AppColors.taskCancelled;
          default:
            return AppColors.textTertiary;
        }
      case 'sale':
        switch (status.toLowerCase()) {
          case 'lead':
            return AppColors.lead;
          case 'prospect':
            return AppColors.prospect;
          case 'proposal':
            return AppColors.proposal;
          case 'negotiation':
            return AppColors.negotiation;
          case 'closed':
          case 'closed_won':
            return AppColors.closedWon;
          case 'closed_lost':
            return AppColors.closedLost;
          case 'disqualified':
            return AppColors.disqualified;
          default:
            return AppColors.textTertiary;
        }
      case 'category':
        switch (status.toLowerCase()) {
          case 'hot':
            return AppColors.hot;
          case 'warm':
            return AppColors.warm;
          case 'cold':
            return AppColors.cold;
          default:
            return AppColors.textTertiary;
        }
      case 'expense':
        switch (status.toLowerCase()) {
          case 'unpaid':
            return Colors.orange;
          case 'paid':
            return Colors.green;
          default:
            return AppColors.textTertiary;
        }
      default:
        return AppColors.textTertiary;
    }
  }

  String _getDisplayText() {
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
