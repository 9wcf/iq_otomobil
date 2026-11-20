import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/app_runtime_controls_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _RuntimeGuardScaffold(
      icon: Icons.build_circle_outlined,
      title: 'وضع الصيانة',
      messageBuilder: (c) => c.maintenanceMessage,
      actionLabel: 'إعادة المحاولة',
      onAction: () async => context.go('/splash'),
      cardColor: const Color(0xFF1E293B),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _RuntimeGuardScaffold(
      icon: Icons.system_update_alt_rounded,
      title: 'تحديث مطلوب',
      messageBuilder: (c) => c.forceUpdateMessage,
      actionLabel: 'تحديث الآن',
      onAction: () async {
        final controls = await const AppRuntimeControlsService().fetch();
        final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final url = controls.updateUrlForPlatform(isIos: isIos);
        if (url == null || url.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم ضبط رابط التحديث من لوحة الأدمن.'),
            ),
          );
          return;
        }
        final uri = Uri.tryParse(url);
        if (uri == null || !await canLaunchUrl(uri)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رابط التحديث غير صالح.')),
          );
          return;
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      cardColor: const Color(0xFF312E81),
    );
  }
}

class _RuntimeGuardScaffold extends StatelessWidget {
  const _RuntimeGuardScaffold({
    required this.icon,
    required this.title,
    required this.messageBuilder,
    required this.actionLabel,
    required this.onAction,
    required this.cardColor,
  });

  final IconData icon;
  final String title;
  final String Function(AppRuntimeControls controls) messageBuilder;
  final String actionLabel;
  final Future<void> Function() onAction;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: FutureBuilder<AppRuntimeControls>(
            future: const AppRuntimeControlsService().fetch(),
            builder: (context, snapshot) {
              final controls =
                  snapshot.data ?? AppRuntimeControls.defaults;
              final message = messageBuilder(controls);
              return Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 58, color: Colors.white),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAction,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
