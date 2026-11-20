import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:iq_otomobil/features/ads/data/ad_repository.dart';

class AdManagementScreen extends StatefulWidget {
  const AdManagementScreen({super.key});

  @override
  State<AdManagementScreen> createState() => _AdManagementScreenState();
}

class _AdManagementScreenState extends State<AdManagementScreen> {
  final _repo = AdRepository();
  final _picker = ImagePicker();

  bool _loading = true;
  List<Map<String, dynamic>> _ads = [];
  int _intervalSeconds = 5;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadAds();
    _loadInterval();
  }

  void _checkPermission() {
    final user = SupabaseService.currentUserInfo;
    if (user == null) return;
    SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle()
        .then((profile) {
      final role = profile?['role'] as String?;
      if (role != 'admin') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('❌ غير مصرح لك'),
            backgroundColor: Colors.red,
          ));
        });
      }
    });
  }

  Future<void> _loadAds() async {
    setState(() => _loading = true);
    try {
      final results = await _repo.getAllAds();
      if (!mounted) return;
      setState(() {
        _ads = results;
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

  Future<void> _loadInterval() async {
    try {
      final v = await _repo.getBannerIntervalSeconds();
      if (!mounted) return;
      setState(() => _intervalSeconds = v);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveInterval() async {
    try {
      setState(() => _loading = true);
      await _repo.setBannerIntervalSeconds(_intervalSeconds);
      await _loadAds();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ تم حفظ مدة انتقال البنرات'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addImageAds() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      String? linkUrl;
      DateTime? endDate;

      final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          final linkCtrl = TextEditingController();
          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: const Text('إعدادات البنر'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رابط عند الضغط (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                                initialDate: endDate ?? DateTime.now(),
                              );
                              if (pickedDate == null) return;
                              setStateDialog(() => endDate = pickedDate);
                            },
                            icon: const Icon(Icons.event),
                            label: Text(
                              endDate == null
                                  ? 'تاريخ انتهاء (اختياري)'
                                  : 'ينتهي: ${endDate!.toIso8601String().split('T').first}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (endDate != null)
                          IconButton(
                            onPressed: () => setStateDialog(() => endDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    linkUrl = linkCtrl.text.trim().isEmpty
                        ? null
                        : linkCtrl.text.trim();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('متابعة'),
                ),
              ],
            ),
          );
        },
      );

      if (ok != true) return;

      setState(() => _loading = true);
      for (final x in picked) {
        final url = await _repo.uploadAdImage(File(x.path));
        await _repo.createAd(
          // Must match DB check constraint on advertisements.type (see advertisements_type_check)
          type: 'banner',
          position: AdRepository.kHomeBannerPosition,
          imageUrl: url,
          linkUrl: linkUrl,
          endDate: endDate,
        );
      }
      await _loadAds();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ تم إضافة البنرات'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> ad, bool value) async {
    try {
      await _repo.updateAdStatus(ad['id'], value);
      await _loadAds();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAd(Map<String, dynamic> ad) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البنر'),
        content: const Text('هل تريد حذف هذا البنر؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repo.deleteAd(ad['id']);
      await _loadAds();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ تم الحذف'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        title: const Text(
          'إدارة البنرات الإعلانية',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadAds,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addImageAds,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('إضافة صور'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مدة الانتقال بين البنرات',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'البنر يظهر في الصفحة الرئيسية فقط (موضع واحد).',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _intervalSeconds,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المدة (ثواني)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color(0xFF0F172A),
                        ),
                        dropdownColor: const Color(0xFF0F172A),
                        items: const [
                          DropdownMenuItem(
                            value: 3,
                            child:
                                Text('3', style: TextStyle(color: Colors.white)),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child:
                                Text('5', style: TextStyle(color: Colors.white)),
                          ),
                          DropdownMenuItem(
                            value: 10,
                            child: Text('10',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _intervalSeconds = v ?? 5),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saveInterval,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('حفظ'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_ads.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'لا توجد بنرات بعد',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  ...List.generate(_ads.length, (i) {
                    final ad = _ads[i];
                    final isActive = ad['is_active'] == true;
                    final imageUrl = ad['image_url']?.toString();
                    final link = ad['link_url']?.toString();
                    final endDateStr = ad['end_date']?.toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive
                              ? Colors.green.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                imageUrl,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  height: 140,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'البنر الرئيسي',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: isActive,
                                      onChanged: (v) => _toggleActive(ad, v),
                                      activeColor: Colors.green,
                                    ),
                                  ],
                                ),
                                if (link != null && link.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'الرابط: $link',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (endDateStr != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'ينتهي: ${endDateStr.split('T').first}',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _deleteAd(ad),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    label: const Text(
                                      'حذف',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

