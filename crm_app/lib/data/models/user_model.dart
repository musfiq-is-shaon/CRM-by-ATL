import '../../core/json_parse.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? role;
  final bool? isActive;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role,
    this.isActive,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'],
      isActive: parseOptionalBool(json['isActive'] ?? json['is_active']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
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
