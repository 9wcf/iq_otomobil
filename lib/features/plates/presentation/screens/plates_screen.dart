import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/plate_provider.dart';

class PlatesScreen extends ConsumerWidget {
  const PlatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platesAsync = ref.watch(approvedPlatesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحات السيارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: () => _showSubmitDialog(context, ref),
            tooltip: 'بيع لوحتك',
          ),
        ],
      ),
      body: platesAsync.when(
        // ✅ تصحيح: استخدام أسماء المعاملات (named parameters)
        data: (plates) {
          if (plates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_outlined,
                        size: 72, color: Colors.blue[200]),
                    const SizedBox(height: 16),
                    Text('لا توجد لوحات معروضة حالياً',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        'كن أول من يعرض لوحته — اضغط على زر البيع في الأعلى',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plates.length,
            itemBuilder: (ctx, i) => _PlateCard(plate: plates[i])
                .animate()
                .fadeIn(delay: (i * 100).ms)
                .slideY(begin: 0.1, end: 0),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('حدث خطأ في التحميل', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(e.toString(),
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(approvedPlatesProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmitDialog(BuildContext context, WidgetRef ref) {
    final plateCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? plateType = 'normal';
    String? governorate = 'بغداد';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('بيع لوحتك',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'رقم اللوحة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: plateType,
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('عادي')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP')),
                  DropdownMenuItem(value: 'special', child: Text('خاص')),
                ],
                onChanged: (v) => plateType = v,
                decoration: const InputDecoration(
                  labelText: 'نوع اللوحة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: governorate,
                items: const [
                  DropdownMenuItem(value: 'بغداد', child: Text('بغداد')),
                  DropdownMenuItem(value: 'البصرة', child: Text('البصرة')),
                  DropdownMenuItem(value: 'نينوى', child: Text('نينوى')),
                  DropdownMenuItem(value: 'أربيل', child: Text('أربيل')),
                ],
                onChanged: (v) => governorate = v,
                decoration: const InputDecoration(
                  labelText: 'المحافظة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتفك',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر المطلوب (دولار)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final data = {
                'plateNumber': plateCtrl.text,
                'plateType': plateType,
                'governorate': governorate,
                'sellerPhone': phoneCtrl.text,
                'price': double.tryParse(priceCtrl.text),
                'description': descCtrl.text,
              };
              final url =
                  ref.read(plateActionProvider.notifier).getWhatsAppLink(data);
              launchUrl(Uri.parse(url));
              Navigator.pop(context);
            },
            child: const Text('إرسال عبر واتساب'),
          ),
        ],
      ),
    );
  }
}

// بطاقة اللوحة
class _PlateCard extends StatelessWidget {
  final Map<String, dynamic> plate;
  const _PlateCard({required this.plate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plate['plate_number'] ?? 'غير محدد',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.blue[900],
                      ),
                    ),
                    if (plate['governorate'] != null)
                      Text(
                        plate['governorate'],
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              _PlateBadge(type: plate['plate_type'] ?? 'normal'),
            ],
          ),
          const Divider(height: 20),
          if (plate['price'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                '\$${plate['price']}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
            ),
          if (plate['description'] != null &&
              plate['description'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plate['description'],
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.phone, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                plate['seller_phone'] ?? '',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.blue[900]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// شارة نوع اللوحة
class _PlateBadge extends StatelessWidget {
  final String type;
  const _PlateBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final Map<String, Color> colors = {
      'vip': Colors.amber,
      'special': Colors.purple,
      'normal': Colors.blue,
    };
    final color = colors[type] ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        type.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
