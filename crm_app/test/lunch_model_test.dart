import 'package:flutter_test/flutter_test.dart';
import 'package:crm/data/models/lunch_model.dart';
import 'package:crm/core/utils/lunch_poll_schedule.dart';
import 'package:crm/presentation/pages/lunch/lunch_ui_helpers.dart';

void main() {
  group('LunchOrderSummary', () {
    test('parses summary with menu breakdown and employee votes', () {
      final summary = LunchOrderSummary.fromJson({
        'poll': {
          'id': 'p1',
          'title': 'Today\'s Lunch',
          'date': '2026-06-22',
          'status': 'closed',
        },
        'officeOrders': 10,
        'personalCount': 3,
        'totalVotes': 13,
        'menuBreakdown': [
          {'label': 'ডিম ভুনা', 'optionType': 'office_menu', 'votes': 2},
          {'label': 'Personal', 'optionType': 'personal', 'votes': 3},
        ],
        'employeeVotes': [
          {
            'userName': 'John Doe',
            'choice': 'ডিম ভুনা',
            'optionType': 'office_menu',
            'votedAt': '2026-06-22T15:03:00Z',
          },
        ],
      });

      expect(summary.officeOrders, 10);
      expect(summary.personalCount, 3);
      expect(summary.totalVotes, 13);
      expect(summary.menuBreakdown.length, 2);
      expect(summary.employeeVotes.first.userName, 'John Doe');
      expect(summary.poll.status, 'closed');
    });

    test('parses employee votes with optionId resolved from poll', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(
            id: 'o1',
            label: 'Chicken',
            optionType: 'office_menu',
          ),
        ],
      );
      final summary = LunchOrderSummary.fromJson({
        'poll': {'id': 'p1', 'title': 'Lunch', 'options': []},
        'votes': [
          {
            'userName': 'Alice',
            'optionId': 'o1',
            'votedAt': '2026-06-22T10:00:00Z',
          },
        ],
      }, pollFallback: poll);

      expect(summary.employeeVotes.length, 1);
      expect(summary.employeeVotes.first.userName, 'Alice');
      expect(summary.employeeVotes.first.choice, 'Chicken');
      expect(summary.employeeVotes.first.optionType, 'office_menu');
    });

    test('sortTodayPollsNewestFirst puts newer poll first on same day', () {
      final older = LunchPoll(
        id: '674000001234567890123456',
        title: 'Old',
        date: DateTime(2026, 6, 28),
      );
      final newer = LunchPoll(
        id: '675000001234567890123456',
        title: 'New',
        date: DateTime(2026, 6, 28),
      );
      final sorted = sortTodayPollsNewestFirst([older, newer]);
      expect(sorted.first.title, 'New');
      expect(sorted.last.title, 'Old');
    });

    test('withPollScopedVotes strips myVote when option id is not on poll', () {
      final poll = LunchPoll(
        id: 'p2',
        title: 'Poll 2',
        options: [
          LunchPollOption(id: 'o3', label: 'Fish', optionType: 'office'),
        ],
        myVote: LunchMyVote(optionId: 'o1'),
      );
      final scoped = poll.withPollScopedVotes();
      expect(scoped.scopedMyVote, isNull);
    });

    test('mergedOptions does not match results by label when option has id', () {
      final poll = LunchPoll(
        id: 'p2',
        title: 'Poll 2',
        options: [
          LunchPollOption(id: 'p2-personal', label: 'Personal', optionType: 'personal'),
        ],
        results: [
          LunchPollOption(
            id: 'p1-personal',
            label: 'Personal',
            optionType: 'personal',
            voteCount: 5,
          ),
        ],
      );
      expect(poll.mergedOptions.first.voteCount, 0);
    });

    test('LunchTodayBundle appends featured poll when missing from items', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p1',
            'title': 'Lunch',
            'date': '2026-06-28',
            'status': 'closed',
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office'},
            ],
          },
        ],
        'poll': {
          'id': 'p2',
          'title': 'Lunch',
          'date': '2026-06-28',
          'status': 'active',
          'options': [
            {'id': 'o3', 'label': 'Fish', 'optionType': 'office'},
          ],
        },
        'myVote': {'optionId': 'o3'},
        'results': [
          {'id': 'o3', 'label': 'Fish', 'optionType': 'office', 'votes': 1},
        ],
      });
      expect(bundle.items.length, 2);
      expect(bundle.items.first.id, 'p2');
      expect(bundle.items.firstWhere((p) => p.id == 'p1').myVote, isNull);
      expect(bundle.items.firstWhere((p) => p.id == 'p2').myVote?.optionId, 'o3');
    });

    test('LunchTodayBundle featured shell does not revive closed poll', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 2));
      final endTime =
          '${tomorrow.hour.toString().padLeft(2, '0')}:${tomorrow.minute.toString().padLeft(2, '0')}';
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p1',
            'title': 'Lunch',
            'date': '2026-06-28',
            'status': 'closed',
            'endTime': endTime,
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office'},
            ],
          },
        ],
        'myVote': {'optionId': 'o1'},
        'results': [
          {'id': 'o1', 'label': 'Chicken', 'optionType': 'office', 'votes': 2},
        ],
      });
      expect(bundle.items, hasLength(1));
      expect(bundle.items.first.status, 'closed');
      expect(bundle.items.first.myVote?.optionId, 'o1');
    });

    test('LunchTodayBundle keeps same-title polls with different ids', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p2',
            'title': 'Lunch',
            'date': '2026-06-28',
            'status': 'active',
          },
          {
            'id': 'p1',
            'title': 'Lunch',
            'date': '2026-06-28',
            'status': 'closed',
          },
        ],
        'poll': {'id': 'p2', 'title': 'Lunch', 'status': 'active'},
      });
      expect(bundle.items.length, 2);
      expect(bundle.items.map((p) => p.id).toSet(), {'p1', 'p2'});
    });

    test('LunchTodayBundle does not prepend legacy as duplicate card', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p2',
            'title': 'New Lunch',
            'status': 'active',
            'options': [
              {'id': 'o3', 'label': 'Fish', 'optionType': 'office'},
            ],
          },
          {
            'id': 'p1',
            'title': 'Old Lunch',
            'status': 'closed',
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office'},
            ],
          },
        ],
        'poll': {'id': 'p1', 'title': 'Old Lunch', 'status': 'closed'},
        'myVote': {'optionId': 'o1'},
        'results': [
          {'id': 'o1', 'label': 'Chicken', 'optionType': 'office', 'votes': 2},
        ],
      });
      expect(bundle.items.length, 2);
      expect(bundle.items.where((p) => p.id == 'p1').length, 1);
      expect(bundle.items.firstWhere((p) => p.id == 'p2').myVote, isNull);
    });

    test('LunchTodayBundle picks featured poll from poll field when items omit id', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'title': 'Old Lunch',
            'status': 'closed',
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office'},
            ],
          },
          {'id': 'p2', 'title': 'New Lunch', 'status': 'active'},
        ],
        'poll': {'id': 'p1', 'title': 'Old Lunch', 'status': 'closed'},
      });
      expect(bundle.items.length, 2);
      expect(bundle.items.map((p) => p.id).toSet(), {'p1', 'p2'});
    });

    test('LunchTodayBundle does not bleed top-level votes across multiple polls', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p2',
            'title': 'Newest Lunch',
            'status': 'active',
            'options': [
              {'id': 'o3', 'label': 'Fish', 'optionType': 'office'},
            ],
          },
          {
            'id': 'p1',
            'title': 'Earlier Lunch',
            'status': 'closed',
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office'},
            ],
          },
        ],
        'poll': {
          'id': 'p2',
          'title': 'Newest Lunch',
          'status': 'active',
        },
        'myVote': {'optionId': 'o3', 'votedAt': '2026-06-28T10:00:00Z'},
        'results': [
          {
            'id': 'o3',
            'label': 'Fish',
            'optionType': 'office',
            'votes': 2,
          },
        ],
      });
      expect(bundle.items.length, 2);
      final newest = bundle.items.firstWhere((p) => p.id == 'p2');
      final older = bundle.items.firstWhere((p) => p.id == 'p1');
      expect(newest.myVote?.optionId, 'o3');
      expect(newest.mergedOptions.first.voteCount, 2);
      expect(older.myVote, isNull);
      expect(older.mergedOptions.first.voteCount, 0);
    });

    test('LunchTodayBundle dedupes same poll id in items', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p2',
            'title': 'Lunch',
            'status': 'active',
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office'},
            ],
          },
          {
            'id': 'p2',
            'title': 'Lunch',
            'status': 'active',
          },
        ],
        'poll': {'id': 'p2', 'title': 'Lunch', 'status': 'active'},
        'myVote': {'optionId': 'o1'},
        'results': [
          {'id': 'o1', 'label': 'Chicken', 'optionType': 'office', 'votes': 1},
        ],
      });
      expect(bundle.items.length, 1);
      expect(bundle.items.first.id, 'p2');
      expect(bundle.items.first.myVote?.optionId, 'o1');
    });

    test('LunchTodayBundle merges top-level myVote and results', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p1',
            'title': 'Today\'s Lunch',
            'status': 'cancelled',
            'options': [
              {'id': 'o1', 'label': 'Chicken', 'optionType': 'office_menu'},
            ],
          },
        ],
        'myVote': {'optionId': 'o1', 'votedAt': '2026-06-22T10:00:00Z'},
        'results': [
          {
            'id': 'o1',
            'label': 'Chicken',
            'optionType': 'office_menu',
            'votes': 3,
            'voters': ['Alice', 'Bob'],
          },
        ],
      });
      expect(bundle.items.length, 1);
      expect(bundle.items.first.myVote?.optionId, 'o1');
      expect(bundle.items.first.mergedOptions.first.voteCount, 3);
      expect(bundle.items.first.mergedOptions.first.voters.length, 2);
    });

    test('mergeAfterVote keeps local myVote when server is stale', () {
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o2'),
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 3),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 2),
        ],
      );
      final server = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o1'),
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 4),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 1),
        ],
      );
      final merged = LunchPoll.mergeAfterVote(local: local, server: server);
      expect(merged.myVote?.optionId, 'o2');
      expect(merged.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 4);
    });

    test('mergeAfterVote keeps authoritative server closed status', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 2));
      final endTime =
          '${tomorrow.hour.toString().padLeft(2, '0')}:${tomorrow.minute.toString().padLeft(2, '0')}';
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'active',
        endTime: endTime,
        myVote: LunchMyVote(optionId: 'o1'),
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 1),
        ],
      );
      final server = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'closed',
        endTime: endTime,
        myVote: LunchMyVote(optionId: 'o1'),
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 1),
        ],
      );
      final merged = LunchPoll.mergeAfterVote(local: local, server: server);
      expect(merged.status, 'closed');
    });

    test('mergeAfterVote takes authoritative past server endTime', () {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 2));
      final past = now.subtract(const Duration(hours: 1));
      final futureApi =
          '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
      final pastApi =
          '${past.hour.toString().padLeft(2, '0')}:${past.minute.toString().padLeft(2, '0')}';
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: DateTime(now.year, now.month, now.day),
        status: 'active',
        endTime: futureApi,
        myVote: LunchMyVote(optionId: 'o1'),
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 1),
        ],
      );
      final server = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: local.date,
        status: 'active',
        endTime: pastApi,
        myVote: LunchMyVote(optionId: 'o1'),
        options: local.options,
      );
      final merged = LunchPoll.mergeAfterVote(local: local, server: server);
      expect(merged.endTime, pastApi);
    });

    test('withMyVote clears voters when previous option reaches zero', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o1'),
        results: [
          LunchPollOption(
            id: 'o1',
            label: 'A',
            optionType: 'office_menu',
            voteCount: 1,
            voters: const [LunchOptionVoter(name: 'You')],
          ),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 2),
        ],
      );
      final updated = poll.withMyVote('o2');
      final prev = updated.mergedOptions.firstWhere((o) => o.id == 'o1');
      expect(prev.voteCount, 0);
      expect(prev.effectiveVoteCount, 0);
      expect(prev.voters, isEmpty);
    });

    test('applyServerSnapshot prefers lower authoritative reportedTotalVotes', () {
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        reportedTotalVotes: 9,
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 3),
        ],
      );
      final fresh = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        reportedTotalVotes: 4,
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 4),
        ],
      );
      final merged = local.applyServerSnapshot(fresh);
      expect(merged.totalVoteCount, 4);
    });

    test('restoreMyVote undoes optimistic first vote on current poll', () {
      final prior = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 2),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 1),
        ],
        reportedTotalVotes: 3,
      );
      final optimistic = prior.withMyVote('o1');
      expect(optimistic.totalVoteCount, 4);
      final restored = optimistic.restoreMyVote(null);
      expect(restored.myVote, isNull);
      expect(restored.totalVoteCount, 3);
      expect(restored.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 2);
    });

    test('restoreMyVote switches back to prior choice', () {
      final prior = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o1', votedAt: DateTime(2026, 1, 1)),
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 5),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 3),
        ],
        reportedTotalVotes: 8,
      );
      final optimistic = prior.withMyVote('o2');
      final restored = optimistic.restoreMyVote(prior.myVote);
      expect(restored.myVote?.optionId, 'o1');
      expect(restored.myVote?.votedAt, DateTime(2026, 1, 1));
      expect(restored.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 5);
      expect(restored.mergedOptions.firstWhere((o) => o.id == 'o2').voteCount, 3);
    });

    test('restoreMyVote same option restores prior votedAt', () {
      final priorAt = DateTime(2026, 1, 1, 10);
      final optimisticAt = DateTime(2026, 1, 1, 12);
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o1', votedAt: optimisticAt),
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 1),
        ],
      );
      final restored = poll.restoreMyVote(
        LunchMyVote(optionId: 'o1', votedAt: priorAt),
      );
      expect(restored.myVote?.optionId, 'o1');
      expect(restored.myVote?.votedAt, priorAt);
      expect(restored.mergedOptions.first.voteCount, 1);
    });

    test('restoreMyVote without adjustCounts keeps server option totals', () {
      final prior = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o1'),
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 5),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 3),
        ],
      );
      final refreshed = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o2'),
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 10),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 8),
        ],
        reportedTotalVotes: 18,
      );
      final restored = refreshed.restoreMyVote(prior.myVote, adjustCounts: false);
      expect(restored.myVote?.optionId, 'o1');
      expect(restored.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 10);
      expect(restored.totalVoteCount, 18);
    });

    test('withMyVote shifts counts when changing vote', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        myVote: LunchMyVote(optionId: 'o1'),
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 5),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 3),
        ],
        reportedTotalVotes: 8,
      );
      final updated = poll.withMyVote('o2');
      expect(updated.myVote?.optionId, 'o2');
      expect(updated.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 4);
      expect(updated.mergedOptions.firstWhere((o) => o.id == 'o2').voteCount, 4);
      expect(updated.totalVoteCount, 8);
    });

    test('withMyVote increments reportedTotalVotes on first vote', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 2),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 1),
        ],
        reportedTotalVotes: 3,
      );
      final updated = poll.withMyVote('o1');
      expect(updated.totalVoteCount, 4);
      expect(updated.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 3);
    });

    test('withMyVote first vote uses option sums when reportedTotalVotes missing', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        results: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office_menu', voteCount: 2),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'office_menu', voteCount: 1),
        ],
      );
      final updated = poll.withMyVote('o1');
      expect(updated.totalVoteCount, 4);
      expect(updated.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 3);
    });

    test('LunchVoteHistoryRow parses menu item and amount', () {
      final row = LunchVoteHistoryRow.fromJson({
        'pollTitle': 'Today\'s Lunch',
        'pollDate': '2026-06-22',
        'menuItem': 'মুরগির মাংস',
        'optionType': 'office_menu',
        'amount': -65,
      });
      expect(row.menuItem, 'মুরগির মাংস');
      expect(row.amount, -65);
    });

    test('LunchTodayBundle merges options from top-level poll object', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p1',
            'title': 'Today\'s Lunch',
            'status': 'active',
          },
        ],
        'poll': {
          'id': 'p1',
          'options': [
            {'id': 'o1', 'label': 'Chicken', 'optionType': 'office_menu'},
            {'id': 'o2', 'label': 'Personal', 'optionType': 'personal'},
          ],
        },
        'myVote': {'optionId': 'o1'},
      });
      expect(bundle.items.length, 1);
      expect(bundle.items.first.mergedOptions.length, 2);
      expect(bundle.items.first.mergedOptions.first.label, 'Chicken');
    });

    test('LunchTodayBundle parses wrapped options map', () {
      final bundle = LunchTodayBundle.fromJson({
        'items': [
          {
            'id': 'p1',
            'title': 'Lunch',
            'options': {
              'items': [
                {'id': 'o1', 'label': 'Rice', 'optionType': 'office_menu'},
              ],
            },
          },
        ],
      });
      expect(bundle.items.first.mergedOptions.length, 1);
      expect(bundle.items.first.mergedOptions.first.label, 'Rice');
    });

    test('derives employee votes from menu breakdown voters', () {
      final summary = LunchOrderSummary.fromJson({
        'poll': {'id': 'p1', 'title': 'Lunch'},
        'menuBreakdown': [
          {
            'label': 'Chicken',
            'optionType': 'office_menu',
            'votes': 2,
            'voters': [
              {'userName': 'Alice'},
              {'userName': 'Bob'},
            ],
          },
        ],
      });
      expect(summary.employeeVotes.length, 2);
      expect(summary.employeeVotes.first.userName, 'Alice');
    });

    test('fromVoteHistoryRows maps admin history to employee votes', () {
      final votes = LunchOrderSummary.fromVoteHistoryRows([
        const LunchVoteHistoryRow(
          pollTitle: 'Lunch',
          pollId: 'p1',
          userName: 'Alice',
          menuItem: 'Chicken',
          optionType: 'office_menu',
        ),
      ], pollId: 'p1');
      expect(votes.length, 1);
      expect(votes.first.userName, 'Alice');
      expect(votes.first.choice, 'Chicken');
    });

    test('lunchOptionKindFrom maps office API type to office menu', () {
      expect(lunchOptionKindFrom('office'), LunchOptionKind.officeMenu);
      expect(lunchOptionKindFrom('office_menu'), LunchOptionKind.officeMenu);
      expect(lunchOptionKindFrom('off'), LunchOptionKind.offAbsent);
      expect(lunchOptionKindFrom('coffee'), LunchOptionKind.other);
      expect(lunchOptionKindFrom('offsite'), LunchOptionKind.other);
      expect(lunchOptionKindFrom('yes'), LunchOptionKind.other);
    });

    test('totalVoteCount uses effectiveVoteCount for mixed payloads', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(
            id: 'o1',
            label: 'A',
            optionType: 'office',
            voteCount: 2,
          ),
          LunchPollOption(
            id: 'o2',
            label: 'B',
            optionType: 'personal',
            voteCount: 0,
            voters: const [
              LunchOptionVoter(name: 'x'),
              LunchOptionVoter(name: 'y'),
            ],
          ),
        ],
      );
      expect(poll.totalVoteCount, 4);
    });

    test('toAddOptionJson uses office for office menu append', () {
      final option = LunchPollOption(
        id: '',
        label: 'Chicken',
        optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
      );
      final json = option.toAddOptionJson();
      expect(json['optionType'], 'office');
      expect(json['label'], 'Chicken');
      expect(json.containsKey('name'), isFalse);
    });

    test('toCreateJson uses office for office menu options', () {
      final option = LunchPollOption(
        id: '',
        label: 'Chicken',
        optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
      );
      final json = option.toCreateJson();
      expect(json['optionType'], 'office');
    });

    test('optionsOrderedForCreate puts office menus before personal and off', () {
      final poll = LunchPoll(
        id: '',
        title: 'Lunch',
        options: [
          LunchPollOption(id: '', label: 'Personal', optionType: 'personal'),
          LunchPollOption(id: '', label: 'Off', optionType: 'off'),
          LunchPollOption(
            id: '',
            label: 'Chicken',
            optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
          ),
        ],
      );
      final ordered = poll.optionsOrderedForCreate();
      expect(ordered.length, 3);
      expect(ordered.first.label, 'Chicken');
      expect(ordered[1].label, 'Personal');
      expect(ordered.last.label, 'Off');
    });

    test('partitionForCreate splits options beyond two for staged create', () {
      final poll = LunchPoll(
        id: '',
        title: 'Lunch',
        options: [
          LunchPollOption(id: '', label: 'Personal', optionType: 'personal'),
          LunchPollOption(id: '', label: 'Off', optionType: 'off'),
          LunchPollOption(
            id: '',
            label: 'Chicken',
            optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
          ),
        ],
      );
      final parts = poll.partitionForCreate();
      expect(parts.initial.length, 2);
      expect(parts.extras.length, 1);
      expect(parts.extras.first.label, 'Chicken');
    });

    test('LunchEmployeeBalance avoids duplicate period and total display', () {
      final same = LunchEmployeeBalance.fromJson({
        'userId': 'u1',
        'userName': 'Alice',
        'netChange': 120,
        'balance': 120,
      });
      expect(same.periodNetChange, 120);
      expect(same.runningBalance, isNull);

      final distinct = LunchEmployeeBalance.fromJson({
        'userId': 'u2',
        'userName': 'Bob',
        'netChange': 60,
        'balance': 500,
      });
      expect(distinct.periodNetChange, 60);
      expect(distinct.runningBalance, 500);

      final periodOnly = LunchEmployeeBalance.fromJson({
        'userId': 'u3',
        'userName': 'Cara',
        'balance': 80,
      });
      expect(periodOnly.periodNetChange, 80);
      expect(periodOnly.runningBalance, isNull);

      final zeroNet = LunchEmployeeBalance.fromJson({
        'userId': 'u4',
        'userName': 'Dan',
        'netChange': 0,
        'balance': 500,
      });
      expect(zeroNet.periodNetChange, 0);
      expect(zeroNet.runningBalance, 500);
    });

    test('toUpdateJsonSequence batches multiple new options in one options request', () {
      final original = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: 'o1', label: 'Personal', optionType: 'personal'),
          LunchPollOption(id: 'o2', label: 'Off', optionType: 'off'),
        ],
      );
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          ...original.options,
          LunchPollOption(
            id: '',
            label: 'Chicken',
            optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
          ),
          LunchPollOption(
            id: '',
            label: 'Rice',
            optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
          ),
        ],
      );

      final payloads = poll.toUpdateJsonSequence(original: original);
      expect(payloads.length, 1);
      expect(payloads.first.containsKey('optionUpdates'), isFalse);
      final opts = payloads.first['options'] as List;
      expect(opts.length, 4);
      expect(opts[0]['label'], 'Chicken');
      expect(opts[0]['orderIndex'], 0);
      expect(opts[0]['pollId'], 'p1');
      expect(opts[0].containsKey('id'), isFalse);
      expect(opts[1]['label'], 'Rice');
      expect(opts[2]['id'], 'o1');
      expect(opts[3]['id'], 'o2');
    });

    test('toUpdateJsonSequence sends options for new items', () {
      final original = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: 'o1', label: 'Personal', optionType: 'personal'),
          LunchPollOption(id: 'o2', label: 'Off', optionType: 'off'),
        ],
      );
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          ...original.options,
          LunchPollOption(
            id: '',
            label: 'Chicken',
            optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
          ),
        ],
      );

      final payloads = poll.toUpdateJsonSequence(original: original);
      expect(payloads.length, 1);
      expect(payloads.first.containsKey('optionUpdates'), isFalse);
      final opts = payloads.first['options'] as List;
      expect(opts.length, 3);
      expect(opts[0]['label'], 'Chicken');
      expect(opts[0]['orderIndex'], 0);
      expect(opts[0]['pollId'], 'p1');
      expect(opts[0].containsKey('id'), isFalse);
      expect(opts[1]['id'], 'o1');
      expect(opts[2]['id'], 'o2');
    });

    test('toUpdateJsonSequence splits metadata and new options', () {
      final original = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: 'o1', label: 'Personal', optionType: 'personal'),
        ],
      );
      final poll = LunchPoll(
        id: 'p1',
        title: 'Updated Lunch',
        options: [
          ...original.options,
          LunchPollOption(
            id: '',
            label: 'Chicken',
            optionType: lunchOptionKindApiValue(LunchOptionKind.officeMenu),
          ),
        ],
      );

      final payloads = poll.toUpdateJsonSequence(original: original);
      expect(payloads.length, 2);
      expect(payloads[0]['title'], 'Updated Lunch');
      expect(payloads[0].containsKey('options'), isFalse);
      expect(payloads[1]['options'], isA<List>());
      expect((payloads[1]['options'] as List).length, 2);
      expect(payloads[1].containsKey('optionUpdates'), isFalse);
    });

    test('toUpdateJsonSequence metadata-only has no option arrays', () {
      final original = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: 'o1', label: 'Personal', optionType: 'personal'),
        ],
      );
      final poll = LunchPoll(
        id: 'p1',
        title: 'Updated Lunch',
        options: original.options,
      );

      final payloads = poll.toUpdateJsonSequence(original: original);
      expect(payloads.length, 1);
      expect(payloads[0]['title'], 'Updated Lunch');
      expect(payloads[0].containsKey('options'), isFalse);
      expect(payloads[0].containsKey('optionUpdates'), isFalse);
    });

    test('toUpdateJsonSequence persists option removals', () {
      final original = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
          LunchPollOption(id: 'o2', label: 'Personal', optionType: 'personal'),
          LunchPollOption(id: 'o3', label: 'Off', optionType: 'off'),
        ],
      );
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: 'o2', label: 'Personal', optionType: 'personal'),
          LunchPollOption(id: 'o3', label: 'Off', optionType: 'off'),
        ],
      );

      final payloads = poll.toUpdateJsonSequence(original: original);
      expect(payloads.length, 1);
      expect(payloads.first.containsKey('options'), isTrue);
      final opts = payloads.first['options'] as List;
      expect(opts.length, 2);
      expect(
        opts.map((o) => (o as Map)['label']).toList(),
        containsAll(['Personal', 'Off']),
      );
    });

    test('applyServerSnapshot takes authoritative past server endTime', () {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 2));
      final past = now.subtract(const Duration(hours: 1));
      final futureApi =
          '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
      final pastApi =
          '${past.hour.toString().padLeft(2, '0')}:${past.minute.toString().padLeft(2, '0')}';
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: DateTime(now.year, now.month, now.day),
        status: 'active',
        endTime: futureApi,
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        ],
      );
      final fresh = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: local.date,
        status: 'active',
        endTime: pastApi,
        options: local.options,
      );

      final merged = local.applyServerSnapshot(fresh);
      expect(merged.endTime, pastApi);
    });

    test('applyServerSnapshot prefers authoritative closed from server', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 2));
      final endTime =
          '${tomorrow.hour.toString().padLeft(2, '0')}:${tomorrow.minute.toString().padLeft(2, '0')}';
      final local = LunchPoll(
        id: 'p1',
        title: 'Yesterday Lunch',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        endTime: endTime,
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        ],
        myVote: LunchMyVote(optionId: 'o1'),
      );
      final closed = LunchPoll(
        id: 'p1',
        title: 'Yesterday Lunch',
        date: local.date,
        status: 'closed',
        endTime: endTime,
        options: local.options,
      );

      final merged = local.applyServerSnapshot(closed);
      expect(merged.status, 'closed');
      expect(merged.scopedMyVote?.optionId, 'o1');
    });

    test('applyServerSnapshot does not wipe options when fresh only has results', () {
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'active',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
          LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office'),
        ],
        myVote: LunchMyVote(optionId: 'o2'),
      );
      final fresh = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'active',
        options: const [],
        results: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office', voteCount: 3),
          LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office', voteCount: 1),
        ],
      );

      final merged = local.applyServerSnapshot(fresh);
      expect(merged.options.length, 2);
      expect(merged.scopedMyVote?.optionId, 'o2');
    });

    test('applyServerSnapshot keeps vote tallies when fresh options are sparse', () {
      final local = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'active',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
          LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office'),
        ],
        results: [
          LunchPollOption(
            id: 'o1',
            label: 'Chicken',
            optionType: 'office',
            voteCount: 4,
            voters: const [LunchOptionVoter(name: 'Ada')],
          ),
          LunchPollOption(
            id: 'o2',
            label: 'Fish',
            optionType: 'office',
            voteCount: 2,
            voters: const [LunchOptionVoter(name: 'Bob')],
          ),
        ],
      );
      final fresh = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'active',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
          LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office'),
        ],
      );

      final merged = local.applyServerSnapshot(fresh);
      expect(merged.mergedOptions.firstWhere((o) => o.id == 'o1').voteCount, 4);
      expect(merged.mergedOptions.firstWhere((o) => o.id == 'o1').voters.length, 1);
      expect(merged.mergedOptions.firstWhere((o) => o.id == 'o2').voteCount, 2);
      expect(merged.totalVoteCount, 6);
    });

    test('attachEmployeeVotes fills counts and voter names', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'active',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
          LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office'),
        ],
      ).attachEmployeeVotes(const [
        LunchEmployeeVoteRow(
          userId: 'u1',
          userName: 'Ada',
          choice: 'Chicken',
          optionType: 'office',
        ),
        LunchEmployeeVoteRow(
          userId: 'u2',
          userName: 'Bob',
          choice: 'Chicken',
          optionType: 'office',
        ),
        LunchEmployeeVoteRow(
          userId: 'u3',
          userName: 'Cara',
          choice: 'Fish',
          optionType: 'office',
        ),
      ]);

      final chicken = poll.mergedOptions.firstWhere((o) => o.id == 'o1');
      final fish = poll.mergedOptions.firstWhere((o) => o.id == 'o2');
      expect(chicken.effectiveVoteCount, 2);
      expect(chicken.voters.map((v) => v.name), ['Ada', 'Bob']);
      expect(fish.effectiveVoteCount, 1);
      expect(fish.voters.single.name, 'Cara');
    });

    test('merge prefers active poll with viable end time over stale closed snapshot', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 2));
      final endTime =
          '${tomorrow.hour.toString().padLeft(2, '0')}:${tomorrow.minute.toString().padLeft(2, '0')}';
      final active = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        endTime: endTime,
        myVote: LunchMyVote(optionId: 'o1'),
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        ],
      );
      final closed = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        status: 'closed',
        endTime: '11:30',
        options: active.options,
      );

      final merged = LunchPoll.merge(closed, active);
      expect(merged.status, 'active');
      expect(merged.endTime, endTime);
      expect(merged.scopedMyVote?.optionId, 'o1');
    });

    test('reactivated poll uses today deadline for end time checks', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 2));
      final endTime =
          '${tomorrow.hour.toString().padLeft(2, '0')}:${tomorrow.minute.toString().padLeft(2, '0')}';
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      expect(
        lunchPollIsPastEndTime(
          endTime: endTime,
          pollDate: yesterday,
          status: 'active',
        ),
        isFalse,
      );
      expect(
        isPollEndTimeViable(endTime, yesterday),
        isTrue,
      );
    });

    test('resolvedForMyLunch does not invent active for closed polls', () {
      final tomorrow = DateTime.now().add(const Duration(hours: 2));
      final endTime =
          '${tomorrow.hour.toString().padLeft(2, '0')}:${tomorrow.minute.toString().padLeft(2, '0')}';
      final closed = LunchPoll(
        id: 'p1',
        title: 'Yesterday Lunch',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'closed',
        endTime: endTime,
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        ],
      );

      final resolved = closed.resolvedForMyLunch();
      expect(resolved.status, 'closed');
      expect(resolved.showOnMyLunch, isFalse);
      expect(resolved.appearsOnMyLunchCard, isFalse);
    });

    test('history vote does not guess among multiple office menus by type', () {
      final options = [
        LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office'),
        LunchPollOption(id: 'o3', label: 'Personal', optionType: 'personal'),
      ];
      final ambiguous = LunchVoteHistoryRow(
        pollTitle: 'Lunch',
        menuItem: null,
        optionType: 'office',
      );
      expect(LunchPoll.myVoteFromHistoryRow(ambiguous, options), isNull);

      final byLabel = LunchVoteHistoryRow(
        pollTitle: 'Lunch',
        menuItem: 'Fish',
        optionType: 'office',
      );
      expect(
        LunchPoll.myVoteFromHistoryRow(byLabel, options)?.optionId,
        'o2',
      );

      final byId = LunchVoteHistoryRow(
        pollTitle: 'Lunch',
        optionId: 'o1',
        optionType: 'office',
      );
      expect(
        LunchPoll.myVoteFromHistoryRow(byId, options)?.optionId,
        'o1',
      );

      final uniqueKind = LunchVoteHistoryRow(
        pollTitle: 'Lunch',
        optionType: 'personal',
      );
      expect(
        LunchPoll.myVoteFromHistoryRow(uniqueKind, options)?.optionId,
        'o3',
      );
    });

    test('scopedMyVote ignores votes when option ids are missing', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(id: '', label: 'Chicken', optionType: 'office'),
        ],
        myVote: const LunchMyVote(optionId: 'o1'),
      );
      expect(poll.scopedMyVote, isNull);
    });

    test('reactivated poll disallows vote changes but stays open for first vote', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Old lunch',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        endTime: '23:59',
        allowVoteChange: true,
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        ],
        myVote: LunchMyVote(optionId: 'o1'),
      );

      expect(poll.isReactivatedPoll, isTrue);
      expect(poll.allowsVoteChanges, isFalse);
      expect(poll.isVotingOpen, isTrue);
    });

    test('prior-day poll without vote can still be open for first vote', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Old lunch',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        endTime: '23:59',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
        ],
      );

      expect(poll.scopedMyVote, isNull);
      expect(poll.allowsVoteChanges, isFalse);
      expect(poll.isVotingOpen, isTrue);
    });

    test('applyServerSnapshot keeps newer local vote over stale history vote', () {
      final local = LunchPoll(
        id: 'p1',
        title: 'Old lunch',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        endTime: '23:59',
        options: [
          LunchPollOption(id: 'o1', label: 'Chicken', optionType: 'office'),
          LunchPollOption(id: 'o2', label: 'Fish', optionType: 'office'),
        ],
        myVote: LunchMyVote(
          optionId: 'o2',
          votedAt: DateTime.now(),
        ),
      );
      final stale = LunchPoll(
        id: 'p1',
        title: 'Old lunch',
        date: local.date,
        status: 'closed',
        options: local.options,
        myVote: LunchMyVote(
          optionId: 'o1',
          votedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      final merged = local.applyServerSnapshot(stale);
      expect(merged.scopedMyVote?.optionId, 'o2');
    });

    test('deriveEmployeeVotes builds rows from poll options', () {
      final poll = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        options: [
          LunchPollOption(
            id: 'o1',
            label: 'Rice',
            optionType: 'office_menu',
            voteCount: 2,
            voters: [
              LunchOptionVoter(name: 'Alice'),
              LunchOptionVoter(name: 'Bob'),
            ],
          ),
        ],
      );
      final votes = LunchOrderSummary.deriveEmployeeVotes(poll);
      expect(votes.length, 2);
      expect(votes.first.userName, 'Alice');
    });
  });
}
