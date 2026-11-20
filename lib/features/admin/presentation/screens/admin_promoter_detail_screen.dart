import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/features/admin/data/admin_repository.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';

/// تفاصيل مروّج: منتجاته وموافقة الأدمن (مسار `/admin/promoter/:promoterId`).
class AdminPromoterDetailScreen extends StatefulWidget {
  const AdminPromoterDetailScreen({super.key, required this.promoterId});

  final String promoterId;

  @override
  State<AdminPromoterDetailScreen> createState() =>
      _AdminPromoterDetailScreenState();
}

class _AdminPromoterDetailScreenState extends State<AdminPromoterDetailScreen> {
  final _repo = AdminRepository();
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _repo.getProfile(widget.promoterId);
      final products = await _repo.getProductsByPromoter(widget.promoterId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _setAutoApprove(bool v) async {
    try {
      await _repo.setPromoterAutoApprove(widget.promoterId, v);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم الحفظ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approve(String productId) async {
    try {
      await _repo.updateProductStatus(productId, 'approved');
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _suspendProduct(String productId) async {
    try {
      await _repo.updateProductStatus(
        productId,
        'suspended',
        suspensionSource: 'admin',
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editProduct(String productId) async {
    final changed = await context.push<bool>('/admin/edit-product?edit=$productId');
    if (!mounted) return;
    if (changed == true) await _load();
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await _repo.deleteProduct(productId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم الحذف'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _isListed(String? status) {
    final s = status ?? 'pending';
    return s == 'approved' || s == 'active';
  }

  String _productStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'suspended':
        return 'معلّق · مخفي عن العملاء';
      case 'approved':
      case 'active':
        return 'معروض';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  Color _statusBorderColor(String status) {
    if (_isListed(status)) {
      return Colors.green.withValues(alpha: 0.5);
    }
    if (status == 'pending') {
      return Colors.orange.withValues(alpha: 0.5);
    }
    if (status == 'suspended') {
      return Colors.deepPurpleAccent.withValues(alpha: 0.55);
    }
    return Colors.red.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF151E32);
    const card = Color(0xFF1E293B);
    final name = _profile?['full_name']?.toString() ?? 'مروّج';
    final phone = _profile?['phone']?.toString() ?? '';
    final autoOn = _profile?['auto_approve_products'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8)))
          : RefreshIndicator(
              color: const Color(0xFF3B82F6),
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Material(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'موافقة تلقائية على المنتجات الجديدة',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: autoOn,
                                activeTrackColor:
                                    const Color(0xFF3B82F6).withValues(alpha: 0.55),
                                onChanged: _setAutoApprove,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'المنتجات (${_products.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_products.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          'لا توجد منتجات لهذا المروّج',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ..._products.map((p) {
                      final id = p['id']?.toString() ?? '';
                      final status = p['status']?.toString() ?? 'pending';
                      final images = p['images'];
                      final imageUrl = (images is List && images.isNotEmpty)
                          ? images[0].toString()
                          : null;
                      final title = productDisplayTitle(p);
                      final price = p['price'] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _statusBorderColor(status),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 110,
                                          height: 110,
                                          color: Colors.grey[900],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 110,
                                        height: 110,
                                        color: Colors.grey[900],
                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Colors.white54,
                                          size: 36,
                                        ),
                                      ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatIQD(price is num
                                            ? price
                                            : double.tryParse('$price')),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _productStatusLabel(status),
                                        style: TextStyle(
                                          color: _isListed(status)
                                              ? Colors.green
                                              : status == 'suspended'
                                                  ? Colors.deepPurpleAccent
                                                  : Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          if (status == 'pending' ||
                                              status == 'suspended')
                                            FilledButton(
                                              onPressed: () => _approve(id),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                              ),
                                              child: Text(
                                                status == 'suspended'
                                                    ? 'إعادة العرض'
                                                    : 'موافقة',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                          if (_isListed(status))
                                            OutlinedButton(
                                              onPressed: () =>
                                                  _suspendProduct(id),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.orange,
                                                side: const BorderSide(
                                                    color: Colors.orange),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                              ),
                                              child: const Text('تعليق',
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                            ),
                                          IconButton(
                                            onPressed: () => _editProduct(id),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: Colors.amber,
                                            ),
                                            tooltip: 'تعديل',
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteProduct(id),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                            ),
                                            tooltip: 'حذف',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
