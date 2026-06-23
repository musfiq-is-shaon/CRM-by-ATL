import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/currency_model.dart';
import '../../data/repositories/currency_repository.dart';

class CurrenciesState {
  final List<Currency> currencies;
  final bool isLoading;
  final String? error;

  const CurrenciesState({
    this.currencies = const [],
    this.isLoading = false,
    this.error,
  });

  CurrenciesState copyWith({
    List<Currency>? currencies,
    bool? isLoading,
    String? error,
  }) {
    return CurrenciesState(
      currencies: currencies ?? this.currencies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CurrenciesNotifier extends StateNotifier<CurrenciesState> {
  final CurrencyRepository _currencyRepository;

  CurrenciesNotifier(this._currencyRepository) : super(const CurrenciesState());

  Future<void> loadCurrencies({bool forceRefresh = false}) async {
    if (!forceRefresh && state.currencies.isNotEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final currencies = await _currencyRepository.getCurrencies();
      state = state.copyWith(currencies: currencies, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final currenciesProvider =
    StateNotifierProvider<CurrenciesNotifier, CurrenciesState>((ref) {
      final currencyRepository = ref.watch(currencyRepositoryProvider);
      return CurrenciesNotifier(currencyRepository);
    });
