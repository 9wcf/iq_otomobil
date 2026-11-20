import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/auth_provider.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/promoter_hub_screen.dart';
import 'package:iq_otomobil/features/orders/presentation/screens/promoter_profile_body.dart';

/// التطبيق التجاري: الرئيسية + ملف شخصي وشريط تنقل سفلي.
class PromoterMainScreen extends StatefulWidget {
  const PromoterMainScreen({super.key});

  @override
  State<PromoterMainScreen> createState() => _PromoterMainScreenState();
}

class _PromoterMainScreenState extends State<PromoterMainScreen> {
  int _tab = 0;
  final GlobalKey<PromoterHubBodyState> _hubKey = GlobalKey();
  bool _loadingGate = true;
  String _role = 'user';
  String _merchantStatus = 'none';
  String _accountStatus = 'approved';
  String _fullName = '';
  String _phone = '';
  bool _sentOnce = false;
  final TextEditingController _nameCtrl = TextEditingController();
  DateTime? _lastFetchAt;
  String? _lastFetchError;
  Future<int>? _pendingOrdersFuture;

  @override
  void initState() {
    super.initState();
    _refreshGate(showLoading: true);
    _pendingOrdersFuture = _fetchPendingOrdersCount();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isMerchantApproved {
    final r = _role.trim();
    if (r == 'admin') return true;
    if (r != 'promoter') return false;
    if (_merchantStatus.trim() != 'approved') return false;
    return _accountStatus.trim() == 'approved';
  }

  Future<void> _refreshGate({required bool showLoading}) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    try {
      if (mounted && showLoading) setState(() => _loadingGate = true);
      final row = await SupabaseService.client
          .from('profiles')
          .select('role, merchant_status, account_status, full_name, phone')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _role = (row?['role']?.toString() ?? 'user').trim();
        _merchantStatus =
            (row?['merchant_status']?.toString() ?? 'none').trim();
        _accountStatus =
            (row?['account_status']?.toString() ?? 'approved').trim();
        _fullName = (row?['full_name']?.toString() ?? '').trim();
        _phone = (row?['phone']?.toString() ?? '').trim();
        if (_nameCtrl.text.trim().isEmpty && _fullName.isNotEmpty) {
          _nameCtrl.text = _fullName;
        }
        _loadingGate = false;
        _lastFetchAt = DateTime.now();
        _lastFetchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGate = false;
        _lastFetchAt = DateTime.now();
        _lastFetchError = e.toString();
      });
    }
  }

  Future<int> _fetchPendingOrdersCount() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return 0;
    final res = await SupabaseService.client
        .from('orders')
        .select('id')
        .eq('promoter_id', uid)
        .inFilter('status', ['pending', 'pending_promoter_review']);
    return (res as List).length;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);

    // Gate: لا يسمح بالدخول للوحة التاجر إلا بعد الموافقة
    if (_loadingGate) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: Colors.lightBlueAccent),
        ),
      );
    }

    if (!_isMerchantApproved) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: bg,
          foregroundColor: Colors.white,
          title: const Text('تفعيل حساب التاجر',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () async {
                await _refreshGate(showLoading: true);
                if (!mounted) return;
                final uid = SupabaseService.currentUserId ?? '—';
                final msg = _lastFetchError != null
                    ? '❌ فشل التحديث: ${_lastFetchError!}'
                    : '✅ تم التحديث\nuid=$uid\nrole=$_role\nmerchant=$_merchantStatus\naccount=$_accountStatus';
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor:
                        _lastFetchError == null ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(authActionProvider.notifier);

            String title;
            String body;
            bool showSend = false;
            bool showWait = false;
            bool showRejected = false;
            final needsName = _fullName.isEmpty &&
                (_merchantStatus == 'none' || _merchantStatus.isEmpty);

            if (_merchantStatus == 'pending') {
              title = 'بانتظار موافقة الإدارة';
              body =
                  'تم إرسال طلب الترقية.\nسيتم تفعيل حسابك بعد موافقة الإدارة.';
              showWait = true;
            } else if (_merchantStatus == 'rejected') {
              title = 'تم رفض الطلب';
              body = 'تم رفض طلب الترقية.\nيرجى التواصل مع الإدارة.';
              showRejected = true;
            } else {
              title = 'حسابك غير مرقّى كتاجر';
              body =
                  'للاستخدام كتاجر يجب إرسال طلب ترقية.\nلن تتمكن من الدخول حتى تتم الموافقة.';
              showSend = true;
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_phone.isNotEmpty) ...[
                          Text(_phone,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        if (needsName) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'الاسم',
                              hintText: 'اكتب اسمك حتى يظهر في لوحة الإدارة',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (showSend)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                final name = _nameCtrl.text.trim();
                                await notifier.requestUpgradeToMerchant(
                                  fullName: name.isEmpty ? null : name,
                                );
                                if (!mounted) return;
                                setState(() {
                                  _merchantStatus = 'pending';
                                  _sentOnce = true;
                                  if (name.isNotEmpty) _fullName = name;
                                });
                                await _refreshGate(showLoading: false);
                              },
                              child: const Text('إرسال طلب ترقية'),
                            ),
                          ),
                        if (showWait ||
                            (_sentOnce && _merchantStatus == 'pending')) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _refreshGate(showLoading: false);
                                if (!mounted) return;
                                final uid = SupabaseService.currentUserId ?? '—';
                                final msg = _lastFetchError != null
                                    ? '❌ فشل التحديث: ${_lastFetchError!}'
                                    : '✅ تم التحديث\nuid=$uid\nrole=$_role\nmerchant=$_merchantStatus\naccount=$_accountStatus';
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: _lastFetchError == null
                                        ? Colors.green
                                        : Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('تحديث الحالة'),
                            ),
                          ),
                        ],
                        if (showRejected) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                final name = _nameCtrl.text.trim();
                                await notifier.requestUpgradeToMerchant(
                                  fullName: name.isEmpty ? null : name,
                                );
                                if (!mounted) return;
                                setState(() {
                                  _merchantStatus = 'pending';
                                  _sentOnce = true;
                                  if (name.isNotEmpty) _fullName = name;
                                });
                              },
                              child: const Text('إعادة إرسال طلب'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (_lastFetchAt != null || _lastFetchError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _lastFetchError != null
                                  ? 'آخر خطأ: ${_lastFetchError!}'
                                  : 'آخر تحديث: ${_lastFetchAt!.hour.toString().padLeft(2, '0')}:${_lastFetchAt!.minute.toString().padLeft(2, '0')}:${_lastFetchAt!.second.toString().padLeft(2, '0')}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _lastFetchError == null
                                    ? Colors.grey[600]
                                    : Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await notifier.logout();
                              if (!context.mounted) return;
                              context.go('/auth');
                            },
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.red),
                            label: const Text('تسجيل الخروج',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: _tab == 0
          ? AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: bg,
              foregroundColor: Colors.white,
              title: const Text(
                'لوحة المروج',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(132),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.push('/add-product'),
                              icon: const Icon(Icons.add_business_rounded,
                                  size: 22),
                              label: const Text(
                                'إضافة منتج',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FutureBuilder<int>(
                              future: _pendingOrdersFuture,
                              builder: (context, snap) {
                                final count = snap.data ?? 0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () async {
                                          await context.push(
                                              '/promoter/requests');
                                          if (!mounted) return;
                                          setState(() {
                                            _pendingOrdersFuture =
                                                _fetchPendingOrdersCount();
                                          });
                                        },
                                        icon: const Icon(
                                            Icons.receipt_long_rounded,
                                            size: 22),
                                        label: const Text(
                                          'طلبات المروج',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                        style: FilledButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        right: -6,
                                        top: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.25)),
                                          ),
                                          child: Text(
                                            count > 99 ? '99+' : '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/promoter/my-products'),
                          icon: const Icon(Icons.inventory_2_outlined, size: 22),
                          label: const Text(
                            'منتجاتي',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: bg,
              foregroundColor: Colors.white,
              title: const Text(
                'ملفي الشخصي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
      body: IndexedStack(
        index: _tab,
        children: [
          PromoterHubBody(key: _hubKey),
          const PromoterProfileBody(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.amber.withValues(alpha: 0.28),
          iconTheme: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white, size: 28);
            }
            return IconThemeData(color: Colors.grey[400], size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.white,
              );
            }
            return TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            );
          }),
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: const Color(0xFF1E293B),
          surfaceTintColor: Colors.transparent,
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            setState(() => _tab = i);
            if (i == 0) {
              _hubKey.currentState?.refresh();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}
