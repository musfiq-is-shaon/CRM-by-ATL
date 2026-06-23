import 'company_model.dart';

class Contact {
  final String id;
  final String name;
  final String? companyId;
  final Company? company;
  final String? designation;
  final String? mobile;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Contact({
    required this.id,
    required this.name,
    this.companyId,
    this.company,
    this.designation,
    this.mobile,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      companyId: json['companyId']?.toString(),
      company: json['company'] != null
          ? Company.fromJson(json['company'])
          : null,
      designation: json['designation'],
      mobile: json['mobile'],
      email: json['email'],
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
      'companyId': companyId,
      'designation': designation,
      'mobile': mobile,
      'email': email,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Resolves company name from embedded [company] or a known company list.
  String? companyDisplayName([List<Company>? companies]) {
    final embedded = company?.name.trim();
    if (embedded != null && embedded.isNotEmpty) return embedded;
    final id = companyId;
    if (id == null || id.isEmpty || companies == null) return null;
    for (final c in companies) {
      if (c.id == id) return c.name;
    }
    return null;
  }
}
