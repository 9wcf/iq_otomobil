import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/features/products/data/promoter_product_order_stats.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/features/catalog/data/shared_spare_categories.dart';
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';

/// قائمة منتجات المروج الحالي مع التعديل من شاشة إضافة المنتج والحذف، وإحصائيات الطلبات لكل منتج.
class PromoterMyProductsScreen extends StatefulWidget {
  const PromoterMyProductsScreen({super.key});

  @override
  State<PromoterMyProductsScreen> createState() =>
      _PromoterMyProductsScreenState();
}

class _PromoterMyProductsScreenState extends State<PromoterMyProductsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  Map<String, PromoterProductOrderStats> _orderStats = {};
  int _promoterOrdersCount = 0;

  /// `null` = عرض كل الأقسام (الكل).
  String? _categoryFilter;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await SupabaseService.client
          .from('products')
          .select('*')
          .eq('promoter_id', user.id)
          .order('created_at', ascending: false);

      final orders = await SupabaseService.client
          .from('orders')
          .select('id, status')
          .eq('promoter_id', user.id);

      final ordersList = List<Map<String, dynamic>>.from(orders);
      _promoterOrdersCount = ordersList.length;

      List<Map<String, dynamic>> orderItems = [];
      if (ordersList.isNotEmpty) {
        final orderIds =
            ordersList.map((o) => o['id'].toString()).toList(growable: false);
        final itemsRaw = await SupabaseService.client
            .from('order_items')
            .select('order_id, product_id, quantity')
            .inFilter('order_id', orderIds);
        orderItems = List<Map<String, dynamic>>.from(itemsRaw);
      }

      final stats = aggregateProductOrderStats(
        orders: ordersList,
        orderItems: orderItems,
      );

      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(res);
        _orderStats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _orderStats = {};
        _promoterOrdersCount = 0;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل المنتجات: $e')),
      );
    }
  }

  static String? _firstImageUrl(Map<String, dynamic> p) {
    final imgs = p['images'];
    if (imgs is List && imgs.isNotEmpty) {
      final first = imgs.first;
      if (first is String && first.isNotEmpty) return first;
    }
    return null;
  }

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) return;

    final id = product['id']?.toString();
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text(
          'هل أنت متأكد من حذف هذا المنتج؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await SupabaseService.client
          .from('products')
          .delete()
          .eq('id', id)
          .eq('promoter_id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المنتج'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحذف: $e')),
      );
    }
  }

  Future<void> _toggleStoreVisibility(Map<String, dynamic> product) async {
    final user = SupabaseService.currentUserInfo;
    if (user == null) return;
    final id = product['id']?.toString();
    if (id == null) return;

    final status = product['status']?.toString() ?? '';
    final src = product['suspension_source']?.toString();

    try {
      if (status == 'approved' || status == 'active') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('إخفاء من المتجر'),
            content: const Text(
              'لن يظهر المنتج للعملاء حتى تعيد تفعيله من هنا.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إخفاء'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        await SupabaseService.client.from('products').update({
          'status': 'suspended',
          'suspension_source': 'promoter',
        }).eq('id', id).eq('promoter_id', user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إخفاء المنتج عن المتجر'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (status == 'suspended') {
        if (src == 'admin') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'هذا المنتج معلّق من الإدارة. تواصل مع الدعم لرفع التعليق.',
              ),
            ),
          );
          return;
        }
        await SupabaseService.client.from('products').update({
          'status': 'approved',
          'suspension_source': null,
        }).eq('id', id).eq('promoter_id', user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إعادة المنتج للعرض'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        return;
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الظهور: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = _products;

    final f = _categoryFilter;
    if (f != null) {
      list = list.where((p) {
        final raw = p['category_id']?.toString().trim() ?? '';
        if (raw == f) return true;
        for (final c in kSharedSpareCategories) {
          if (c.id == f && raw == c.name) return true;
        }
        return false;
      }).toList();
    }

    final q = _searchQuery.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        final title = productDisplayTitle(p).toLowerCase();
        final model = (p['model']?.toString() ?? '').toLowerCase();
        final brandStored = p['brand_id']?.toString().trim();
        final brandLabel = (brandStored != null && brandStored.isNotEmpty)
            ? (brandByStorageLabel(brandStored)?.displayLine ?? brandStored)
                .toLowerCase()
            : '';
        return title.contains(q) ||
            model.contains(q) ||
            brandLabel.contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _openEdit(Map<String, dynamic> product) async {
    final id = product['id']?.toString();
    if (id == null) return;

    final changed = await context.push<bool>('/add-product?edit=$id');
    if (!mounted) return;
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/promoter'),
        ),
        title: const Text(
          'منتجاتي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 72, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد منتجات بعد',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أضف منتجاً من لوحة المروج',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Colors.blue,
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStatsBanner(),
                              const SizedBox(height: 12),
                              _buildSearchBar(),
                              const SizedBox(height: 12),
                              _buildCategoryFilterBar(),
                            ],
                          ),
                        ),
                      ),
                      if (_filteredProducts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.filter_alt_off_outlined,
                                    size: 56, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'لا توجد منتجات مطابقة للبحث'
                                      : 'لا توجد منتجات في هذا القسم',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _categoryFilter = null;
                                    _searchCtrl.clear();
                                  }),
                                  child: const Text('عرض كل المنتجات'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: _filteredProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final p = _filteredProducts[i];
                              final pid = p['id']?.toString();
                              final saleStats =
                                  pid != null ? _orderStats[pid] : null;
                              final buckets =
                                  bucketProductOrderStats(saleStats);
                              final totalOrders = saleStats?.totalOrders ?? 0;
                              final model = productDisplayTitle(p);
                              final price =
                                  (p['price'] as num?)?.toDouble() ?? 0;
                              final status = p['status'];
                              final suspensionSrc =
                                  p['suspension_source']?.toString();
                              final url = _firstImageUrl(p);
                              final canSelfToggleVisibility =
                                  status == 'approved' ||
                                      status == 'active' ||
                                      (status == 'suspended' &&
                                          suspensionSrc != 'admin');

                              return Material(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openEdit(p),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 88,
                                                height: 88,
                                                child: url != null
                                                    ? Image.network(
                                                        url,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (_, __, ___) =>
                                                                _placeholder(),
                                                      )
                                                    : _placeholder(),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    model,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    formatIQD(price),
                                                    style: const TextStyle(
                                                      color: Colors
                                                          .lightBlueAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _ProductListingStatusChip(
                                                    status: status,
                                                    suspensionSource:
                                                        suspensionSrc,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'تعديل المنتج',
                                                  onPressed: () => _openEdit(p),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: status == 'suspended'
                                                      ? (suspensionSrc ==
                                                              'admin'
                                                          ? 'معلّق من الإدارة'
                                                          : 'إظهار في المتجر')
                                                      : 'إخفاء عن المتجر',
                                                  onPressed: canSelfToggleVisibility
                                                      ? () =>
                                                          _toggleStoreVisibility(
                                                              p)
                                                      : null,
                                                  icon: Icon(
                                                    status == 'suspended'
                                                        ? Icons.visibility_rounded
                                                        : Icons
                                                            .visibility_off_outlined,
                                                    color: canSelfToggleVisibility
                                                        ? Colors.lightBlueAccent
                                                        : Colors.white24,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'حذف',
                                                  onPressed: () =>
                                                      _confirmDelete(p),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _OrderStatsFixedRow(
                                          buckets: buckets,
                                          totalOrders: totalOrders,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'ابحث عن منتج بالاسم أو الماركة...',
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: Colors.grey[400]),
                onPressed: _searchCtrl.clear,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_list_rounded, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              'تصفية حسب القسم',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 8),
                child: _CategoryFilterChip(
                  label: 'الكل',
                  selected: _categoryFilter == null,
                  accent: Colors.lightBlueAccent,
                  onTap: () => setState(() => _categoryFilter = null),
                ),
              ),
              ...kSharedSpareCategories.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryFilterChip(
                    label: c.name,
                    selected: _categoryFilter == c.id,
                    accent: c.color,
                    onTap: () => setState(() => _categoryFilter = c.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF334155),
      child: const Icon(Icons.image_not_supported_outlined,
          color: Colors.white38, size: 36),
    );
  }

  Widget _buildStatsBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.lightBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined,
              color: Colors.lightBlueAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إحصائيات الطلبات',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _promoterOrdersCount == 0
                      ? 'لا توجد طلبات على متجرك بعد.'
                      : 'إجمالي الطلبات الواردة: $_promoterOrdersCount — والتفصيل حسب المنتج يظهر في كل بطاقة.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.35),
                      accent.withValues(alpha: 0.18),
                    ],
                  )
                : null,
            color: selected ? null : const Color(0xFF1E293B),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[400],
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// شارة حالة عرض المنتج: معروض / قيد المراجعة / معلّق.
class _ProductListingStatusChip extends StatelessWidget {
  const _ProductListingStatusChip({
    required this.status,
    this.suspensionSource,
  });

