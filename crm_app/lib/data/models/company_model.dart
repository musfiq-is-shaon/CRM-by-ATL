import 'user_model.dart';
import 'currency_model.dart';

class Company {
  final String id;
  final String name;
  final String? location;
  final String? country;
  final String? kamUserId;
  final User? kamUser;
  final String? currencyId;
  final Currency? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Company({
    required this.id,
    required this.name,
    this.location,
    this.country,
    this.kamUserId,
    this.kamUser,
    this.currencyId,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    final kamRaw = json['kamUser'];
    final currencyRaw = json['currency'];
    return Company(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString(),
      country: json['country']?.toString(),
      kamUserId: json['kamUserId']?.toString() ??
          (kamRaw is Map
              ? (kamRaw['id'] ?? kamRaw['_id'])?.toString()
              : kamRaw?.toString()),
      kamUser: kamRaw is Map
          ? User.fromJson(Map<String, dynamic>.from(kamRaw))
          : null,
      currencyId: json['currencyId']?.toString() ??
          (currencyRaw is Map
              ? (currencyRaw['id'] ?? currencyRaw['_id'])?.toString()
              : currencyRaw?.toString()),
      currency: currencyRaw is Map
          ? Currency.fromJson(Map<String, dynamic>.from(currencyRaw))
          : null,
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
      'name': name,
      'location': location,
      'country': country,
      'kamUserId': kamUserId,
      'currencyId': currencyId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
