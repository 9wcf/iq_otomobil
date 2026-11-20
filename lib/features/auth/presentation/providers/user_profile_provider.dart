import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';

/// دور المستخدم الحالي (لزر الإدارة في الهوم) — بدون إخفاء بقية الأزرار أثناء التحميل.
final userProfileRoleProvider = FutureProvider.autoDispose<String?>((ref) async {
  final uid = SupabaseService.currentUserId;
  if (uid == null) return null;
  try {
    final row = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return row?['role'] as String?;
  } catch (_) {
    return null;
  }
});
