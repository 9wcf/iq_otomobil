import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/catalog_provider.dart';
import 'package:go_router/go_router.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});
  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _wheelCtrl = TextEditingController();
  String? _brandId, _categoryId, _condition;
  List<File> _images = [];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    setState(() => _images = picked.map((f) => File(f.path)).toList());
  }

  void _submit() {
    if (!_formKey.currentState!.validate() ||
        _images.isEmpty ||
        _brandId == null ||
        _categoryId == null ||
        _condition == null) return;
    ref
        .read(productUploadProvider.notifier)
        .upload(
          brandId: _brandId!,
          categoryId: _categoryId!,
          model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
          condition: _condition!,
          wheelType:
              _wheelCtrl.text.trim().isEmpty ? null : _wheelCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          images: _images,
        )
        .then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم رفع القطعة بنجاح، بانتظار موافقة الأدمن')));
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(productUploadProvider);
    final isLoading = uploadState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة قطعة جديدة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DropdownField('الماركة', brandsProvider, (v) => _brandId = v),
            const SizedBox(height: 12),
            _DropdownField('القسم', categoriesProvider, (v) => _categoryId = v),
            const SizedBox(height: 12),
            TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                    labelText: 'الموديل / سنة الصنع',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _condition,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'used', child: Text('مستعمل')),
                DropdownMenuItem(value: 'refurbished', child: Text('مجدد')),
              ],
              onChanged: (v) => setState(() => _condition = v),
              decoration: const InputDecoration(
                  labelText: 'الحالة', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _wheelCtrl,
                decoration: const InputDecoration(
                    labelText: 'نوع العجلة / القياس',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'وصف القطعة', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library),
              label: Text('${_images.length} صور تم اختيارها'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('رفع القطعة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _DropdownField(
    String label,
    AutoDisposeFutureProvider<List<Map<String, dynamic>>> provider,
    void Function(String?) onChanged,
  ) {
    return Consumer(
      builder: (context, ref, _) => ref.watch(provider).when(
            data: (items) => DropdownButtonFormField<String>(
              items: (items as List)
                  .map((i) => DropdownMenuItem(
                      value: i['id'] as String, child: Text(i['name'])))
                  .toList(),
              onChanged: onChanged,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            loading: () => DropdownButtonFormField<String>(
              items: const [],
              onChanged: null,
              decoration: const InputDecoration(
                labelText: 'جاري التحميل...',
                border: OutlineInputBorder(),
              ),
            ),
            error: (_, __) => DropdownButtonFormField<String>(
              items: const [],
              onChanged: null,
              decoration: const InputDecoration(
                labelText: 'خطأ في التحميل',
                border: OutlineInputBorder(),
              ),
            ),
          ),
    );
  }
}
