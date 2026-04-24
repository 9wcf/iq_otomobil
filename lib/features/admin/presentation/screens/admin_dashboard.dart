import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  int _totalUsers = 0, _totalProducts = 0, _pendingProducts = 0;
  double _totalSales = 0.0;
  List<Map<String, dynamic>> _users = [], _products = [];

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadDashboardData();
  }

  // ✅ فحص الصلاحية الداخلي
  void _checkPermission() {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .then((profile) {
        final role = profile?['role'] as String?;
        if (role != 'admin') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('❌ غير مصرح لك'), backgroundColor: Colors.red));
              context.go('/');
            }
          });
        }
      });
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService.client;
      final usersRes = await supabase
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);
      final productsRes = await supabase
          .from('products')
          .select('*')
          .order('created_at', ascending: false);
      final pendingCount =
          productsRes.where((p) => p['status'] == 'pending').length;
      if (!mounted) return;
      setState(() {
        _users = usersRes;
        _products = productsRes;
        _totalUsers = usersRes.length;
        _totalProducts = productsRes.length;
        _pendingProducts = pendingCount;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      if (mounted) {
        _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ تم التحديث'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateProductStatus(String productId, String newStatus) async {
    try {
      if (newStatus == 'deleted')
        await SupabaseService.client
            .from('products')
            .delete()
            .eq('id', productId);
      else
        await SupabaseService.client
            .from('products')
            .update({'status': newStatus}).eq('id', productId);
      if (mounted) {
        _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ تم التحديث'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
          backgroundColor: const Color(0xFF1E40AF),
          elevation: 0,
          title: const Text('لوحة تحكم الأدمن',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadDashboardData),
            IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () {
                  SupabaseService.client.auth.signOut();
                  if (context.mounted) context.go('/auth');
                })
          ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _buildContent(),
      bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: Colors.blue.withOpacity(0.3),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.dashboard, color: Colors.blue),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.people_outline, color: Colors.grey),
                selectedIcon: Icon(Icons.people, color: Colors.blue),
                label: 'الأعضاء'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.inventory_2, color: Colors.blue),
                label: 'المنتجات')
          ]),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildStatsDashboard();
      case 1:
        return _buildUsersManagement();
      case 2:
        return _buildProductsManagement();
      default:
        return _buildStatsDashboard();
    }
  }

  Widget _buildStatsDashboard() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ]),
              child: const Row(children: [
                Icon(Icons.admin_panel_settings, size: 56, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('مرحباً بك يا مدير 👋',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('IQ OTOMBIL',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      Text('Admin Panel',
                          style: TextStyle(color: Colors.white, fontSize: 16))
                    ]))
              ])),
          const SizedBox(height: 32),
          const Text('نظرة عامة',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _StatCard(
                    title: 'المستخدمين',
                    value: '$_totalUsers',
                    icon: Icons.people,
                    color: Colors.blue,
                    delay: 100.ms),
                _StatCard(
                    title: 'المنتجات',
                    value: '$_totalProducts',
                    icon: Icons.inventory_2,
                    color: Colors.green,
                    delay: 200.ms),
                _StatCard(
                    title: 'قيد الانتظار',
                    value: '$_pendingProducts',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    delay: 300.ms),
                _StatCard(
                    title: 'المبيعات',
                    value: '\$${_totalSales.toStringAsFixed(1)}',
                    icon: Icons.attach_money,
                    color: Colors.purple,
                    delay: 400.ms)
              ]),
          const SizedBox(height: 32),
          const Text('آخر النشاطات',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._products
              .take(5)
              .map((product) => _buildRecentActivityItem(product))
              .toList()
        ]));
  }

  Widget _buildRecentActivityItem(Map<String, dynamic> product) {
    final name = product['model'] ?? 'منتج';
    final price = product['price'] ?? 0;
    final status = product['status'] ?? 'pending';
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: Row(children: [
          Icon(status == 'approved' ? Icons.check_circle : Icons.pending,
              color: status == 'approved' ? Colors.green : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('\$$price', style: const TextStyle(color: Colors.green))
              ])),
          Text(status == 'approved' ? 'مقبول' : 'معلق',
              style: TextStyle(
                  color: status == 'approved' ? Colors.green : Colors.orange,
                  fontSize: 12))
        ])).animate().fadeIn();
  }

  Widget _buildUsersManagement() {
    if (_users.isEmpty)
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text('لا يوجد مستخدمين حالياً',
            style: TextStyle(color: Colors.grey, fontSize: 16))
      ]));
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (ctx, index) {
          final user = _users[index];
          final role = user['role'] ?? 'user';
          final isBanned = user['is_banned'] ?? false;
          final name = user['full_name'] ?? 'مستخدم';
          final email = user['email'] ?? '';
          return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: isBanned
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isBanned
                          ? Colors.red
                          : Colors.blue.withOpacity(0.3))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                          backgroundColor: isBanned ? Colors.red : Colors.blue,
                          radius: 24,
                          child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text(email,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12))
                          ])),
                      _buildRoleBadge(role, isBanned)
                    ]),
                    const Divider(height: 32, color: Colors.grey),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (role != 'admin') ...[
                        ElevatedButton.icon(
                            onPressed: () => _updateUser(user['id'], {
                                  'role':
                                      role == 'promoter' ? 'user' : 'promoter'
                                }),
                            icon: Icon(
                                role == 'promoter'
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18),
                            label: Text(role == 'promoter' ? 'مستخدم' : 'مروج'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black)),
                        const SizedBox(width: 8)
                      ],
                      ElevatedButton.icon(
                          onPressed: () =>
                              _updateUser(user['id'], {'is_banned': !isBanned}),
                          icon:
                              Icon(isBanned ? Icons.lock_open : Icons.gpp_bad),
                          label: Text(isBanned ? 'فك الحظر' : 'حظر'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isBanned ? Colors.green : Colors.red,
                              foregroundColor: Colors.white))
                    ])
                  ])).animate().fadeIn(delay: (index * 50).ms);
        });
  }

  Widget _buildRoleBadge(String role, bool isBanned) {
    Color badgeColor;
    String labelText;
    if (isBanned) {
      badgeColor = Colors.red;
      labelText = 'محظور';
    } else {
      switch (role) {
        case 'admin':
          badgeColor = Colors.purple;
          labelText = 'أدمن';
          break;
        case 'promoter':
          badgeColor = Colors.amber;
          labelText = 'مروج';
          break;
        default:
          badgeColor = Colors.grey[700]!;
          labelText = 'مستخدم';
      }
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: badgeColor, borderRadius: BorderRadius.circular(20)),
        child: Text(labelText,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)));
  }

  Widget _buildProductsManagement() {
    if (_products.isEmpty)
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text('لا توجد منتجات حالياً',
            style: TextStyle(color: Colors.grey, fontSize: 16))
      ]));
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (ctx, index) {
          final p = _products[index];
          final images = p['images'];
          final imageUrl = (images is List && images.isNotEmpty)
              ? images[0].toString()
              : null;
          final name = p['model'] ?? 'منتج';
          final price = p['price'] ?? 0;
          final status = p['status'] ?? 'pending';
          final brandName = p['brand_id'] ?? 'غير محدد';
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: status == 'approved'
                        ? Colors.green
                        : status == 'pending'
                            ? Colors.orange
                            : Colors.red)),
            child: Row(children: [
              ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                  child: imageUrl != null
                      ? Image.network(imageUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey[800],
                              child: const Icon(Icons.image_not_supported,
                                  color: Colors.white)))
                      : Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[800],
                          child: const Icon(Icons.shopping_bag,
                              color: Colors.white, size: 40))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(brandName,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12)),
                            const SizedBox(height: 8),
                            Text('\$$price',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                            const SizedBox(height: 12),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (status == 'pending')
                                    ElevatedButton(
                                        onPressed: () => _updateProductStatus(
                                            p['id'], 'approved'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8)),
                                        child: const Text('موافقة',
                                            style: TextStyle(fontSize: 12))),
                                  if (status != 'pending')
                                    ElevatedButton(
                                        onPressed: () => _updateProductStatus(
                                            p['id'], 'pending'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8)),
                                        child: const Text('تعليق',
                                            style: TextStyle(fontSize: 12))),
                                  const SizedBox(width: 8),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () => _updateProductStatus(
                                          p['id'], 'deleted'))
                                ])
                          ])))
            ]),
          ).animate().fadeIn(delay: (index * 50).ms);
        });
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final Duration delay;
  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color,
      required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 12),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14))
      ]),
    ).animate().fadeIn(delay: delay).scale(begin: const Offset(0.8, 0.8));
  }
}
