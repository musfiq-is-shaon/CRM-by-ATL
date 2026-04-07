import '../../core/json_parse.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? role;
  final bool? isActive;
  final DateTime? createdAt;
  /// HR shift template id from `GET /api/users/me` (or login payload) when present.
  final String? shiftId;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role,
    this.isActive,
    this.createdAt,
    this.shiftId,
  });

  /// Plain string, Mongo extended JSON `{ "\$oid": "..." }`, or nested id maps.
  static String? _idLikeToString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty && s != 'null') return s;
      return null;
    }
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final o = m[r'$oid'] ?? m['oid'];
      if (o != null) {
        final s = o.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return _idLikeToString(m['id'] ?? m['_id']);
    }
    return null;
  }

  static String? _parseShiftId(Map<String, dynamic> json) {
    for (final k in [
      'shiftId',
      'shift_id',
      'assignedShiftId',
      'assigned_shift_id',
      'currentShiftId',
      'current_shift_id',
      'defaultShiftId',
      'default_shift_id',
      'shiftAssignmentId',
      'shift_assignment_id',
      'selectedShiftId',
      'selected_shift_id',
    ]) {
      final v = json[k];
      if (v == null) continue;
      final s = _idLikeToString(v);
      if (s != null && s.isNotEmpty) return s;
    }
    for (final key in [
      'shift',
      'assignedShift',
      'assigned_shift',
      'workShift',
      'work_shift',
    ]) {
      final v = json[key];
      if (v is String || v is Map) {
        final s = _idLikeToString(v);
        if (s != null && s.isNotEmpty) return s;
      }
    }
    return null;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _idLikeToString(json['id'] ?? json['_id']) ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'],
      isActive: parseOptionalBool(json['isActive'] ?? json['is_active']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      shiftId: _parseShiftId(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'shiftId': shiftId,
    };
  }

  bool get isAdmin => role == 'admin';
}

class AuthResponse {
  final User user;
  final String token;
  final String? expiresAt;

  AuthResponse({required this.user, required this.token, this.expiresAt});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] ?? {}),
      token: json['token'] ?? '',
      expiresAt: json['expiresAt'],
    );
  }
}
