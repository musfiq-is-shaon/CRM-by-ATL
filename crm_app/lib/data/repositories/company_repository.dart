import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/company_model.dart';

class CompanyRepository {
  final ApiClient _apiClient;

  // In-memory cache for companies
  final Map<String, Company> _companyCache = {};
  List<Company>? _cachedCompanies;

  CompanyRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Company>> getCompanies({
    String? search,
    String? country,
    String? kamUserId,
    bool forceRefresh = false,
  }) async {
    // Return cached companies if available and not forcing refresh
    if (!forceRefresh && _cachedCompanies != null) {
      return _cachedCompanies!;
    }

    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (country != null && country.isNotEmpty) queryParams['country'] = country;
    if (kamUserId != null && kamUserId.isNotEmpty) {
      queryParams['kamUserId'] = kamUserId;
    }

    final response = await _apiClient.get(
      AppConstants.companies,
      queryParameters: queryParams,
    );
    final List<dynamic> data = response.data;
    final companies = data.map((json) => Company.fromJson(json)).toList();

    // Cache all companies
    _cachedCompanies = companies;
    for (var company in companies) {
      _companyCache[company.id] = company;
    }

    return companies;
  }

  Future<Company?> getCompanyById(String id, {bool useCache = true}) async {
    // Return cached company if available
    if (useCache && _companyCache.containsKey(id)) {
      return _companyCache[id];
    }

    final response = await _apiClient.get('${AppConstants.companies}/$id');
    final company = Company.fromJson(response.data);
    _companyCache[company.id] = company;
    return company;
  }

  /// Batch fetch multiple companies by IDs - much more efficient than individual calls
  Future<Map<String, Company>> getCompaniesByIds(List<String> ids) async {
    final result = <String, Company>{};
    final idsToFetch = <String>[];

    // Check cache first
    for (var id in ids) {
      if (_companyCache.containsKey(id)) {
        result[id] = _companyCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }

    // If all are cached, return early
    if (idsToFetch.isEmpty) {
      return result;
    }

    // Fetch all companies and filter (or could be optimized with batch API)
    try {
      final allCompanies = await getCompanies();
      for (var company in allCompanies) {
        if (idsToFetch.contains(company.id)) {
          result[company.id] = company;
        }
      }
    } catch (e) {
      // If batch fetch fails, individual fetches will be attempted by callers
    }

    return result;
  }

  /// Clear cache - call after login or when data changes
  void clearCache() {
    _companyCache.clear();
    _cachedCompanies = null;
  }

  Future<Company> createCompany({
    required String name,
    String? location,
    String? country,
    required String kamUserId,
    required String currencyId,
    String? createdByUserId,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'location': location?.trim() ?? '',
      'country': country?.trim() ?? '',
      'kamUserId': kamUserId,
      'currencyId': currencyId,
      if (createdByUserId != null && createdByUserId.isNotEmpty)
        'createdByUserId': createdByUserId,
    };
    final response = await _apiClient.post(
      AppConstants.companies,
      data: data,
    );
    var company = Company.fromJson(_unwrapCompanyJson(response.data));
    if (company.name.trim().isEmpty) {
      company = Company(
        id: company.id,
        name: name.trim(),
        location: company.location ?? location?.trim(),
        country: company.country ?? country?.trim(),
        kamUserId: company.kamUserId ?? kamUserId,
        currencyId: company.currencyId ?? currencyId,
        createdAt: company.createdAt,
        updatedAt: company.updatedAt,
      );
    }

    if (company.id.isEmpty) {
      final resolved = await _findCompanyByName(company.name);
      if (resolved != null) company = resolved;
    }

    if (company.id.isEmpty) {
      throw Exception(
        'Company was saved but the server did not return an id. '
        'Pull to refresh the company list and try again.',
      );
    }

    _companyCache[company.id] = company;
    _cachedCompanies = [
      company,
      ...?(_cachedCompanies?.where((c) => c.id != company.id)),
    ];
    return company;
  }

  Future<Company?> _findCompanyByName(String name) async {
    final norm = name.trim().toLowerCase();
    if (norm.isEmpty) return null;

    final companies = await getCompanies(forceRefresh: true);
    for (final company in companies) {
      if (company.name.trim().toLowerCase() == norm) return company;
    }
    return null;
  }

  Future<Company> updateCompany({
    required String id,
    String? name,
    String? location,
    String? country,
    String? kamUserId,
  }) async {
    final response = await _apiClient.put(
      '${AppConstants.companies}/$id',
      data: {
        'name': name,
        'location': location,
        'country': country,
        'kamUserId': kamUserId,
      },
    );
    return Company.fromJson(response.data);
  }

  Future<void> deleteCompany(String id) async {
    await _apiClient.delete('${AppConstants.companies}/$id');
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CompanyRepository(apiClient: apiClient);
});

Map<String, dynamic> _unwrapCompanyJson(dynamic data) {
  if (data is! Map) return {};
  var current = Map<String, dynamic>.from(data);

  for (var depth = 0; depth < 4; depth++) {
    if (current.containsKey('id') || current.containsKey('_id')) {
      return current;
    }

    Map<String, dynamic>? nested;
    for (final key in ['company', 'data', 'result', 'item']) {
      final inner = current[key];
      if (inner is Map) {
        nested = Map<String, dynamic>.from(inner);
        break;
      }
    }
    if (nested == null) return current;
    current = nested;
  }

  return current;
}
