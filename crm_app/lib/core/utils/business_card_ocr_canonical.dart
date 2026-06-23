/// Canonical contact fields extracted from a business card OCR JSON payload.
class CanonicalBusinessCardContact {
  const CanonicalBusinessCardContact({
    this.name,
    this.companyName,
    this.companyLocation,
    this.designation,
    this.mobile,
    this.email,
  });

  final String? name;
  final String? companyName;
  final String? companyLocation;
  final String? designation;
  final String? mobile;
  final String? email;

  bool get hasAnyField =>
      _nonEmpty(name) != null ||
      _nonEmpty(companyName) != null ||
      _nonEmpty(companyLocation) != null ||
      _nonEmpty(designation) != null ||
      _nonEmpty(mobile) != null ||
      _nonEmpty(email) != null;

  Map<String, String?> toFieldMap() => {
        'name': _nonEmpty(name),
        'company': _nonEmpty(companyName),
        'location': _nonEmpty(companyLocation),
        'designation': _nonEmpty(designation),
        'mobile': _nonEmpty(mobile),
        'email': _nonEmpty(email),
      };
}

String? _nonEmpty(String? v) {
  final t = v?.trim();
  if (t == null || t.isEmpty || t.toLowerCase() == 'null') return null;
  return t;
}

String _normKey(String key) =>
    key.toLowerCase().trim().replaceAll(RegExp(r'[\s\-]+'), '_');

const _nameKeys = {
  'name',
  'full_name',
  'fullname',
  'contact_name',
  'person_name',
  'person',
  'contact',
  'client_name',
  'customer_name',
  'applicant_name',
  'your_name',
};

const _companyKeys = {
  'company',
  'company_name',
  'organization',
  'organisation',
  'org',
  'employer',
  'business',
  'business_name',
  'firm',
  'office',
  'workplace',
};

const _locationKeys = {
  'location',
  'company_location',
  'office_location',
  'address',
  'company_address',
  'office_address',
  'street_address',
  'street',
  'city',
  'head_office',
  'headquarters',
  'hq',
};

const _designationKeys = {
  'designation',
  'title',
  'job_title',
  'jobtitle',
  'position',
  'role',
  'department_title',
  'profession',
};

const _mobileKeys = {
  'mobile',
  'phone',
  'telephone',
  'tel',
  'cell',
  'phone_number',
  'mobile_number',
  'contact_number',
  'contact_phone',
  'work_phone',
  'office_phone',
  'primary_phone',
  'phone_no',
  'mobile_no',
};

const _emailKeys = {
  'email',
  'e_mail',
  'email_address',
  'mail',
  'work_email',
  'office_email',
  'contact_email',
};

final _emailRegex = RegExp(
  r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
  caseSensitive: false,
);

final _phoneRegex = RegExp(
  r'(\+?\d[\d\s().\-]{6,}\d)',
);

