import 'package:flutter_test/flutter_test.dart';

import 'package:crm/presentation/pages/lunch/lunch_ui_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lunchEndTimeOfDay / formatLunchEndTimeDisplay', () {
    test('parses 24h HH:mm', () {
      final tod = lunchEndTimeOfDay('13:30');
      expect(tod.hour, 13);
      expect(tod.minute, 30);
    });

    test('parses 12h strings without dropping minutes', () {
      final tod = lunchEndTimeOfDay('6:30 PM');
      expect(tod.hour, 18);
      expect(tod.minute, 30);
      expect(formatLunchEndTimeDisplay('6:30 PM'), isNot(contains('6:00')));
      expect(formatLunchEndTimeDisplay('18:30'), contains('6:30'));
    });

    test('empty end time displays em dash', () {
      expect(formatLunchEndTimeDisplay(null), '—');
      expect(formatLunchEndTimeDisplay(''), '—');
    });
  });

  group('preferPollEndTime', () {
    test('keeps viable prior when incoming is past', () {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 2));
      final past = now.subtract(const Duration(hours: 1));
      final futureApi =
          '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
      final pastApi =
          '${past.hour.toString().padLeft(2, '0')}:${past.minute.toString().padLeft(2, '0')}';

      final picked = preferPollEndTime(
        prior: futureApi,
        incoming: pastApi,
        pollDate: DateTime(now.year, now.month, now.day),
      );
      expect(picked, futureApi);
    });

    test('prefers incoming when both viable', () {
      final now = DateTime.now();
      final a = now.add(const Duration(hours: 1));
      final b = now.add(const Duration(hours: 3));
      final aApi =
          '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';
      final bApi =
          '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';

      final picked = preferPollEndTime(
        prior: aApi,
        incoming: bApi,
        pollDate: DateTime(now.year, now.month, now.day),
      );
      expect(picked, bApi);
    });

    test('falls back when one side is null', () {
      expect(
        preferPollEndTime(prior: null, incoming: '14:00', pollDate: null),
        '14:00',
      );
      expect(
        preferPollEndTime(prior: '14:00', incoming: null, pollDate: null),
        '14:00',
      );
    });
  });

  group('isPollEndTimeViable', () {
    test('future end on today is viable', () {
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 1));
      final api =
          '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
      expect(isPollEndTimeViable(api, now), isTrue);
    });

    test('past end on today is not viable', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1));
      final api =
          '${past.hour.toString().padLeft(2, '0')}:${past.minute.toString().padLeft(2, '0')}';
      expect(isPollEndTimeViable(api, now), isFalse);
    });
  });
}
