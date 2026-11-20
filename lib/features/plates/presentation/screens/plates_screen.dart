import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/utils/support_whatsapp.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/iraq_governorates.dart';
import '../providers/plate_provider.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/core/widgets/user_flow_ui.dart';
import 'package:iq_otomobil/features/catalog/presentation/widgets/user_product_list_tile.dart';

class PlatesScreen extends ConsumerWidget {
  const PlatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platesAsync = ref.watch(approvedPlatesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: kProductListBackground,
      appBar: AppBar(
        title: Text(
          'لوحات السيارات',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: kProductListBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _PlatesAddButton(
              onPressed: () => _showSubmitDialog(context, ref),
            ),
          ),
        ],
      ),
      body: platesAsync.when(
        data: (plates) {
          if (plates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'لا توجد لوحات معتمدة حالياً',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أضف لوحتك وستُراجع من الإدارة ثم تظهر هنا',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              userShellScrollBottomPadding(context),
            ),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: plates.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: kProductCardListSpacing + 4),
            itemBuilder: (ctx, i) => _PlateCard(plate: plates[i])
                .animate()
                .fadeIn(delay: (40 * i).ms, duration: 280.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 56, color: AppColors.error.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في التحميل',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => ref.invalidate(approvedPlatesProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSubmitDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _SellPlateDialog(
        onSubmitted: (payload) async {
          ref.invalidate(approvedPlatesProvider);

          final msg = payload.whatsAppMessage;
          await showDialog<void>(
            context: context,
            builder: (dCtx) => _WhatsAppContactDialog(message: msg),
          );
        },
      ),
    );
  }
}

class _PlateSubmitPayload {
  const _PlateSubmitPayload({
    required this.plateNumber,
    required this.plateType,
    required this.governorate,
    required this.sellerPhone,
    this.price,
    this.description,
  });

  final String plateNumber;
  final String plateType;
  final String governorate;
  final String sellerPhone;
  final double? price;
  final String? description;

  String get whatsAppMessage {
    final sb = StringBuffer();
    sb.writeln('طلب موافقة لوحة سيارة');
    sb.writeln('—');
    sb.writeln('رقم اللوحة: $plateNumber');
    sb.writeln('نوع اللوحة: $plateType');
    sb.writeln('المحافظة: $governorate');
    if (price != null) sb.writeln('السعر: ${formatIQD(price)}');
    sb.writeln('رقمي للتواصل: $sellerPhone');
    if (description != null && description!.trim().isNotEmpty) {
      sb.writeln('ملاحظات: ${description!.trim()}');
    }
    sb.writeln('—');
    sb.writeln('تم الإرسال من تطبيق IQ OTOMBIL');
    return sb.toString();
  }
}

