import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/lunch_model.dart';
import '../../providers/lunch_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/loading_widget.dart';
import 'lunch_hub_chrome.dart';
import 'lunch_poll_form_page.dart';
import 'lunch_ui_helpers.dart';

class LunchPollsAdminPage extends ConsumerStatefulWidget {
  const LunchPollsAdminPage({super.key});

  @override
  ConsumerState<LunchPollsAdminPage> createState() => _LunchPollsAdminPageState();
}

class _LunchPollsAdminPageState extends ConsumerState<LunchPollsAdminPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    await ref.read(lunchProvider.notifier).loadAdminPolls(
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 7)),
    );
  }

  int _voteTotal(LunchPoll poll) => poll.totalVoteCount;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lunchProvider);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final border = AppThemeColors.borderColor(context);
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          LunchPageTitle(
            title: 'Polls',
            subtitle: 'Create and manage daily lunch polls.',
            trailing: [
              FilledButton.icon(
                onPressed: () => showLunchPollFormSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.status == LunchLoadStatus.loading && state.adminPolls.isEmpty)
            const LoadingWidget(message: 'Loading polls…')
          else if (state.adminPolls.isEmpty)
            CRMCard(
              child: Text('No polls yet', style: TextStyle(color: textSecondary)),
            )
          else
            ...state.adminPolls.map(
              (poll) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CRMCard(
                  onTap: () => showLunchPollFormSheet(context, ref, existing: poll),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  poll.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                                if (poll.date != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('EEE, MMM d, yyyy').format(poll.date!.toLocal()),
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          lunchPollStatusBadge(poll.effectiveStatus),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.how_to_vote_outlined,
                            label: '${_voteTotal(poll)} votes',
                            color: primary,
                          ),
                          const SizedBox(width: 8),
                          if (poll.endTime != null && poll.endTime!.isNotEmpty)
                            _MetaChip(
                              icon: Icons.schedule,
                              label: formatLunchEndTimeDisplay(poll.endTime),
                              color: textSecondary,
                            ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: textSecondary, size: 20),
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await showLunchPollFormSheet(context, ref, existing: poll);
                                await _load();
                              } else if (v == 'close' && poll.isVotingOpen) {
                                await ref.read(lunchProvider.notifier).closePoll(poll.id);
                                await _load();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              if (poll.isVotingOpen)
                                const PopupMenuItem(value: 'close', child: Text('Close poll')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
