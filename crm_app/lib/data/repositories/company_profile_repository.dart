import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/company_profile_model.dart';

class CompanyProfileRepository {
  CompanyProfileRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<CompanyProfile> getCompanyProfile() async {
    final response = await _api.get(AppConstants.companyProfile);
    return CompanyProfile.fromJson(response.data);
  }

  /// Admin only — see Postman "Update company profile (admin)".
  Future<CompanyProfile> updateCompanyProfile(CompanyProfile profile) async {
    final response = await _api.put(
      AppConstants.companyProfile,
      data: profile.toUpdateBody(),
    );
    return CompanyProfile.fromJson(response.data);
  }
}

final companyProfileRepositoryProvider =
    Provider<CompanyProfileRepository>((ref) {
  return CompanyProfileRepository(apiClient: ref.watch(apiClientProvider));
});
