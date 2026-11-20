import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/features/favorites/data/favorites_repository.dart';

final favoritesRepoProvider = Provider((ref) => FavoritesRepository());

class FavoriteIdsNotifier extends StateNotifier<Set<String>> {
  FavoriteIdsNotifier(this._repo) : super(const <String>{}) {
    _bootstrap();
  }

  final FavoritesRepository _repo;

  Future<void> _bootstrap() async {
    state = await _repo.getFavoriteIds();
  }

  Future<void> reload() async {
    state = await _repo.getFavoriteIds();
  }

  Future<void> toggle(String productId) async {
    state = await _repo.toggleFavorite(productId);
  }

  Future<void> remove(String productId) async {
    state = await _repo.removeFavorite(productId);
  }
}

final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsNotifier, Set<String>>(
  (ref) => FavoriteIdsNotifier(ref.watch(favoritesRepoProvider)),
);

final favoriteProductsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ids = ref.watch(favoriteIdsProvider).toList();
  if (ids.isEmpty) return const <Map<String, dynamic>>[];
  return ref.watch(favoritesRepoProvider).fetchFavoriteProducts(ids);
});

