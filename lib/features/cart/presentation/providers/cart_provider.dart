import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/cart/data/cart_repository.dart';

final cartRepoProvider = Provider((ref) => CartRepository());

class CartCountNotifier extends StateNotifier<int> {
  CartCountNotifier(this._repo) : super(0) {
    _bootstrap();
  }

  final CartRepository _repo;

  Future<void> _bootstrap() async {
    state = await _fetchCount();
  }

  Future<void> reload() async {
    state = await _fetchCount();
  }

  /// تحديث فوري متفائل (بلا انتظار شبكة) — يجعل البادج يتغيّر في نفس اللحظة،
  /// و[reload] اللاحق يصحّح القيمة من الخادم عند الحاجة.
  void applyDelta(int delta) {
    final next = state + delta;
    state = next < 0 ? 0 : next;
  }

  void set(int value) {
    state = value < 0 ? 0 : value;
  }

  Future<int> _fetchCount() async {
    if (SupabaseService.currentUserId == null) return 0;
    try {
      return await _repo.getCartCount();
    } catch (_) {
      return 0;
    }
  }
}

/// عداد السلة المتزامن (مثل المفضلة) — يتحدّث فوراً بعد الإضافة/الحذف.
final cartCountNotifierProvider =
    StateNotifierProvider<CartCountNotifier, int>(
  (ref) => CartCountNotifier(ref.watch(cartRepoProvider)),
);

final cartItemsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(cartRepoProvider).getCartWithProducts(),
);

/// للتوافق مع الكود القديم — يقرأ من العداد المتزامن.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartCountNotifierProvider),
);

class CartNotifier extends StateNotifier<AsyncValue<void>> {
  CartNotifier(this._repo, this._countNotifier) : super(const AsyncData(null));

  final CartRepository _repo;
  final CartCountNotifier _countNotifier;

  Future<void> add(String productId, {int qty = 1}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.addToCart(productId, qty));
    if (!state.hasError) await _countNotifier.reload();
  }

  Future<void> remove(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.removeFromCart(id));
    if (!state.hasError) await _countNotifier.reload();
  }

  Future<void> clear() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.clearCart());
    if (!state.hasError) await _countNotifier.reload();
  }
}

final cartActionProvider =
    StateNotifierProvider<CartNotifier, AsyncValue<void>>(
  (ref) => CartNotifier(
    ref.watch(cartRepoProvider),
    ref.read(cartCountNotifierProvider.notifier),
  ),
);
