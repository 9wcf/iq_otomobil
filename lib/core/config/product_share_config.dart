import 'package:iq_otomobil/core/services/supabase_service.dart';

/// إعدادات روابط مشاركة المنتجات و Deep Links.
abstract final class ProductShareConfig {
  /// دومين مخصص (اختياري) — يُفعَّل لاحقاً عند نشر [share_landing].
  static const customShareHost = 'link.iqotomobil.com';

  static String get supabaseHost => Uri.parse(SupabaseService.projectUrl).host;

  /// مجلد Storage العام — ارفع [product-share.html] إلى bucket اسمه `app-links`.
  static const storageBucket = 'app-links';
  static const storageObjectPath = 'product-share.html';

  static const customScheme = 'iqotomobil';

  static const androidPackageId = 'iq.iqotomobil';

  static const iosBundleId = 'iq.iqotomobil.customer';

  static const defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=iq.iqotomobil';

  static const defaultAppStoreUrl =
      'https://apps.apple.com/search?term=IQ+OTOMBIL';

  static const edgeFunctionPath = '/functions/v1/product-share';

  static String get storageSharePath =>
      '/storage/v1/object/public/$storageBucket/$storageObjectPath';

  /// الرابط الذي يُشارَك على واتساب — Edge Function (Content-Type صحيح).
  static String httpsProductUrl(String productId) {
    final id = productId.trim();
    final encoded = Uri.encodeComponent(id);
    return 'https://$supabaseHost$edgeFunctionPath?id=$encoded';
  }

  /// رابط Storage (احتياطي — قد يعرض HTML كنص على Supabase).
  static String storageProductUrl(String productId) {
    final id = productId.trim();
    final encoded = Uri.encodeComponent(id);
    return 'https://$supabaseHost$storageSharePath?id=$encoded';
  }

  static String customSchemeProductUrl(String productId) {
    final id = productId.trim();
    return '$customScheme://product/${Uri.encodeComponent(id)}';
  }

  static List<String> get acceptedHttpsHosts => [
        supabaseHost,
        customShareHost,
      ];
}
