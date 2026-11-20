import 'package:flutter/material.dart';
import 'package:iq_otomobil/core/services/app_runtime_controls_service.dart';

class AdminAppControlsScreen extends StatefulWidget {
  const AdminAppControlsScreen({super.key});

  @override
  State<AdminAppControlsScreen> createState() => _AdminAppControlsScreenState();
}

class _AdminAppControlsScreenState extends State<AdminAppControlsScreen> {
  final _service = const AppRuntimeControlsService();
  final _maintenanceMessageCtrl = TextEditingController();
  final _forceUpdateMessageCtrl = TextEditingController();
  final _updateUrlAndroidCtrl = TextEditingController();
  final _updateUrlIosCtrl = TextEditingController();
  final _minBuildCtrl = TextEditingController(text: '1');

  bool _loading = true;
  bool _saving = false;
  bool _maintenanceMode = false;
  bool _forceUpdateEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maintenanceMessageCtrl.dispose();
    _forceUpdateMessageCtrl.dispose();
    _updateUrlAndroidCtrl.dispose();
    _updateUrlIosCtrl.dispose();
    _minBuildCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final controls = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _maintenanceMode = controls.maintenanceMode;
        _forceUpdateEnabled = controls.forceUpdateEnabled;
        _maintenanceMessageCtrl.text = controls.maintenanceMessage;
        _forceUpdateMessageCtrl.text = controls.forceUpdateMessage;
        _updateUrlAndroidCtrl.text = controls.updateUrl ?? '';
        _updateUrlIosCtrl.text = controls.updateUrlIos ?? '';
        _minBuildCtrl.text = controls.minSupportedBuild.toString();
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

  Future<void> _save() async {
    final minBuild = int.tryParse(_minBuildCtrl.text.trim()) ?? 1;
    setState(() => _saving = true);
    try {
      await _service.save(
        AppRuntimeControls(
          maintenanceMode: _maintenanceMode,
          forceUpdateEnabled: _forceUpdateEnabled,
          minSupportedBuild: minBuild < 1 ? 1 : minBuild,
          maintenanceMessage: _maintenanceMessageCtrl.text.trim().isEmpty
              ? AppRuntimeControls.defaults.maintenanceMessage
              : _maintenanceMessageCtrl.text.trim(),
          forceUpdateMessage: _forceUpdateMessageCtrl.text.trim().isEmpty
              ? AppRuntimeControls.defaults.forceUpdateMessage
              : _forceUpdateMessageCtrl.text.trim(),
          updateUrl: _updateUrlAndroidCtrl.text.trim().isEmpty
              ? null
              : _updateUrlAndroidCtrl.text.trim(),
          updateUrlIos: _updateUrlIosCtrl.text.trim().isEmpty
              ? null
              : _updateUrlIosCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ إعدادات التحكم بالتطبيق'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        title: const Text(
          'التحكم بتطبيق المستخدم',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _maintenanceMode,
                  onChanged: (v) => setState(() => _maintenanceMode = v),
                  activeColor: Colors.orangeAccent,
                  title: const Text(
                    'تفعيل وضع الصيانة',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'عند التفعيل سيتم منع استخدام تطبيق المستخدم مؤقتا.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _maintenanceMessageCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'رسالة الصيانة',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  value: _forceUpdateEnabled,
                  onChanged: (v) => setState(() => _forceUpdateEnabled = v),
                  activeColor: Colors.redAccent,
                  title: const Text(
                    'تفعيل التحديث الإجباري',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'عند التفعيل سيظهر للمستخدم شاشة تحديث إجباري.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _forceUpdateMessageCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'رسالة التحديث الإجباري',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _updateUrlAndroidCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'رابط Google Play (أندرويد)',
                    hintText: 'https://play.google.com/store/apps/...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _updateUrlIosCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'رابط App Store (آيفون)',
                    hintText: 'https://apps.apple.com/app/...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _minBuildCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'أقل Build مطلوب (رقم بعد + في pubspec)',
                    hintText: 'مثال: الإصدار 1.0.0+5 → ضع 5',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
                  ),
                ),
              ],
            ),
    );
  }
}
