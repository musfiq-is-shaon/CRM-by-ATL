/// Org profile from `GET/PUT /api/company-profile` (Postman: Company profile).
class CompanyProfile {
  CompanyProfile({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.city,
    this.country,
    this.industry,
    this.taxId,
    this.description,
    this.logo,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? website;
  final String? address;
  final String? city;
  final String? country;
  final String? industry;
  final String? taxId;
  final String? description;
  /// Base64 data URL or URL string from API.
  final String? logo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CompanyProfile.fromJson(dynamic raw) {
    final json = _unwrap(raw);
    if (json == null) {
      return CompanyProfile();
    }
    return CompanyProfile(
      id: json['id']?.toString(),
      name: _str(json['name']),
      email: _str(json['email']),
      phone: _str(json['phone']),
      website: _str(json['website']),
      address: _str(json['address']),
      city: _str(json['city']),
      country: _str(json['country']),
      industry: _str(json['industry']),
      taxId: _str(json['taxId'] ?? json['tax_id']),
      description: _str(json['description']),
      logo: _str(json['logo']),
      createdAt: _dt(json['createdAt'] ?? json['created_at']),
      updatedAt: _dt(json['updatedAt'] ?? json['updated_at']),
    );
  }

  /// Body for `PUT /api/company-profile` (Postman: all fields optional).
  Map<String, dynamic> toUpdateBody() {
    return {
      'name': name ?? '',
      'email': email ?? '',
      'phone': phone ?? '',
      'website': website ?? '',
      'address': address ?? '',
      'city': city ?? '',
      'country': country ?? '',
      'industry': industry ?? '',
      'taxId': taxId ?? '',
      'description': description ?? '',
      'logo': logo,
    };
  }

  /// Full map including empty strings (for form defaults).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'website': website,
      'address': address,
      'city': city,
      'country': country,
      'industry': industry,
      'taxId': taxId,
      'description': description,
      'logo': logo,
    };
  }

  CompanyProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? city,
    String? country,
    String? industry,
    String? taxId,
    String? description,
    String? logo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      industry: industry ?? this.industry,
      taxId: taxId ?? this.taxId,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Map<String, dynamic>? _unwrap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final inner = m['data'] ?? m['profile'] ?? m['company'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return m;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
