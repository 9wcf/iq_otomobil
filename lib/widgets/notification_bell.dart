import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import '../features/orders/presentation/providers/order_provider.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const SizedBox.shrink();

    final notificationsAsync = ref.watch(unreadNotificationsProvider(userId));

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotifications(context, ref, userId),
        ),
        notificationsAsync.when(
          data: (list) => list.isNotEmpty
              ? Positioned(right: 8, top: 8, child: _Badge(count: list.length))
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NotificationsSheet(userId: userId),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration:
            const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text('$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      );
}

class _NotificationsSheet extends ConsumerWidget {
  final String userId;
  const _NotificationsSheet({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(unreadNotificationsProvider(userId));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإشعارات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: notificationsAsync.when(
              data: (list) => list.isEmpty
                  ? const Center(child: Text('لا توجد إشعارات جديدة'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(list[i]['title'] as String? ?? ''),
                        subtitle: Text(list[i]['message'] as String? ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () {
                            ref
                                .read(orderActionProvider.notifier)
                                .markNotificationRead(
                                    list[i]['id'] as String);
                            ref.invalidate(unreadNotificationsProvider(userId));
                          },
                        ),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
