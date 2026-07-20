import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/async_load_helper.dart';
import '../../data/models/company_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/company_repository.dart'
    show CompanyRepository, companyRepositoryProvider;
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/user_repository.dart'
    show UserRepository, userRepositoryProvider;

/// Client-side filters for the orders list (API has no filter params).
class OrderListFilters {
  const OrderListFilters({
    this.status,
    this.assignToUserId,
    this.deliveryFrom,
    this.deliveryTo,
  });

  final String? status;
  final String? assignToUserId;
  final DateTime? deliveryFrom;
  final DateTime? deliveryTo;

  static const empty = OrderListFilters();

  int get activeCount {
    var n = 0;
    if (status != null && status!.trim().isNotEmpty) n++;
    if (assignToUserId != null && assignToUserId!.trim().isNotEmpty) n++;
    if (deliveryFrom != null) n++;
    if (deliveryTo != null) n++;
    return n;
  }
}

class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? listSearch;
  final OrderListFilters listFilters;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.listSearch,
    this.listFilters = OrderListFilters.empty,
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? listSearch,
    bool clearListSearch = false,
    OrderListFilters? listFilters,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      listSearch: clearListSearch ? null : (listSearch ?? this.listSearch),
      listFilters: listFilters ?? this.listFilters,
    );
  }

  /// Orders list API has no `search` param; filter in the UI layer.
  List<Order> get visibleOrders {
    Iterable<Order> rows = orders;

    final q = listSearch?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      rows = rows.where((o) {
        final companyName = (o.company?.name ?? '').toLowerCase();
        final details = o.orderDetails?.toLowerCase() ?? '';
        final status = o.status?.toLowerCase() ?? '';
        return companyName.contains(q) ||
            details.contains(q) ||
            status.contains(q);
      });
    }

    final f = listFilters;
    if (f.status != null && f.status!.trim().isNotEmpty) {
      final st = f.status!.trim();
      rows = rows.where((o) => o.status == st);
    }
    if (f.assignToUserId != null && f.assignToUserId!.trim().isNotEmpty) {
      final id = f.assignToUserId!.trim();
      rows = rows.where((o) => o.assignTo == id);
    }
    if (f.deliveryFrom != null || f.deliveryTo != null) {
      rows = rows.where((o) {
        final d = o.deliveryDate;
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (f.deliveryFrom != null) {
          final from = DateTime(
            f.deliveryFrom!.year,
            f.deliveryFrom!.month,
            f.deliveryFrom!.day,
          );
          if (day.isBefore(from)) return false;
        }
        if (f.deliveryTo != null) {
          final to = DateTime(
            f.deliveryTo!.year,
            f.deliveryTo!.month,
            f.deliveryTo!.day,
          );
          if (day.isAfter(to)) return false;
        }
        return true;
      });
    }

    return rows.toList();
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final OrderRepository _orderRepository;
  final CompanyRepository _companyRepository;
  final UserRepository _userRepository;

  OrdersNotifier(
    this._orderRepository,
    this._companyRepository,
    this._userRepository,
  ) : super(const OrdersState());

  Future<void> loadOrders({bool refresh = false}) async {
    final hadCache = state.orders.isNotEmpty;
    if (!hadCache) {
      state = state.copyWith(isLoading: true, isRefreshing: false, error: null);
    } else if (refresh) {
      state = state.copyWith(isRefreshing: true, error: null);
    } else {
      final flags = beginAsyncLoad(hasCachedData: true);
      state = state.copyWith(
        isLoading: flags.isLoading,
        isRefreshing: flags.isRefreshing,
        error: null,
      );
    }
    try {
      final orders = await _orderRepository.getOrders();

      final companyIds = <String>{};
      final userIds = <String>{};
      for (final o in orders) {
        if (o.companyId != null) companyIds.add(o.companyId!);
        if (o.assignTo != null) userIds.add(o.assignTo!);
        if (o.forwardedTo != null) userIds.add(o.forwardedTo!);
      }

      final companiesFuture = companyIds.isNotEmpty
          ? _companyRepository.getCompaniesByIds(companyIds.toList())
          : Future.value(<String, Company>{});
      final usersFuture = userIds.isNotEmpty
          ? _userRepository.getUsersByIds(userIds.toList())
          : Future.value(<String, User>{});

      final results = await Future.wait([companiesFuture, usersFuture]);
      final companiesMap = results[0] as Map<String, Company>;
      final usersMap = results[1] as Map<String, User>;

      final enriched = orders.map((o) {
        Company? company;
        if (o.companyId != null && companiesMap.containsKey(o.companyId)) {
          company = companiesMap[o.companyId];
        }
        User? assignUser = o.assignToUser;
        if (assignUser == null &&
            o.assignTo != null &&
            usersMap.containsKey(o.assignTo)) {
          assignUser = usersMap[o.assignTo];
        }
        User? fwdUser = o.forwardedToUser;
        if (fwdUser == null &&
            o.forwardedTo != null &&
            usersMap.containsKey(o.forwardedTo)) {
          fwdUser = usersMap[o.forwardedTo];
        }
        return o.copyWith(
          company: company,
          assignToUser: assignUser,
          forwardedToUser: fwdUser,
        );
      }).toList();

      state = state.copyWith(
        orders: List<Order>.from(enriched),
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: asyncLoadError(e),
      );
    }
  }

  void setListSearch(String? search) {
    final trimmed = search?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearListSearch: true);
    } else {
      state = state.copyWith(listSearch: trimmed, clearListSearch: false);
    }
  }

  void setListFilters(OrderListFilters filters) {
    state = state.copyWith(listFilters: filters);
  }

  void clearListFilters() {
    state = state.copyWith(listFilters: OrderListFilters.empty);
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(
    ref.watch(orderRepositoryProvider),
    ref.watch(companyRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});
