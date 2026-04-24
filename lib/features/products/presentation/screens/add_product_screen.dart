import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _wheelCtrl = TextEditingController();
  final _yearFromCtrl = TextEditingController();
  final _yearToCtrl = TextEditingController();

  String? _selectedBrand;
  String? _selectedCategory;
  String? _selectedCondition;

  List<XFile> _selectedImages = [];
  List<Uint8List> _imagePreviewBytes = [];
  bool _isUploading = false;

  final List<Map<String, String>> _brands = [
    {'id': '1', 'name': 'تويوتا'},
    {'id': '2', 'name': 'هيونداي'},
    {'id': '3', 'name': 'كيا'},
    {'id': '4', 'name': 'نيسان'},
    {'id': '5', 'name': 'مرسيدس'},
    {'id': '6', 'name': 'بي ام دبليو'},
    {'id': '7', 'name': 'مازدا'},
    {'id': '8', 'name': 'فورد'},
  ];

  final List<Map<String, String>> _categories = [
    {'id': '1', 'name': 'محركات'},
    {'id': '2', 'name': 'فرامل'},
    {'id': '3', 'name': 'كهرباء'},
    {'id': '4', 'name': 'تبريد'},
    {'id': '5', 'name': 'هيكل'},
    {'id': '6', 'name': 'زجاج'},
    {'id': '7', 'name': 'إطارات'},
    {'id': '8', 'name': 'فلتر'},
    {'id': '9', 'name': 'بطارية'},
    {'id': '10', 'name': 'تعليق'},
  ];

  final List<String> _conditions = ['جديد', 'مستعمل', 'مجدد'];

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFiles.isNotEmpty) {
        _selectedImages = pickedFiles;

        List<Uint8List> previewBytes = [];
        for (var file in pickedFiles) {
          final bytes = await file.readAsBytes();
          previewBytes.add(bytes);
        }

        if (mounted) {
          setState(() {
            _imagePreviewBytes = previewBytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الصور: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imagePreviewBytes.removeAt(index);
    });
  }

  Widget _buildImagePreview(int index) {
    return _imagePreviewBytes.isNotEmpty && index < _imagePreviewBytes.length
        ? Image.memory(
            _imagePreviewBytes[index],
            height: 120,
            width: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 120,
                width: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              );
            },
          )
        : Container(
            height: 120,
            width: 120,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported),
          );
  }

  Future<String?> _uploadImage(
      XFile imageFile, String userId, int index) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomId = DateTime.now().microsecondsSinceEpoch;
      final fileName = '${userId}_${timestamp}_${randomId}_$index.jpg';
      final filePath = 'products/$fileName';

      print('بدء رفع الصورة: $filePath');

      await SupabaseService.client.storage
          .from('products')
          .uploadBinary(filePath, bytes);

      print('تم رفع الصورة بنجاح');

      final publicUrl = SupabaseService.client.storage
          .from('products')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('خطأ في رفع الصورة $index: $e');
      rethrow;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار صورة واحدة على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final snackBar = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('جاري رفع الصور...'),
            ],
          ),
          duration: Duration(days: 1),
        ),
      );

      final imageUrls = <String>[];

      for (int i = 0; i < _selectedImages.length; i++) {
        final url = await _uploadImage(_selectedImages[i], user.id, i);
        if (url != null) {
          imageUrls.add(url);
        }
      }

      snackBar.close();

      if (imageUrls.isEmpty) {
        throw Exception('فشل في رفع الصور');
      }

      final brandName = _brands.firstWhere(
        (b) => b['id'] == _selectedBrand,
        orElse: () => {'name': 'غير محدد'},
      )['name'];

      final categoryName = _categories.firstWhere(
        (c) => c['id'] == _selectedCategory,
        orElse: () => {'name': 'غير محدد'},
      )['name'];

      final conditionValue = _selectedCondition == 'جديد'
          ? 'new'
          : _selectedCondition == 'مستعمل'
              ? 'used'
              : 'refurbished';

      // ✅ إزالة حقل 'name' نهائياً
      final productData = {
        'promoter_id': user.id,
        'brand_id': brandName,
        'category_id': categoryName,
        'model': _modelCtrl.text.trim(),
        'condition': conditionValue,
        'wheel_type':
            _wheelCtrl.text.trim().isEmpty ? null : _wheelCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'year_from': int.tryParse(_yearFromCtrl.text),
        'year_to': int.tryParse(_yearToCtrl.text),
        'images': imageUrls,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      };

      print('إدخال بيانات المنتج: $productData');

      await SupabaseService.client.from('products').insert(productData);

      print('✅ تم إدخال المنتج بنجاح وسيظهر مباشرة في الشاشة الرئيسية!');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('✅ تم إضافة المنتج بنجاح وسيظهر في الشاشة الرئيسية مباشرة!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      print('❌ خطأ في رفع المنتج: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة منتج جديد'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isUploading ? null : _submit,
            tooltip: 'حفظ المنتج',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text('معلومات المنتج',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم القطعة *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) => v!.isEmpty ? 'اسم القطعة مطلوب' : null,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedBrand,
                        decoration: const InputDecoration(
                          labelText: 'الماركة *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.branding_watermark),
                        ),
                        items: _brands
                            .map((b) => DropdownMenuItem(
                                  value: b['id'],
                                  child: Text(b['name']!),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedBrand = v),
                        validator: (v) => v == null ? 'الماركة مطلوبة' : null,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'القسم *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                  value: c['id'],
                                  child: Text(c['name']!),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        validator: (v) => v == null ? 'القسم مطلوب' : null,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الموديل / سنة الصنع',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          helperText: 'مثال: 2020 أو كامري 2020',
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCondition,
                        decoration: const InputDecoration(
                          labelText: 'الحالة *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info_outline),
                        ),
                        items: _conditions
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCondition = v),
                        validator: (v) => v == null ? 'الحالة مطلوبة' : null,
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text('سنوات التوافق مع الموديل',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('حدد السنوات التي تتوافق معها هذه القطعة',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yearFromCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'من سنة',
                              border: OutlineInputBorder(),
                              hintText: '2015',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _yearToCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إلى سنة',
                              border: OutlineInputBorder(),
                              hintText: '2020',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _wheelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نوع العجلة / القياس (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tire_repair),
                    helperText: 'مثال: 16 بوصة، 205/55 R16',
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 700.ms),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر (دولار) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'السعر مطلوب';
                    if (double.tryParse(v) == null) return 'سعر غير صحيح';
                    return null;
                  },
                ),
              ),
            ).animate().fadeIn(delay: 800.ms),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'الوصف التفصيلي',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    helperText:
                        'اكتب تفاصيل إضافية عن القطعة، حالتها، ضمانها، إلخ...',
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 900.ms),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.photo_library, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Text('صور المنتج *',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_imagePreviewBytes.isNotEmpty)
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagePreviewBytes.length,
                          itemBuilder: (ctx, i) => Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildImagePreview(i),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                top: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_camera),
                      label: Text('اختر صور (${_selectedImages.length}/10)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (_selectedImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'تم اختيار ${_selectedImages.length} صورة',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 1000.ms),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _submit,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isUploading ? 'جاري الرفع...' : 'حفظ المنتج',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 1100.ms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _modelCtrl.dispose();
    _wheelCtrl.dispose();
    _yearFromCtrl.dispose();
    _yearToCtrl.dispose();
    super.dispose();
  }
}
