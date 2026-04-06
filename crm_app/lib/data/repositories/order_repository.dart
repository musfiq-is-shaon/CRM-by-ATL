import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../models/order_model.dart';

class OrderRepository {
  final ApiClient _apiClient;

  OrderRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Flask/API may return `{ "data": {...} }`, `{ "order": {...} }`, or the row at root.
  static dynamic _unwrap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      if (m['data'] != null) return _unwrap(m['data']);
      if (m['order'] != null) return _unwrap(m['order']);
      if (m['item'] != null) return _unwrap(m['item']);
      if (m['result'] != null) return _unwrap(m['result']);
    }
    return raw;
  }

  static Map<String, dynamic> _asOrderMap(dynamic raw) {
    final u = _unwrap(raw);
    if (u is! Map) {
      throw FormatException('Expected order object, got $u');
    }
    return Map<String, dynamic>.from(u);
  }

  static List<dynamic> _asList(dynamic raw) {
    final u = _unwrap(raw);
    if (u is List) return u;
    return [];
  }

  Future<List<Order>> getOrders({
    String? companyId,
    String? salesId,
    String? assignToUserId,
    String? assignTo,
    String? status,
    String? nextAction,
    String? deliveryDateFrom,
    String? deliveryDateTo,
    String? nextActionDateFrom,
    String? nextActionDateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (companyId != null && companyId.isNotEmpty) {
      queryParams['companyId'] = companyId;
    }
    if (salesId != null && salesId.isNotEmpty) queryParams['salesId'] = salesId;
    if (assignToUserId != null && assignToUserId.isNotEmpty) {
      queryParams['assignToUserId'] = assignToUserId;
    }
    if (assignTo != null && assignTo.isNotEmpty) queryParams['assignTo'] = assignTo;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (nextAction != null && nextAction.isNotEmpty) {
      queryParams['nextAction'] = nextAction;
    }
    if (deliveryDateFrom != null && deliveryDateFrom.isNotEmpty) {
      queryParams['deliveryDateFrom'] = deliveryDateFrom;
    }
    if (deliveryDateTo != null && deliveryDateTo.isNotEmpty) {
      queryParams['deliveryDateTo'] = deliveryDateTo;
    }
    if (nextActionDateFrom != null && nextActionDateFrom.isNotEmpty) {
      queryParams['nextActionDateFrom'] = nextActionDateFrom;
    }
    if (nextActionDateTo != null && nextActionDateTo.isNotEmpty) {
      queryParams['nextActionDateTo'] = nextActionDateTo;
    }

    final response = await _apiClient.get(
      AppConstants.orders,
      queryParameters: queryParams,
    );
    final data = _asList(response.data);
    return data
        .map((json) => Order.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  /// Loads one order. Tries `GET /api/orders/:id` first; many backends only
  /// expose list + patch (see Postman), in which case we fall back to
  /// [getOrders] and find the row by id.
  Future<Order> getOrderById(String id) async {
    try {
      final response = await _apiClient.get('${AppConstants.orders}/$id');
      return Order.fromJson(_asOrderMap(response.data));
    } on NotFoundException {
      return _findOrderInListOrThrow(id);
    } on AppException catch (e) {
      // 403: some deployments block GET-by-id but allow list for the same user.
      if (e.statusCode == 405 || e.statusCode == 404 || e.statusCode == 403) {
        return _findOrderInListOrThrow(id);
      }
      rethrow;
    } on FormatException {
      return _findOrderInListOrThrow(id);
    }
  }

  Future<Order> _findOrderInListOrThrow(String id) async {
    final list = await getOrders();
    for (final o in list) {
      if (o.id == id) return o;
    }
    throw NotFoundException(
      message: 'Order not found',
      statusCode: 404,
    );
  }

  Future<Order> createOrder({
    required String companyId,
    String? salesId,
    required String orderDetails,
    double? revenue,
    DateTime? orderConfirmationDate,
    DateTime? deliveryDate,
    String? assignTo,
    bool finalizeCloseWon = false,
    String? closedWonStatus,
    String? statusChangeNote,
    String? changedByUserId,
  }) async {
    final body = <String, dynamic>{
      'companyId': companyId,
      'salesId': salesId,
      'orderDetails': orderDetails,
      'revenue': revenue,
      'orderConfirmationDate':
          orderConfirmationDate?.toIso8601String().split('T')[0],
      'deliveryDate': deliveryDate?.toIso8601String().split('T')[0],
      'assignTo': assignTo,
      'attachments': <dynamic>[],
      'finalizeCloseWon': finalizeCloseWon,
      'closedWonStatus': closedWonStatus,
      'statusChangeNote': statusChangeNote,
      'changedByUserId': changedByUserId,
    };
    body.removeWhere((k, v) => v == null);

    final response = await _apiClient.post(
      AppConstants.orders,
      data: body,
    );
    return Order.fromJson(_asOrderMap(response.data));
  }

  Future<Order> patchOrder({
    required String id,
    String? status,
    String? nextAction,
    DateTime? nextActionDate,
    String? forwardedTo,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'nextAction': nextAction,
      'nextActionDate': nextActionDate?.toIso8601String().split('T')[0],
      'forwardedTo': forwardedTo,
    };
    data.removeWhere((k, v) => v == null);

    final response = await _apiClient.patch(
      '${AppConstants.orders}/$id',
      data: data,
    );
    return Order.fromJson(_asOrderMap(response.data));
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderRepository(apiClient: apiClient);
});