  final dynamic status;
  final String? suspensionSource;

  @override
  Widget build(BuildContext context) {
    final s = status?.toString() ?? '';
    late final String label;
    late final Color bg;
    late final Color fg;
    late final IconData icon;

    switch (s) {
      case 'rejected':
        label = 'مرفوض · غير معروض';
        bg = const Color(0xFF450A0A);
        fg = const Color(0xFFFFA8A8);
        icon = Icons.block_rounded;
        break;
      case 'pending':
        label = 'قيد المراجعة';
        bg = const Color(0xFF713F12);
        fg = const Color(0xFFFDE68A);
        icon = Icons.pending_actions_rounded;
        break;
      case 'suspended':
        final byAdmin = suspensionSource == 'admin';
        label = byAdmin
            ? 'معلّق من الإدارة · مخفي'
            : 'معلّق · مخفي عن المتجر';
        bg = const Color(0xFF3B0764);
        fg = const Color(0xFFE9D5FF);
        icon = Icons.pause_circle_outline_rounded;
        break;
      case 'approved':
        label = 'معتمد · معروض';
        bg = const Color(0xFF134E4A);
        fg = const Color(0xFF5EEAD4);
        icon = Icons.verified_rounded;
        break;
      case 'active':
        label = 'نشط · معروض';
        bg = const Color(0xFF14532D);
        fg = const Color(0xFF86EFAC);
        icon = Icons.storefront_rounded;
        break;
      default:
        label = s.isEmpty ? '—' : s;
        bg = const Color(0xFF334155);
        fg = Colors.white70;
        icon = Icons.label_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// صفان: عناوين ثم أرقام — إحصائيات الطلبات حسب الحالة.
class _OrderStatsFixedRow extends StatelessWidget {
  const _OrderStatsFixedRow({
    required this.buckets,
    required this.totalOrders,
  });

  final ProductOrderBuckets buckets;
  final int totalOrders;

  static const _cCancelled = Color(0xFFF87171);
  static const _cPending = Color(0xFFFBBF24);
  static const _cDelivered = Color(0xFF34D399);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 17, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'إحصائيات المنتج',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                totalOrders > 0
                    ? '$totalOrders طلباً · ${buckets.totalUnits} وحدة'
                    : 'لا طلبات بعد',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatHeader(
                  label: 'ملغي',
                  accent: _cCancelled,
                  icon: Icons.cancel_outlined,
                ),
              ),
              Expanded(
                child: _StatHeader(
                  label: 'قيد الانتظار',
                  accent: _cPending,
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
              Expanded(
                child: _StatHeader(
                  label: 'تم التسليم',
                  accent: _cDelivered,
                  icon: Icons.local_shipping_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatValue(
                  value: buckets.cancelled,
                  accent: _cCancelled,
                ),
              ),
              Expanded(
                child: _StatValue(
                  value: buckets.pending,
                  accent: _cPending,
                ),
              ),
              Expanded(
                child: _StatValue(
                  value: buckets.delivered,
                  accent: _cDelivered,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatHeader extends StatelessWidget {
  const _StatHeader({
    required this.label,
    required this.accent,
    required this.icon,
  });

  final String label;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: accent.withValues(alpha: 0.9)),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.value, required this.accent});

  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: accent,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.5,
      ),
    );
  }
}
