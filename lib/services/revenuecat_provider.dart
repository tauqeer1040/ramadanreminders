import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'revenuecat_service.dart';

enum SubscriptionStatus {
  unknown,
  subscribed,
  notSubscribed,
  loading,
}

class RevenueCatState {
  final SubscriptionStatus status;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final String? error;

  const RevenueCatState({
    this.status = SubscriptionStatus.unknown,
    this.customerInfo,
    this.offerings,
    this.error,
  });

  bool get isPro => status == SubscriptionStatus.subscribed;

  RevenueCatState copyWith({
    SubscriptionStatus? status,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    String? error,
  }) {
    return RevenueCatState(
      status: status ?? this.status,
      customerInfo: customerInfo ?? this.customerInfo,
      offerings: offerings ?? this.offerings,
      error: error,
    );
  }
}

class RevenueCatNotifier extends StateNotifier<RevenueCatState> {
  RevenueCatNotifier() : super(const RevenueCatState()) {
    _init();
  }

  Future<void> _init() async {
    final service = RevenueCatService.instance;
    service.addListener(_onCustomerInfoChanged);

    state = state.copyWith(status: SubscriptionStatus.loading);

    await service.ensureInitialized();

    final info = await service.getCustomerInfo();
    if (info != null) {
      _onCustomerInfoChanged(info);
    }
  }

  void _onCustomerInfoChanged(CustomerInfo info) {
    final isPro = RevenueCatService.instance.hasActiveEntitlement(info);
    state = state.copyWith(
      customerInfo: info,
      status: isPro ? SubscriptionStatus.subscribed : SubscriptionStatus.notSubscribed,
      error: null,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(status: SubscriptionStatus.loading);
    final service = RevenueCatService.instance;
    final info = await service.getCustomerInfo();
    if (info != null) {
      _onCustomerInfoChanged(info);
    } else {
      state = state.copyWith(status: SubscriptionStatus.notSubscribed);
    }
  }

  Future<Offerings?> fetchOfferings() async {
    final service = RevenueCatService.instance;
    final offerings = await service.getOfferings();
    state = state.copyWith(offerings: offerings);
    return offerings;
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final service = RevenueCatService.instance;
      await service.purchasePackage(package);
      await refresh();
      return state.isPro;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final service = RevenueCatService.instance;
      await service.restorePurchases();
      await refresh();
      return state.isPro;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> canMakePayments() async {
    return RevenueCatService.instance.canMakePayments();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    RevenueCatService.instance.removeListener(_onCustomerInfoChanged);
    super.dispose();
  }
}

final revenueCatProvider =
    StateNotifierProvider<RevenueCatNotifier, RevenueCatState>((ref) {
  return RevenueCatNotifier();
});
