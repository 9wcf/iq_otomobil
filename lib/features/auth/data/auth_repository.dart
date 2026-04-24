import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AuthRepository {
  final _client = SupabaseService.client;

  Future<User?> signUp(
      {required String phone,
      required String password,
      required String fullName}) async {
    final res = await _client.auth.signUp(
      phone: phone,
      password: password,
      data: {'full_name': fullName},
    );
    return res.user;
  }

  Future<User?> signIn(
      {required String phone, required String password}) async {
    final res =
        await _client.auth.signInWithPassword(phone: phone, password: password);
    return res.user;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final res =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    return res;
  }

  Stream<Session?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((e) => e.session);
}