/// Maps DocStrange `result.json.content` or legacy OCR JSON to CRM contact fields.
CanonicalBusinessCardContact canonicalizeBusinessCardOcr(
  Map<String, dynamic> raw,
) {
  // Fast path: DocStrange field-list / schema keys at top level.
  final direct = _fromDocStrangeContent(raw);
  if (direct.hasAnyField) return direct;

  final roots = _ocrSearchRoots(raw);
  final flat = <String, String>{};
  for (final root in roots) {
    _flattenOcrMap(root, flat);
  }

  var name = _pickByKeys(flat, _nameKeys);
  var company = _pickByKeys(flat, _companyKeys);
  var location = _pickByKeys(flat, _locationKeys);
  var designation = _pickByKeys(flat, _designationKeys);
  var mobile = _normalizePhone(_pickByKeys(flat, _mobileKeys));
  var email = _normalizeEmail(_pickByKeys(flat, _emailKeys));

  // Nested section shapes (contact_information, personal_information, …)
  for (final root in roots) {
    for (final sectionKey in [
      'contact_information',
      'contact_info',
      'personal_information',
      'business_card',
      'card',
      'details',
    ]) {
      final section = root[sectionKey];
      if (section is! Map) continue;
      final sm = Map<String, dynamic>.from(section);
      final sectionFlat = <String, String>{};
      _flattenOcrMap(sm, sectionFlat);
      name ??= _pickByKeys(sectionFlat, _nameKeys);
      company ??= _pickByKeys(sectionFlat, _companyKeys);
      location ??= _pickByKeys(sectionFlat, _locationKeys);
      designation ??= _pickByKeys(sectionFlat, _designationKeys);
      mobile ??= _normalizePhone(_pickByKeys(sectionFlat, _mobileKeys));
      email ??= _normalizeEmail(_pickByKeys(sectionFlat, _emailKeys));
    }
  }

  // Regex fallback over all string values
  if (email == null) {
    for (final v in flat.values) {
      final m = _emailRegex.firstMatch(v);
      if (m != null) {
        email = m.group(0);
        break;
      }
    }
  }
  if (mobile == null) {
    for (final entry in flat.entries) {
      if (_emailKeys.contains(_normKey(entry.key))) continue;
      final m = _phoneRegex.firstMatch(entry.value);
      if (m != null) {
        mobile = _normalizePhone(m.group(0));
        if (mobile != null) break;
      }
    }
  }

  // If name still missing, pick longest plausible person-like string
  name ??= _inferName(flat, company, email, mobile);

  return CanonicalBusinessCardContact(
    name: name,
    companyName: company,
    companyLocation: location,
    designation: designation,
    mobile: mobile,
    email: email,
  );
}

List<Map<String, dynamic>> _ocrSearchRoots(Map<String, dynamic> raw) {
  final roots = <Map<String, dynamic>>[raw];
  for (final key in [
    'result',
    'data',
    'json',
    'extracted_data',
    'extractedData',
    'output',
    'content',
  ]) {
    final v = raw[key];
    if (v is Map) roots.add(Map<String, dynamic>.from(v));
    if (key == 'result' && v is Map) {
      final jsonNode = v['json'];
      if (jsonNode is Map) {
        final content = jsonNode['content'];
        if (content is Map) roots.add(Map<String, dynamic>.from(content));
      }
    }
  }
  return roots;
}

void _flattenOcrMap(Map<String, dynamic> map, Map<String, String> out) {
  for (final entry in map.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    if (value == null) continue;
    if (value is String) {
      final t = value.trim();
      if (t.isNotEmpty) out.putIfAbsent(_normKey(key), () => t);
    } else if (value is num) {
      out.putIfAbsent(_normKey(key), () => value.toString());
    } else if (value is Map) {
      _flattenOcrMap(Map<String, dynamic>.from(value), out);
    }
  }
}

String? _pickByKeys(Map<String, String> flat, Set<String> keys) {
  for (final entry in flat.entries) {
    if (keys.contains(entry.key)) {
      return _nonEmpty(entry.value);
    }
  }
  for (final entry in flat.entries) {
    for (final k in keys) {
      if (entry.key.contains(k)) {
        return _nonEmpty(entry.value);
      }
    }
  }
  return null;
}

String? _normalizeEmail(String? raw) {
  final t = _nonEmpty(raw);
  if (t == null) return null;
  final m = _emailRegex.firstMatch(t);
  return m?.group(0)?.toLowerCase();
}

String? _normalizePhone(String? raw) {
  final t = _nonEmpty(raw);
  if (t == null) return null;
  final digits = t.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.replaceAll('+', '').length < 7) return null;
  return digits.startsWith('+') ? digits : digits;
}

