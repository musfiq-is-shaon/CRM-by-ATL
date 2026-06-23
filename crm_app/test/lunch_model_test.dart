import 'package:flutter_test/flutter_test.dart';
import 'package:crm/data/models/lunch_model.dart';

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
