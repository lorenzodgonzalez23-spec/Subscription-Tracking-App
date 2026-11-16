import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/subscription_repository.dart';
import '../../domain/payment_method_model.dart';
import 'subscription_provider.dart';

final paymentMethodsProvider =
    StateNotifierProvider<
      PaymentMethodsNotifier,
      AsyncValue<List<PaymentMethod>>
    >(
      (ref) =>
          PaymentMethodsNotifier(ref.watch(subscriptionRepositoryProvider)),
    );

class PaymentMethodsNotifier
    extends StateNotifier<AsyncValue<List<PaymentMethod>>> {
  PaymentMethodsNotifier(this.repository) : super(const AsyncLoading()) {
    reload();
  }

  final SubscriptionRepository repository;

  Future<void> reload() async {
    state = await AsyncValue.guard(repository.getPaymentMethods);
  }

  Future<void> save(PaymentMethod method) async {
    await repository.savePaymentMethod(method);
    await reload();
  }
}
