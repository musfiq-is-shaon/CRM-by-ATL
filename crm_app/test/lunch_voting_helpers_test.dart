import 'package:flutter_test/flutter_test.dart';

import 'package:crm/data/models/lunch_model.dart';

void main() {
  group('LunchPoll voting helpers', () {
    LunchPoll base({
      String status = 'active',
      String? endTime,
      LunchMyVote? myVote,
    }) {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 2));
      final api = endTime ??
          '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
      return LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: DateTime(now.year, now.month, now.day),
        status: status,
        endTime: api,
        myVote: myVote,
        options: [
          LunchPollOption(id: 'o1', label: 'A', optionType: 'office', voteCount: 1),
          LunchPollOption(id: 'o2', label: 'B', optionType: 'personal', voteCount: 0),
        ],
      );
    }

    test('hasSameOptionCounts detects matching totals', () {
      final a = base();
      final b = base().withMyVote('o2');
      expect(a.hasSameOptionCounts(a), isTrue);
      expect(a.hasSameOptionCounts(b), isFalse);
    });

    test('restoreMyVote same option restores votedAt', () {
      final priorAt = DateTime(2026, 3, 1, 10);
      final poll = base(
        myVote: LunchMyVote(optionId: 'o1', votedAt: DateTime(2026, 3, 1, 12)),
      );
      final restored = poll.restoreMyVote(
        LunchMyVote(optionId: 'o1', votedAt: priorAt),
      );
      expect(restored.myVote?.votedAt, priorAt);
      expect(restored.mergedOptions.first.voteCount, 1);
    });

    test('applyServerSnapshot trusts non-empty fresh endTime', () {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 2));
      final past = now.subtract(const Duration(hours: 1));
      final futureApi =
          '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
      final pastApi =
          '${past.hour.toString().padLeft(2, '0')}:${past.minute.toString().padLeft(2, '0')}';
      final local = base(endTime: futureApi);
      final fresh = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: local.date,
        status: 'active',
        endTime: pastApi,
        options: local.options,
      );
      expect(local.applyServerSnapshot(fresh).endTime, pastApi);
    });

    test('mergeAfterVote forces server closed status', () {
      final local = base(status: 'active');
      final server = LunchPoll(
        id: 'p1',
        title: 'Lunch',
        date: local.date,
        status: 'closed',
        endTime: local.endTime,
        myVote: LunchMyVote(optionId: 'o1'),
        options: local.options,
      );
      final merged = LunchPoll.mergeAfterVote(local: local, server: server);
      expect(merged.status, 'closed');
    });
  });
}
