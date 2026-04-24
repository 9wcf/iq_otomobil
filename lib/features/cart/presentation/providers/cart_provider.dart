import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/features/cart/data/cart_repository.dart';

final cartRepoProvider = Provider((ref) => CartRepository());

final cartItemsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(cartRepoProvider).getCartWithProducts());
final cartCountProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(cartRepoProvider).getCartCount());

class CartNotifier extends StateNotifier<AsyncValue<void>> {
  final CartRepository _repo;
  CartNotifier(this._repo) : super(const AsyncData(null));

  Future<void> add(String productId, {int qty = 1}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.addToCart(productId, qty));
  }

  Future<void> remove(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.removeFromCart(id));
  }

  Future<void> clear() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.clearCart());
  }
}

final cartActionProvider =
    StateNotifierProvider<CartNotifier, AsyncValue<void>>(
        (ref) => CartNotifier(ref.watch(cartRepoProvider)));
