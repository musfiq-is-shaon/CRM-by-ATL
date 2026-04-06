// Defensive parsing for loosely typed REST / JSON (Flask, etc.).

bool? parseOptionalBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}

int? parseOptionalInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

num? parseOptionalNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

String _shiftFormat12h(DateTime loc) {
  final h = loc.hour;
  final min = loc.minute;
  final mm = min.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  var h12 = h > 12 ? h - 12 : h;
  if (h12 == 0) h12 = 12;
  return '$h12:$mm $period';
}

/// Normalizes shift times from REST/JSON: `"09:00"`, ISO-8601, Mongo `{"\$date":...}`, epoch ms.
String shiftTimeFromApiValue(dynamic raw) {
  if (raw == null) return '';
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    final d = m[r'$date'] ?? m['date'] ?? m[r'$numberLong'];
    if (d != null) return shiftTimeFromApiValue(d);
    return '';
  }
  if (raw is int && raw.abs() > 1000000000000) {
    return _shiftFormat12h(
      DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true).toLocal(),
    );
  }
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return '';

  final dt = DateTime.tryParse(s);
  if (dt != null) {
    return _shiftFormat12h(dt.toLocal());
  }

  final re = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?');
  final match = re.firstMatch(s);
  if (match != null) {
    final h = int.tryParse(match.group(1)!);
    final min = int.tryParse(match.group(2)!);
    if (h != null && min != null && h >= 0 && h < 24 && min >= 0 && min < 60) {
      return _shiftFormat12h(DateTime(2000, 1, 1, h, min));
    }
  }
  return s;
}
