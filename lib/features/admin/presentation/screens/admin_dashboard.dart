import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/features/catalog/data/product_display_utils.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

bool _profileHasPhone(Map<String, dynamic> u) {
  final raw = u['phone']?.toString().trim() ?? '';
  if (raw.length >= 8) return true;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8;
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  int _pendingProducts = 0;
  int _pendingPlates = 0;
  List<Map<String, dynamic>> _users = [], _products = [], _plates = [];

  /// أعضاء مسجّلون برقم هاتف (يُخفى التراث بدون هاتف)
  List<Map<String, dynamic>> get _phoneProfiles =>
      _users.where((u) => _profileHasPhone(u)).toList();

  /// الأعضاء = مستخدمون فقط (بدون مروج/أدمن)
  List<Map<String, dynamic>> get _memberListProfiles => _phoneProfiles
      .where((u) => u['role']?.toString() == 'user')
      .toList();

  List<Map<String, dynamic>> get _promoterProfiles => _phoneProfiles
      .where((u) => u['role']?.toString() == 'promoter')
      .toList();

  List<Map<String, dynamic>> get _upgradeRequests => _phoneProfiles
      .where((u) =>
          u['role']?.toString() == 'user' &&
          (u['merchant_status']?.toString() ?? 'none') == 'pending')
      .toList();

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadDashboardData();
  }

  // ✅ فحص الصلاحية الداخلي
  void _checkPermission() {
    final user = SupabaseService.currentUserInfo;
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
      List<dynamic> usersRes;
      try {
        usersRes = await supabase
            .from('profiles')
            .select('*')
            .order('created_at', ascending: false);
      } catch (_) {
        // بعض المشاريع لا تحتوي created_at أو قد يمنع RLS الترتيب/الجلب
        usersRes = await supabase.from('profiles').select('*');
      }
      final productsRes = await supabase
          .from('products')
          .select('*')
          .order('created_at', ascending: false);
      final platesRes = await supabase
          .from('car_plates')
          .select('*')
          .order('created_at', ascending: false);
      final pendingCount =
          productsRes.where((p) => p['status'] == 'pending').length;
      final pendingPlatesCount =
          platesRes.where((p) => p['status'] == 'pending').length;
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(usersRes);
        _products = productsRes;
        _plates = platesRes;
        _pendingProducts = pendingCount;
        _pendingPlates = pendingPlatesCount;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
        );
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      // تحقق: اقرأ القيم بعد التحديث لتأكيد وصولها (يفيد مع RLS/صلاحيات الأدمن)
      final row = await SupabaseService.client
          .from('profiles')
          .select('role, merchant_status, account_status, full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        _loadDashboardData();
        final msg = row == null
            ? '✅ تم التحديث، لكن لم أستطع قراءة السجل بعده (RLS؟)'
            : '✅ تم التحديث\n'
                'name=${(row['full_name'] ?? '—')}\n'
                'phone=${(row['phone'] ?? '—')}\n'
                'role=${(row['role'] ?? '—')}\n'
                'merchant=${(row['merchant_status'] ?? '—')}\n'
                'account=${(row['account_status'] ?? '—')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updatePlateStatus(String plateId, String newStatus) async {
    try {
      if (newStatus == 'deleted') {
        await SupabaseService.client
            .from('car_plates')
            .delete()
            .eq('id', plateId);
      } else {
        await SupabaseService.client
            .from('car_plates')
            .update({'status': newStatus}).eq('id', plateId);
      }
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
    const bg = Color(0xFF0B1220);
    const surface = Color(0xFF151E32);
    const accent = Color(0xFF818CF8);

    final navIndex = _selectedIndex > 3 ? 3 : _selectedIndex;
    if (navIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = navIndex);
      });
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
          backgroundColor: surface,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('لوحة الإدارة',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                tooltip: 'البنرات الإعلانية',
                icon: const Icon(Icons.campaign_rounded, color: Colors.white),
                onPressed: () => context.push('/admin/ads')),
            IconButton(
                tooltip: 'التحكم بالتطبيق',
                icon: const Icon(Icons.settings_applications_rounded,
                    color: Colors.white),
                onPressed: () => context.push('/admin/system-controls')),
            IconButton(
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _loadDashboardData),
            IconButton(
                tooltip: 'خروج',
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                onPressed: () async {
                  await SupabaseService.signOutAll();
                  if (context.mounted) context.go('/auth');
                })
          ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : _buildContent(),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          backgroundColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF3B82F6).withValues(alpha: 0.22),
          shadowColor: Colors.black54,
          elevation: 12,
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF93C5FD),
              );
            }
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: Color(0xFF60A5FA),
                size: 26,
              );
            }
            return IconThemeData(color: Colors.grey[600], size: 24);
          }),
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: const Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black38,
          selectedIndex: navIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'الأعضاء'),
            NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'المروجون'),
            NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number_rounded),
                label: 'اللوحات'),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final i = _selectedIndex > 3 ? 3 : _selectedIndex;
    switch (i) {
      case 0:
        return _buildStatsDashboard();
      case 1:
        return _buildUsersManagement();
      case 2:
        return _buildPromotersManagement();
      case 3:
        return _buildPlatesManagement();
      default:
        return _buildStatsDashboard();
    }
  }

  Widget _buildStatsDashboard() {
    const statsSurface = Color(0xFF151E32);
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
          const SizedBox(height: 8),
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
              childAspectRatio: 0.92,
              children: [
                _StatCard(
                    title: 'الأعضاء (هاتف)',
                    value: '${_memberListProfiles.length}',
                    icon: Icons.people,
                    color: Colors.blue,
                    delay: 100.ms),
                _StatCard(
                    title: 'المروجون',
                    value: '${_promoterProfiles.length}',
                    icon: Icons.storefront,
                    color: const Color(0xFFF59E0B),
                    delay: 200.ms),
                _StatCard(
                    title: 'منتجات قيد المراجعة',
                    value: '$_pendingProducts',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    delay: 300.ms),
                _StatCard(
                    title: 'لوحات قيد المراجعة',
                    value: '$_pendingPlates',
                    icon: Icons.confirmation_number,
                    color: Colors.teal,
                    delay: 400.ms)
              ]),
          const SizedBox(height: 20),
          Material(
            color: statsSurface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/admin/ads'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          color: Color(0xFF93C5FD), size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة البنرات الإعلانية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'رفع وتعديل وحذف البنرات وضبط مدة العرض',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded,
                        color: Colors.white.withValues(alpha: 0.35)),
                  ],
                ),
              ),
            ),
          ),
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
    final name = productDisplayTitle(product);
    final price = product['price'] ?? 0;
    final status = product['status'] ?? 'pending';
    final listed = status == 'approved' || status == 'active';
    final suspended = status == 'suspended';
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: Row(children: [
          Icon(
              listed
                  ? Icons.check_circle
                  : suspended
                      ? Icons.pause_circle_outline
                      : Icons.pending,
              color: listed
                  ? Colors.green
                  : suspended
                      ? Colors.deepPurpleAccent
                      : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text(formatIQD(price is num ? price : num.tryParse('$price')),
                    style: const TextStyle(color: Colors.green))
              ])),
          Text(
              listed
                  ? 'معروض'
                  : suspended
                      ? 'معلّق'
                      : status == 'pending'
                          ? 'قيد المراجعة'
                          : 'غير معروض',
              style: TextStyle(
                  color: listed
                      ? Colors.green
                      : suspended
                          ? Colors.deepPurpleAccent
                          : Colors.orange,
                  fontSize: 12))
        ])).animate().fadeIn();
  }

  Widget _buildUsersManagement() {
    final list = _memberListProfiles;
    if (list.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.phone_android_rounded, size: 80, color: Colors.grey[700]),
        const SizedBox(height: 16),
        Text(
          _users.isEmpty
              ? 'لا يوجد مستخدمين حالياً'
              : 'لا يظهر إلا الأعضاء المسجّلون برقم هاتف',
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ]));
    }
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, index) {
          final user = list[index];
          final role = user['role'] ?? 'user';
          final isBanned = user['is_banned'] ?? false;
          final name = (user['full_name']?.toString().trim().isNotEmpty == true)
              ? user['full_name'].toString()
              : 'مستخدم';
          final phone = user['phone']?.toString() ?? '';
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
                            if (phone.isNotEmpty)
                              Text(phone,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 13))
                          ])),
                      _buildRoleBadge(role.toString(), isBanned)
                    ]),
                    const Divider(height: 32, color: Colors.grey),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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

  /// مروجون فقط — الضغط يفتح إدارة منتجات كل مروج
  Widget _buildPromotersManagement() {
    final requests = _upgradeRequests;
    final promoters = _promoterProfiles;

    Future<void> approveUpgrade(String uid) async {
      await _updateUser(uid, {
        'role': 'promoter',
        'merchant_status': 'approved',
        'account_status': 'approved',
      });
    }

    Future<void> rejectUpgrade(String uid) async {
      await _updateUser(uid, {
        'merchant_status': 'rejected',
      });
    }

    if (requests.isEmpty && promoters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات ترقية ولا مروجون حالياً',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (requests.isNotEmpty) ...[
          const Text(
            'طلبات ترقية إلى تاجر',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...requests.map((u) {
            final id = u['id'].toString();
            final name = (u['full_name']?.toString().trim().isNotEmpty == true)
                ? u['full_name'].toString()
                : 'مستخدم';
            final phone = u['phone']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(phone,
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => approveUpgrade(id),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('موافقة'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => rejectUpgrade(id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: const Text('رفض'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (promoters.isNotEmpty) ...[
          const Text(
            'المروجون',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(promoters.length, (index) {
        final u = promoters[index];
        final id = u['id'].toString();
        final name = (u['full_name']?.toString().trim().isNotEmpty == true)
            ? u['full_name'].toString()
            : 'مروج';
        final phone = u['phone']?.toString() ?? '';
        final status = u['account_status']?.toString() ?? '';
        final autoOn = u['auto_approve_products'] == true;
        final productCount = _products
            .where((p) => p['promoter_id']?.toString() == id)
            .length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFF151E32),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/admin/promoter/$id'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFF59E0B),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'م',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (status.isNotEmpty && status != 'approved')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                status == 'pending'
                                    ? 'قيد المراجعة'
                                    : 'الحالة: $status',
                                style: TextStyle(
                                  color: Colors.amber[200],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                '$productCount منتج',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                              if (autoOn) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'موافقة تلقائية',
                                    style: TextStyle(
                                      color: Colors.lightGreenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: (index * 40).ms);
          }),
        ],
      ],
    );
  }

  Widget _buildPlatesManagement() {
    if (_plates.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text('لا توجد طلبات لوحات حالياً',
            style: TextStyle(color: Colors.grey, fontSize: 16))
      ]));
    }
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _plates.length,
        itemBuilder: (ctx, index) {
          final plate = _plates[index];
          final images = plate['images'];
          final imageUrl = (images is List && images.isNotEmpty)
              ? images[0].toString()
              : null;
          final title = plate['plate_number'] ?? 'لوحة';
          final gov = plate['governorate']?.toString() ?? '';
          final price = plate['price'];
          final phone = plate['seller_phone']?.toString() ?? '';
          final status = plate['status'] ?? 'pending';
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
                          child: const Icon(Icons.confirmation_number,
                              color: Colors.white, size: 40))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (gov.isNotEmpty)
                              Text(gov,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('الهاتف: $phone',
                                style: TextStyle(
                                    color: Colors.grey[300], fontSize: 12)),
                            if (price != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  formatIQD(price is num
                                      ? price
                                      : num.tryParse('$price')),
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ),
                            const SizedBox(height: 12),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (status == 'pending')
                                    ElevatedButton(
                                        onPressed: () => _updatePlateStatus(
                                            plate['id'], 'approved'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8)),
                                        child: const Text('موافقة',
                                            style: TextStyle(fontSize: 12))),
                                  if (status == 'approved')
                                    ElevatedButton(
                                        onPressed: () => _updatePlateStatus(
                                            plate['id'], 'pending'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8)),
                                        child: const Text('إخفاء',
                                            style: TextStyle(fontSize: 12))),
                                  const SizedBox(width: 8),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () => _updatePlateStatus(
                                          plate['id'], 'deleted'))
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[400], fontSize: 12.5))
          ]),
    ).animate().fadeIn(delay: delay).scale(begin: const Offset(0.8, 0.8));
  }
}
