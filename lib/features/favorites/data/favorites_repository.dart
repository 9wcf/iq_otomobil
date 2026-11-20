import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesRepository {
  String get _storageKey {
    final uid = SupabaseService.currentUserId;
    return 'favorite_product_ids_${uid ?? 'guest'}';
  }

  Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<Set<String>> toggleFavorite(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return getFavoriteIds();
    final current = await getFavoriteIds();
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await _saveIds(current);
    return current;
  }

  Future<Set<String>> removeFavorite(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return getFavoriteIds();
    final current = await getFavoriteIds();
    current.remove(id);
    await _saveIds(current);
    return current;
  }

  Future<List<Map<String, dynamic>>> fetchFavoriteProducts(
      List<String> ids) async {
    final cleanIds =
        ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleanIds.isEmpty) return const <Map<String, dynamic>>[];
    final rows = await SupabaseService.client
        .from('products')
        .select('*')
        .inFilter('id', cleanIds)
        .inFilter('status', ['approved', 'active']);
    final list = List<Map<String, dynamic>>.from(rows as List);
    final byId = <String, Map<String, dynamic>>{
      for (final row in list) (row['id']?.toString() ?? ''): row,
    };
    return cleanIds
        .map((id) => byId[id])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _saveIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, ids.toList());
  }
}