class _WhatsAppContactDialog extends StatelessWidget {
  const _WhatsAppContactDialog({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(Icons.chat_rounded, color: Color(0xFF22C55E)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'تم استلام الطلب',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تواصل مع الإدارة عبر واتساب:\n${SupportContact.display}',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: const TextStyle(height: 1.35),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              await openSupportWhatsApp(context: context, message: message);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text(
              'تواصل عبر واتساب',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

Future<String?> _showGovernoratePicker(
    BuildContext context, String current) async {
  String query = '';
  List<String> filtered = List<String>.from(kIraqGovernorates);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              void applyFilter(String q) {
                query = q.trim();
                setModalState(() {
                  if (query.isEmpty) {
                    filtered = List<String>.from(kIraqGovernorates);
                  } else {
                    filtered = kIraqGovernorates
                        .where((g) => g.contains(query))
                        .toList();
                  }
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'اختر المحافظة',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: applyFilter,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن المحافظة…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final g = filtered[i];
                        final sel = g == current;
                        return ListTile(
                          title: Text(
                            g,
                            style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel
                                  ? Theme.of(ctx).colorScheme.primary
                                  : null,
                            ),
                          ),
                          trailing: sel
                              ? Icon(Icons.check_circle_rounded,
                                  color: Theme.of(ctx).colorScheme.primary)
                              : null,
                          onTap: () => Navigator.pop(ctx, g),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

class _SellPlateDialog extends ConsumerStatefulWidget {
  final void Function(_PlateSubmitPayload payload) onSubmitted;

  const _SellPlateDialog({required this.onSubmitted});

  @override
  ConsumerState<_SellPlateDialog> createState() => _SellPlateDialogState();
}

class _SellPlateDialogState extends ConsumerState<_SellPlateDialog> {
  final _plateCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  String _plateType = 'normal';
  String _governorate = kIraqGovernorates.first;
  File? _imageFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final userPhone = SupabaseService.currentUserInfo?.phone?.trim();
    if (userPhone != null && userPhone.isNotEmpty) {
      _phoneCtrl.text = userPhone;
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _phoneCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (x == null) return;
    setState(() => _imageFile = File(x.path));
  }

  Future<void> _submit() async {
    final plate = _plateCtrl.text.trim();
    if (plate.isEmpty) {
      _toast('أدخل رقم اللوحة');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _toast('أدخل رقم الهاتف');
      return;
    }

    setState(() => _submitting = true);
    try {
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final price = double.tryParse(_priceCtrl.text.trim());
      await ref.read(plateActionProvider.notifier).submit(
            plateNumber: plate,
            plateType: _plateType,
            governorate: _governorate,
            description: desc,
            price: price,
            sellerPhone: phone,
            sellerName: null,
            images: _imageFile != null ? [_imageFile!] : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted(
        _PlateSubmitPayload(
          plateNumber: plate,
          plateType: _plateType,
          governorate: _governorate,
          sellerPhone: phone,
          price: price,
          description: desc,
        ),
      );
    } catch (e) {
      _toast('فشل الإرسال: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.orange[800]),
    );
  }

  InputDecoration _dec({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.14),
                      cs.secondary.withValues(alpha: 0.08),
                      cs.surface,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.confirmation_number_rounded,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بيع لوحتك',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'أدخل التفاصيل، وسيتم إرسالها للمراجعة',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(
                        icon: Icons.confirmation_number_outlined,
                        title: 'معلومات اللوحة',
                        subtitle: 'رقم اللوحة ونوعها',
                        child: Column(
                          children: [
                            TextField(
                              controller: _plateCtrl,
                              textDirection: TextDirection.ltr,
                              enabled: !_submitting,
                              decoration: _dec(
                                label: 'رقم اللوحة',
                                hint: 'مثال: 123456',
                                prefixIcon: const Icon(
                                    Icons.confirmation_number_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'نوع اللوحة',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'normal', label: Text('عادي')),
                                ButtonSegment(value: 'vip', label: Text('VIP')),
                                ButtonSegment(value: 'special', label: Text('خاص')),
                              ],
                              selected: {_plateType},
                              onSelectionChanged: _submitting
                                  ? null
                                  : (s) => setState(() => _plateType = s.first),
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        icon: Icons.location_city_rounded,
                        title: 'المحافظة',
                        subtitle: 'اختر المحافظة من القائمة',
                        child: Material(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _submitting
                                ? null
                                : () async {
                                    final g = await _showGovernoratePicker(
                                        context, _governorate);
                                    if (g != null) setState(() => _governorate = g);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.location_city_rounded,
                                      color: cs.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _governorate,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_up_rounded,
                                      color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        icon: Icons.call_rounded,
                        title: 'بيانات التواصل',
                        subtitle:
                            'رقمك للعرض عند الموافقة — واتساب الإدارة: ${SupportContact.display}',
                        child: Column(
                          children: [
                            TextField(
                              controller: _phoneCtrl,
                              enabled: !_submitting,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              decoration: _dec(
                                label: 'رقمك للتواصل',
                                hint: 'مثال: 776 099 7799',
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _priceCtrl,
                              enabled: !_submitting,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              textDirection: TextDirection.ltr,
                              decoration: _dec(
                                label: 'السعر المطلوب (دينار)',
                                hint: 'اختياري',
                                prefixIcon:
                                    const Icon(Icons.payments_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _descCtrl,
                              enabled: !_submitting,
                              maxLines: 2,
                              decoration: _dec(
                                label: 'ملاحظات (اختياري)',
                                hint: 'أي تفاصيل إضافية…',
                                prefixIcon: const Icon(Icons.notes_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        icon: Icons.photo_library_outlined,
                        title: 'صورة اللوحة',
                        subtitle: 'إضافة صورة تساعد في تسريع المراجعة',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _submitting ? null : _pickImage,
                              icon:
                                  const Icon(Icons.add_photo_alternate_rounded),
                              label: Text(
                                _imageFile == null
                                    ? 'إرفاق صورة اللوحة'
                                    : 'تغيير الصورة',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            if (_imageFile != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AspectRatio(
                                  aspectRatio: kPlateImageAspectRatio,
                                  child: Image.file(
                                    _imageFile!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Actions (sticky)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'إرسال للمراجعة',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Plates list — premium UI (matches home & product detail) ───────────────

abstract final class _PlatesUi {
  static const cardShadow = Color(0x14134A8A);
}

class _PlatesAddButton extends StatelessWidget {
  const _PlatesAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.55),
            ),
          ),
          child: const Icon(
            Icons.add_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// بطاقة اللوحة — تصميم عمودي premium متوافق مع بطاقات المنتجات.
class _PlateCard extends StatefulWidget {
  const _PlateCard({required this.plate});

  final Map<String, dynamic> plate;

  @override
  State<_PlateCard> createState() => _PlateCardState();
}

class _PlateCardState extends State<_PlateCard> {
  bool _pressed = false;

  String? _firstImageUrl() {
    final imgs = widget.plate['images'];
    if (imgs is List && imgs.isNotEmpty) {
      return imgs.first.toString();
    }
    return null;
  }

  String _plateTypeLabel(String raw) {
    switch (raw) {
      case 'vip':
        return 'VIP';
      case 'special':
        return 'خاص';
      case 'normal':
      default:
        return 'عادي';
    }
  }

  Future<void> _callSeller(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بهذا الرقم')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = _firstImageUrl();
    final plateNumber =
        (widget.plate['plate_number'] ?? 'غير محدد').toString();
    final governorate = widget.plate['governorate']?.toString().trim();
    final phone = (widget.plate['seller_phone'] ?? '').toString().trim();
    final typeRaw = (widget.plate['plate_type'] ?? 'normal').toString();
    final typeLabel = _plateTypeLabel(typeRaw);
    final priceRaw = widget.plate['price'];
    final priceText = priceRaw != null
        ? formatIQD(
            priceRaw is num ? priceRaw : num.tryParse('$priceRaw'),
          )
        : null;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.988 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: _PlatesUi.cardShadow,
                blurRadius: _pressed ? 8 : 14,
                offset: Offset(0, _pressed ? 2 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plateNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  height: 1.1,
                                ),
                              ),
                              if (governorate != null &&
                                  governorate.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _PlateMetaChip(
                                  icon: Icons.location_on_outlined,
                                  label: governorate,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PlateTypeBadge(label: typeLabel, raw: typeRaw),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: kPlateImageAspectRatio,
                        child: _PlateCardImage(imageUrl: imageUrl),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (priceText != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'السعر',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  priceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        if (phone.isNotEmpty) ...[
                          if (priceText != null) const SizedBox(width: 10),
                          _PlateCallButton(
                            phone: phone,
                            onTap: () => _callSeller(phone),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlateCardImage extends StatelessWidget {
  const _PlateCardImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 900,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => const ColoredBox(
          color: AppColors.inputFill,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => const _PlateImagePlaceholder(),
      );
    }
    return const _PlateImagePlaceholder();
  }
}

class _PlateImagePlaceholder extends StatelessWidget {
  const _PlateImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.inputFill,
      child: Center(
        child: Icon(
          Icons.confirmation_number_outlined,
          size: 48,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _PlateMetaChip extends StatelessWidget {
  const _PlateMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateTypeBadge extends StatelessWidget {
  const _PlateTypeBadge({required this.label, required this.raw});

  final String label;
  final String raw;

  @override
  Widget build(BuildContext context) {
    if (raw == 'vip') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final Color accent;
    switch (raw) {
      case 'special':
        accent = const Color(0xFF8B5CF6);
      default:
        accent = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlateCallButton extends StatefulWidget {
  const _PlateCallButton({required this.phone, required this.onTap});

  final String phone;
  final VoidCallback onTap;

  @override
  State<_PlateCallButton> createState() => _PlateCallButtonState();
}

class _PlateCallButtonState extends State<_PlateCallButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}