class NotificationItem {
  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    required this.isRead,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String message;
  final String? type;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NotificationItem.fromJson(Map<String, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return NotificationItem(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      title: _pickText(json, const ['title', 'subject', 'name']) ?? 'Notification',
      message: _pickText(json, const ['message', 'body', 'content']) ?? '',
      type: _pickText(json, const ['type', 'category']),
      isRead:
          _pickBool(json, const ['isRead', 'is_read', 'read']) ??
          ((json['readAt'] ?? json['read_at']) != null),
      createdAt: _pickDate(json, const ['createdAt', 'created_at', 'date']),
      updatedAt: _pickDate(json, const ['updatedAt', 'updated_at']),
    );
  }

  static String? _pickText(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static bool? _pickBool(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }

  static DateTime? _pickDate(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      final d = DateTime.tryParse(v.toString());
      if (d != null) return d;
    }
    return null;
  }
}
