import 'package:iq_otomobil/core/services/supabase_service.dart';

class AppRuntimeControls {
  const AppRuntimeControls({
    required this.maintenanceMode,
    required this.forceUpdateEnabled,
    required this.minSupportedBuild,
    required this.maintenanceMessage,
    required this.forceUpdateMessage,
    this.updateUrl,
    this.updateUrlIos,
  });

  final bool maintenanceMode;
  final bool forceUpdateEnabled;
  final int minSupportedBuild;
  final String maintenanceMessage;
  final String forceUpdateMessage;
  /// Google Play أو APK (أندرويد).
  final String? updateUrl;
  /// App Store (آيفون).
  final String? updateUrlIos;

  static const defaults = AppRuntimeControls(
    maintenanceMode: false,
    forceUpdateEnabled: false,
    minSupportedBuild: 1,
    maintenanceMessage: 'التطبيق في وضع الصيانة حاليا. يرجى المحاولة لاحقا.',
    forceUpdateMessage: 'يتوفر تحديث إجباري للتطبيق. يرجى التحديث للمتابعة.',
    updateUrl: null,
    updateUrlIos: null,
  );

  /// رابط المتجر المناسب للمنصة الحالية.
  String? updateUrlForPlatform({required bool isIos}) {
    if (isIos) {
      final ios = updateUrlIos?.trim();
      if (ios != null && ios.isNotEmpty) return ios;
      return updateUrl?.trim().isNotEmpty == true ? updateUrl!.trim() : null;
    }
    final android = updateUrl?.trim();
    if (android != null && android.isNotEmpty) return android;
    return updateUrlIos?.trim().isNotEmpty == true ? updateUrlIos!.trim() : null;
  }

  factory AppRuntimeControls.fromMap(Map<String, dynamic>? row) {
    if (row == null) return defaults;
    return AppRuntimeControls(
      maintenanceMode: row['maintenance_mode'] == true,
      forceUpdateEnabled: row['force_update_enabled'] == true,
      minSupportedBuild: (row['min_supported_build'] as num?)?.toInt() ?? 1,
      maintenanceMessage:
          (row['maintenance_message']?.toString().trim().isNotEmpty == true)
              ? row['maintenance_message'].toString().trim()
              : defaults.maintenanceMessage,
      forceUpdateMessage:
          (row['force_update_message']?.toString().trim().isNotEmpty == true)
              ? row['force_update_message'].toString().trim()
              : defaults.forceUpdateMessage,
      updateUrl: row['update_url']?.toString().trim().isEmpty == true
          ? null
          : row['update_url']?.toString().trim(),
      updateUrlIos: row['update_url_ios']?.toString().trim().isEmpty == true
          ? null
          : row['update_url_ios']?.toString().trim(),
    );
  }
}

class AppRuntimeControlsService {
  const AppRuntimeControlsService();

  Future<AppRuntimeControls> fetch() async {
    final row = await SupabaseService.client
        .from('app_runtime_controls')
        .select('*')
        .eq('id', 1)
        .maybeSingle();
    return AppRuntimeControls.fromMap(row);
  }

  Future<void> save(AppRuntimeControls controls) async {
    await SupabaseService.client.from('app_runtime_controls').upsert({
      'id': 1,
      'maintenance_mode': controls.maintenanceMode,
      'force_update_enabled': controls.forceUpdateEnabled,
      'min_supported_build': controls.minSupportedBuild,
      'maintenance_message': controls.maintenanceMessage.trim(),
      'force_update_message': controls.forceUpdateMessage.trim(),
      'update_url': controls.updateUrl?.trim().isEmpty == true
          ? null
          : controls.updateUrl?.trim(),
      'update_url_ios': controls.updateUrlIos?.trim().isEmpty == true
          ? null
          : controls.updateUrlIos?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
