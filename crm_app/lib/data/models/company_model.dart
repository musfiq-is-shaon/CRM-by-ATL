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
    return Company(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      location: json['location'],
      country: json['country'],
      kamUserId: json['kamUserId']?.toString(),
      kamUser: json['kamUser'] != null ? User.fromJson(json['kamUser']) : null,
      currencyId: json['currencyId']?.toString(),
      currency: json['currency'] != null
          ? Currency.fromJson(json['currency'])
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
