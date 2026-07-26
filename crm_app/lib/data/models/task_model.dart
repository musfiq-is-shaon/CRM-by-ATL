import 'company_model.dart';
import 'user_model.dart';

class Task {
  final String id;
  final String title;
  final String? note;
  final String? companyId;
  final Company? company;
  final DateTime? dueDatetime;
  final String? assignByUserId;
  final User? assignByUser;
  final String? assignToUserId;
  final User? assignToUser;
  final String status;
  final String? actorUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Task({
    required this.id,
    required this.title,
    this.note,
    this.companyId,
    this.company,
    this.dueDatetime,
    this.assignByUserId,
    this.assignByUser,
    this.assignToUserId,
    this.assignToUser,
    required this.status,
    this.actorUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note']?.toString(),
      companyId: json['companyId']?.toString() ??
          (json['company'] is Map
              ? (json['company']['id'] ?? json['company']['_id'])?.toString()
              : json['company']?.toString()),
      company: json['company'] is Map
          ? Company.fromJson(Map<String, dynamic>.from(json['company'] as Map))
          : null,
      dueDatetime: json['dueDatetime'] != null
          ? DateTime.tryParse(json['dueDatetime'].toString())
          : null,
      assignByUserId: json['assignByUserId']?.toString() ??
          (json['assignByUser'] is Map
              ? (json['assignByUser']['id'] ?? json['assignByUser']['_id'])
                  ?.toString()
              : json['assignByUser']?.toString()),
      assignByUser: json['assignByUser'] is Map
          ? User.fromJson(
              Map<String, dynamic>.from(json['assignByUser'] as Map),
            )
          : null,
      assignToUserId: json['assignToUserId']?.toString() ??
          (json['assignToUser'] is Map
              ? (json['assignToUser']['id'] ?? json['assignToUser']['_id'])
                  ?.toString()
              : json['assignToUser']?.toString()),
      assignToUser: json['assignToUser'] is Map
          ? User.fromJson(
              Map<String, dynamic>.from(json['assignToUser'] as Map),
            )
          : null,
      status: json['status']?.toString() ?? 'pending',
      actorUserId: json['actorUserId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'companyId': companyId,
      'dueDatetime': dueDatetime?.toIso8601String(),
      'assignByUserId': assignByUserId,
      'assignToUserId': assignToUserId,
      'status': status,
      'actorUserId': actorUserId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isOverdue {
    if (dueDatetime == null) return false;
    return DateTime.now().isAfter(dueDatetime!) && !isCompleted;
  }
}

class TaskLog {
  final String id;
  final String taskId;
  final String? note;
  /// New status after this event (when applicable).
  final String? status;
  /// Previous status when the API sends it; otherwise UI can infer from ordered logs.
  final String? previousStatus;
  final String? actorUserId;
  final User? actorUser;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Original index in the GET /logs JSON array (stable sort when timestamps tie).
  final int? sourceIndex;

  TaskLog({
    required this.id,
    required this.taskId,
    this.note,
    this.status,
    this.previousStatus,
    this.actorUserId,
    this.actorUser,
    this.createdAt,
    this.updatedAt,
    this.sourceIndex,
  });

  factory TaskLog.fromJson(Map<String, dynamic> json) {
    User? parseUser(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        return User.fromJson(Map<String, dynamic>.from(v));
      }
      return null;
    }

    const pipelineStatuses = {
      'pending',
      'in_progress',
      'completed',
      'cancelled',
    };

    String? normalizePipelineStatus(String? raw) {
      if (raw == null) return null;
      final s = raw.trim().toLowerCase().replaceAll(' ', '_');
      if (s.isEmpty) return null;
      if (pipelineStatuses.contains(s)) return s;
      return null;
    }

    /// Scalar or common `{ "code": "completed" }` shapes from APIs.
    String? statusScalar(dynamic v) {
      if (v == null) return null;
      if (v is String || v is num || v is bool) {
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }
      if (v is Map) {
        final m = Map<String, dynamic>.from(v);
        for (final k in [
          'code',
          'value',
          'key',
          'name',
          'slug',
          'id',
          'status',
          'state',
        ]) {
          final inner = statusScalar(m[k]);
          if (inner != null) return inner;
        }
      }
      return null;
    }

    Map<String, dynamic>? asJsonMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    String? pickFromMap(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final s = statusScalar(m[k]);
        if (s != null) return s;
      }
      return null;
    }

    const fromKeys = [
      'previousStatus',
      'fromStatus',
      'oldStatus',
      'previous_status',
      'from_status',
      'old_status',
      'beforeStatus',
      'before_status',
      'statusFrom',
      'status_from',
      'from',
      'old',
      'previous',
      'previousState',
      'old_value',
      'oldValue',
    ];
    const toKeys = [
      'status',
      'newStatus',
      'toStatus',
      'new_status',
      'to_status',
      'afterStatus',
      'after_status',
      'statusTo',
      'status_to',
      'to',
      'new',
      'next',
      'nextStatus',
      'newState',
      'new_state',
      'new_value',
      'newValue',
    ];

    var prev = pickFromMap(json, fromKeys);
    var next = pickFromMap(json, toKeys);

    for (final nest in [
      'payload',
      'metadata',
      'meta',
      'changes',
      'change',
      'details',
      'data',
      'body',
    ]) {
      final m = asJsonMap(json[nest]);
      if (m == null) continue;
      prev ??= pickFromMap(m, fromKeys);
      next ??= pickFromMap(m, toKeys);
    }

    final noteText = json['note']?.toString();
    final nTrim = noteText?.trim();
    if (nTrim != null && nTrim.isNotEmpty) {
      final m1 = RegExp(
        r'from\s+([a-z0-9_]+)\s+to\s+([a-z0-9_]+)',
        caseSensitive: false,
      ).firstMatch(nTrim);
      if (m1 != null) {
        final a = normalizePipelineStatus(m1.group(1));
        final b = normalizePipelineStatus(m1.group(2));
        if (a != null && b != null) {
          prev ??= a;
          next ??= b;
        }
      } else {
        final m2 = RegExp(
          r'([a-z0-9_]+)\s*(?:\u2192|->)\s*([a-z0-9_]+)',
          caseSensitive: false,
        ).firstMatch(nTrim);
        if (m2 != null) {
          final a = normalizePipelineStatus(m2.group(1));
          final b = normalizePipelineStatus(m2.group(2));
          if (a != null && b != null) {
            prev ??= a;
            next ??= b;
          }
        }
      }
    }

    int? sourceIndex;
    final si = json['_sourceIndex'];
    if (si is int) {
      sourceIndex = si;
    } else if (si != null) {
      sourceIndex = int.tryParse(si.toString());
    }

    final updatedAt = json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString())
        : (json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null);

    return TaskLog(
      id: json['id']?.toString() ?? '',
      taskId:
          json['taskId']?.toString() ?? json['task_id']?.toString() ?? '',
      note: noteText,
      status: next,
      previousStatus: prev,
      actorUserId: json['actorUserId']?.toString() ??
          json['changedByUserId']?.toString() ??
          json['actor_user_id']?.toString(),
      actorUser: parseUser(json['actorUser']) ?? parseUser(json['changedByUser']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null),
      updatedAt: updatedAt,
      sourceIndex: sourceIndex,
    );
  }

  TaskLog copyWith({
    User? actorUser,
    String? actorUserId,
    bool clearActorUser = false,
  }) {
    return TaskLog(
      id: id,
      taskId: taskId,
      note: note,
      status: status,
      previousStatus: previousStatus,
      actorUserId: actorUserId ?? this.actorUserId,
      actorUser: clearActorUser ? null : (actorUser ?? this.actorUser),
      createdAt: createdAt,
      updatedAt: updatedAt,
      sourceIndex: sourceIndex,
    );
  }
}

/// Human-readable task pipeline status for activity lines.
String taskStatusLogLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'in_progress':
      return 'In progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      if (status.isEmpty) return '—';
      final t = status.replaceAll('_', ' ');
      if (t.isEmpty) return '—';
      return t[0].toUpperCase() + t.substring(1);
  }
}