String? _inferName(
  Map<String, String> flat,
  String? company,
  String? email,
  String? mobile,
) {
  final skipValues = {
    company?.toLowerCase(),
    email?.toLowerCase(),
    mobile,
  }.whereType<String>().toSet();

  String? best;
  var bestScore = 0;
  for (final entry in flat.entries) {
    if (_companyKeys.contains(entry.key) ||
        _locationKeys.contains(entry.key) ||
        _mobileKeys.contains(entry.key) ||
        _emailKeys.contains(entry.key) ||
        _designationKeys.contains(entry.key)) {
      continue;
    }
    final v = entry.value.trim();
    if (v.length < 3 || v.length > 60) continue;
    if (skipValues.contains(v.toLowerCase())) continue;
    if (_emailRegex.hasMatch(v)) continue;
    if (_phoneRegex.hasMatch(v) && v.replaceAll(RegExp(r'\D'), '').length >= 7) {
      continue;
    }
    var score = v.length;
    if (entry.key.contains('name')) score += 20;
    if (v.contains(' ') && !v.contains('@')) score += 10;
    if (score > bestScore) {
      bestScore = score;
      best = v;
    }
  }
  return best;
}

/// Direct mapping from DocStrange `result.json.content` (official response shape).
CanonicalBusinessCardContact _fromDocStrangeContent(Map<String, dynamic> content) {
  return CanonicalBusinessCardContact(
    name: _nonEmpty(content['name']?.toString()),
    companyName: _nonEmpty(content['company']?.toString()) ??
        _nonEmpty(content['company_name']?.toString()),
    companyLocation: _nonEmpty(content['location']?.toString()) ??
        _nonEmpty(content['company_location']?.toString()) ??
        _nonEmpty(content['address']?.toString()) ??
        _nonEmpty(content['company_address']?.toString()),
    designation: _nonEmpty(content['designation']?.toString()) ??
        _nonEmpty(content['title']?.toString()) ??
        _nonEmpty(content['job_title']?.toString()),
    mobile: _normalizePhone(
      content['mobile']?.toString() ?? content['phone']?.toString(),
    ),
    email: _normalizeEmail(content['email']?.toString()),
  );
}

/// Combines OCR from the front and back of the same card. [primary] wins when
/// both sides extracted the same field.
CanonicalBusinessCardContact mergeBusinessCardContacts(
  CanonicalBusinessCardContact primary,
  CanonicalBusinessCardContact secondary,
) {
  return CanonicalBusinessCardContact(
    name: _nonEmpty(primary.name) ?? _nonEmpty(secondary.name),
    companyName:
        _nonEmpty(primary.companyName) ?? _nonEmpty(secondary.companyName),
    companyLocation: _nonEmpty(primary.companyLocation) ??
        _nonEmpty(secondary.companyLocation),
    designation:
        _nonEmpty(primary.designation) ?? _nonEmpty(secondary.designation),
    mobile: _nonEmpty(primary.mobile) ?? _nonEmpty(secondary.mobile),
    email: _nonEmpty(primary.email) ?? _nonEmpty(secondary.email),
  );
}

/// Merges OCR from multiple card pages (front, back, extra sides).
CanonicalBusinessCardContact mergeBusinessCardPages(
  List<CanonicalBusinessCardContact> pages,
) {
  if (pages.isEmpty) return const CanonicalBusinessCardContact();
  var merged = pages.first;
  for (var i = 1; i < pages.length; i++) {
    merged = mergeBusinessCardContacts(merged, pages[i]);
  }
  return merged;
}

/// Match OCR company name to an existing CRM company id (exact then contains).
String? matchCompanyIdByName(List<({String id, String name})> companies, String? companyName) {
  final target = _nonEmpty(companyName);
  if (target == null) return null;
  final norm = target.toLowerCase();

  for (final c in companies) {
    if (c.name.trim().toLowerCase() == norm) return c.id;
  }
  for (final c in companies) {
    final cn = c.name.trim().toLowerCase();
    if (cn.contains(norm) || norm.contains(cn)) return c.id;
  }
  return null;
}
