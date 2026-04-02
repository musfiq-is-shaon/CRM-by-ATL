import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/rbac_model.dart';

class RbacRepository {
  RbacRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<RbacMe> fetchMe() async {
    final response = await _api.get(AppConstants.rbacMe);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw FormatException('Invalid RBAC response');
    }
    return RbacMe.fromJson(data);
  }
}

final rbacRepositoryProvider = Provider<RbacRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return RbacRepository(apiClient: api);
});
