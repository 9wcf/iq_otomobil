import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:iq_otomobil/features/products/data/car_brands_catalog.dart';
import 'package:iq_otomobil/features/products/data/car_models_catalog.dart';
import 'package:iq_otomobil/features/catalog/data/shared_spare_categories.dart';
import 'package:iq_otomobil/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:iq_otomobil/features/auth/presentation/providers/user_profile_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.editProductId});

  /// عند التمرير يُحمّل المنتج للتعديل (حقوق المروج تُتحقق من الخادم).
  final String? editProductId;

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

  String? _selectedBrandId;
  String? _selectedCategory;
  String? _selectedCondition;
  String? _selectedModelType;
  final _customModelCtrl = TextEditingController();

  List<XFile> _selectedImages = [];
  List<Uint8List> _imagePreviewBytes = [];
  bool _isUploading = false;

  /// صور قائمة مسبقاً عند التعديل (روابط) — يمكن إزالة بعضها قبل الحفظ.
  List<String> _keptExistingImageUrls = [];

  bool _loadingEdit = false;

  /// قيمة `promoter_id` كما في الصف (يجب استخدامها في التحديث لتطابق RLS والفلتر).
  String? _rowPromoterId;

  bool get _isEditing => widget.editProductId != null;

  final List<String> _conditions = [
    'جديد',
    'مستعمل',
    'مجدد',
    'وارد امريكي',
    'وارد كوري',
  ];

  static const int _maxImages = 10;

  int get _totalImageCount =>
      _keptExistingImageUrls.length + _selectedImages.length;

  @override
  void initState() {
    super.initState();
    if (widget.editProductId == null) {
      _selectedCondition = 'جديد';
    }
    if (widget.editProductId != null) {
      _loadingEdit = true;
      _loadProductForEdit();
    }
  }

  Future<void> _loadProductForEdit() async {
    final id = widget.editProductId;
    if (id == null) return;

    try {
      final user = SupabaseService.currentUserInfo;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final row = await SupabaseService.client
          .from('products')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (row == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المنتج غير موجود')),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      final rowPromoter = row['promoter_id']?.toString();
      final sessionUid = SupabaseService.client.auth.currentUser?.id;
      bool canEdit = rowPromoter == user.id ||
          (sessionUid != null && rowPromoter == sessionUid);
      if (!canEdit) {
        try {
          final role = await ref.read(userProfileRoleProvider.future);
          if (role == 'admin') canEdit = true;
        } catch (_) {}
      }
      if (!canEdit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن تعديل هذا المنتج')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final images = row['images'];
      final urls = <String>[];
      if (images is List) {
        for (final x in images) {
          final s = x?.toString();
          if (s != null && s.isNotEmpty) urls.add(s);
        }
      }

      final brand = brandByStorageLabel(row['brand_id']?.toString());

      String? catId;
      final rawCat = row['category_id']?.toString();
      if (rawCat != null) {
        for (final c in kSharedSpareCategories) {
          if (c.id == rawCat || c.name == rawCat) {
            catId = c.id;
            break;
          }
        }
      }

      final cond = row['condition']?.toString();
      String condAr;
      switch (cond) {
        case 'new':
          condAr = 'جديد';
          break;
        case 'used':
          condAr = 'مستعمل';
          break;
        case 'refurbished':
          condAr = 'مجدد';
          break;
        case 'american_import':
          condAr = 'وارد امريكي';
          break;
        case 'korean_import':
          condAr = 'وارد كوري';
          break;
        default:
          condAr = (cond != null && _conditions.contains(cond))
              ? cond
              : 'جديد';
      }

      final rawPiece = row['piece_name']?.toString().trim();
      final rawModel = row['model']?.toString() ?? '';

      final price = row['price'];
      final yf = row['year_from'];
      final yt = row['year_to'];

      if (!mounted) return;
      setState(() {
        if (rawPiece != null && rawPiece.isNotEmpty) {
          _nameCtrl.text = rawPiece;
          _modelCtrl.text = rawModel;
        } else {
          // بيانات قديمة: الاسم والموديل كانا مدمجين في model فقط
          _nameCtrl.text = rawModel;
          _modelCtrl.text = rawModel;
        }
        _descCtrl.text = row['description']?.toString() ?? '';
        final priceNum =
            price is num ? price : num.tryParse(price?.toString() ?? '');
        _priceCtrl.text =
            priceNum != null ? _groupDigits(priceNum.round().toString()) : '';
        _wheelCtrl.text = row['wheel_type']?.toString() ?? '';
        _yearFromCtrl.text = yf != null ? '$yf' : '';
        _yearToCtrl.text = yt != null ? '$yt' : '';
        _selectedBrandId = brand?.id;
        _selectedCategory = catId ?? '1';
        _selectedCondition = condAr;
        final matched = matchCatalogModel(brand?.id, rawModel);
        if (matched != null) {
          _selectedModelType = matched;
          _customModelCtrl.clear();
        } else if (rawModel.isNotEmpty) {
          _selectedModelType = kCarModelOtherOption;
          _customModelCtrl.text = rawModel;
        } else {
          _selectedModelType = null;
          _customModelCtrl.clear();
        }
        _modelCtrl.text = rawModel;
        _keptExistingImageUrls = urls;
        _rowPromoterId = rowPromoter;
        _loadingEdit = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المنتج: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? helper,
    Widget? prefixIcon,
  }) {
    final r = BorderRadius.circular(14);
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide:
            BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFiles.isEmpty) return;

      final remaining = _maxImages - _totalImageCount;
      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الحد الأقصى $_maxImages صور')),
          );
        }
        return;
      }

      final toAdd = pickedFiles.take(remaining).toList();
      final previewBytes = <Uint8List>[];
      for (final file in toAdd) {
        previewBytes.add(await file.readAsBytes());
      }

      if (!mounted) return;
      setState(() {
        _selectedImages = [..._selectedImages, ...toAdd];
        _imagePreviewBytes = [..._imagePreviewBytes, ...previewBytes];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الصور: $e')),
        );
      }
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imagePreviewBytes.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _keptExistingImageUrls.removeAt(index);
    });
  }

  Widget _buildImagePreview(int index) {
    if (_imagePreviewBytes.isEmpty || index >= _imagePreviewBytes.length) {
      return Container(
        height: 112,
        width: 112,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported),
      );
    }
    return Image.memory(
      _imagePreviewBytes[index],
      height: 112,
      width: 112,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 112,
        width: 112,
        color: Colors.grey[300],
        child: const Icon(Icons.error_outline),
      ),
    );
  }

  Future<String?> _uploadImage(XFile imageFile, String userId, int index) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomId = DateTime.now().microsecondsSinceEpoch;
    final fileName = '${userId}_${timestamp}_${randomId}_$index.jpg';
    final filePath = 'products/$fileName';

    await SupabaseService.client.storage.from('products').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final url = SupabaseService.client.storage
        .from('products')
        .getPublicUrl(filePath);
    final s = url.trim();
    return s.isEmpty ? null : s;
  }

  bool _isChosenCategoryValid() {
    final v = _selectedCategory?.trim();
    if (v == null || v.isEmpty) return false;
    return kSharedSpareCategories.any((c) => c.id == v);
  }

  static const Map<String, String> _conditionDbValues = {
    'جديد': 'new',
    'مستعمل': 'used',
    'مجدد': 'refurbished',
    'وارد امريكي': 'american_import',
    'وارد كوري': 'korean_import',
  };

  String _conditionDbValue(String? conditionAr) =>
      _conditionDbValues[conditionAr] ?? 'new';

  double _parsedPrice() {
    final digitsOnly = _priceCtrl.text.replaceAll(',', '').trim();
    return double.parse(digitsOnly);
  }

  Future<void> _submit() async {
    if (!_isChosenCategoryValid()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار القسم من القائمة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_totalImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء الإبقاء على صورة واحدة على الأقل أو إضافة صور'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

      ScaffoldMessengerState? sm;
    try {
      final user = SupabaseService.currentUserInfo;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      sm = ScaffoldMessenger.of(context);
      dynamic loadingSnack;
      if (_selectedImages.isNotEmpty) {
        loadingSnack = sm.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('جاري رفع الصور الجديدة…')),
              ],
            ),
            duration: const Duration(days: 1),
          ),
        );
      }

      final imageUrls = <String>[..._keptExistingImageUrls];
      for (var i = 0; i < _selectedImages.length; i++) {
        final url = await _uploadImage(_selectedImages[i], user.id, i);
        if (url != null && url.isNotEmpty) imageUrls.add(url);
      }

      loadingSnack?.close();

      if (imageUrls.isEmpty) throw Exception('لا توجد صور صالحة');

      final brand = brandById(_selectedBrandId);
      final brandValue = brand?.storageLabel ?? 'غير محدد';

      final conditionValue = _conditionDbValue(_selectedCondition);

      final modelText = _resolvedModelText();
      final nameText = _nameCtrl.text.trim();

      final imagesPayload = List<String>.from(imageUrls);

      if (_isEditing && widget.editProductId != null) {
        // يجب أن يطابق promoter_id ما يقرأه الخادم في auth.uid() (JWT sub)،
        // خاصة مع Firebase + mint-supabase-jwt؛ نفضّل معرف جلسة Supabase ثم المخزن في الصف.
        final jwtUid = SupabaseService.client.auth.currentUser?.id;
        final promoterFilter = _rowPromoterId ?? jwtUid ?? user.id;
        final updatedRows = await SupabaseService.client
            .from('products')
            .update({
              'brand_id': brandValue,
              'category_id': _selectedCategory,
              'piece_name': nameText,
              'model': modelText.isEmpty ? null : modelText,
              'condition': conditionValue,
              'wheel_type': _wheelCtrl.text.trim().isEmpty
                  ? null
                  : _wheelCtrl.text.trim(),
              'description': _descCtrl.text.trim(),
              'price': _parsedPrice(),
              'year_from': int.tryParse(_yearFromCtrl.text),
              'year_to': int.tryParse(_yearToCtrl.text),
              'images': imagesPayload,
            })
            .eq('id', widget.editProductId!)
            .eq('promoter_id', promoterFilter)
            .select('id, images');

        final updatedList = List<Map<String, dynamic>>.from(updatedRows as List);
        if (updatedList.isEmpty) {
          throw Exception(
            'لم يُحفظ التعديل (0 صفوف). غالباً سياسة RLS أو عدم تطابق مالك المنتج. جرّب تسجيل الخروج والدخول مجدداً.',
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('تم حفظ التعديلات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final productData = {
          'promoter_id': user.id,
          'brand_id': brandValue,
          'category_id': _selectedCategory,
          'piece_name': nameText,
          'model': modelText.isEmpty ? null : modelText,
          'condition': conditionValue,
          'wheel_type':
              _wheelCtrl.text.trim().isEmpty ? null : _wheelCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'price': _parsedPrice(),
          'year_from': int.tryParse(_yearFromCtrl.text),
          'year_to': int.tryParse(_yearToCtrl.text),
          'images': imageUrls,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        };

        await SupabaseService.client.from('products').insert(productData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('تم إضافة المنتج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // تحديث قوائم الكتالوج/الرئيسية حتى تظهر الصور والحقول الجديدة فوراً
      ref.invalidate(productsProvider);
      for (var p = 0; p < 20; p++) {
        ref.invalidate(latestProductsPageProvider(p));
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      sm?.clearSnackBars();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 560;

    if (_loadingEdit) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: cs.onSurface,
          title: const Text('تعديل المنتج'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF1F5F9),
        foregroundColor: cs.onSurface,
        title: Text(_isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilledButton.tonal(
              onPressed: _isUploading ? null : _submit,
              child: const Icon(Icons.save_rounded, size: 22),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _SectionCard(
              icon: Icons.inventory_2_outlined,
              title: 'معلومات المنتج',
              child: TextFormField(
                controller: _nameCtrl,
                decoration: _fieldDecoration(
                  context,
                  label: 'اسم القطعة *',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'اسم القطعة مطلوب' : null,
              ),
            ).animate().fadeIn(duration: 200.ms),
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _brandField(cs)),
                  const SizedBox(width: 12),
                  Expanded(child: _categoryField(cs)),
                ],
              )
            else ...[
              _brandField(cs),
              const SizedBox(height: 12),
              _categoryField(cs),
            ],
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _modelField(cs)),
                  const SizedBox(width: 12),
                  Expanded(child: _conditionField(cs)),
                ],
              )
            else ...[
              _modelField(cs),
              const SizedBox(height: 12),
              _conditionField(cs),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.date_range_rounded,
              title: 'سنوات التوافق',
              subtitle: 'حدد السنوات التي تنطبق عليها القطعة (اختياري)',
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearFromCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(
                        context,
                        label: 'من سنة',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _yearToCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(
                        context,
                        label: 'إلى سنة',
                        prefixIcon: const Icon(Icons.event_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 220.ms),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.album_outlined,
              title: 'ويل',
              child: TextFormField(
                controller: _wheelCtrl,
                decoration: _fieldDecoration(
                  context,
                  label: 'نوع الويل / القياس (اختياري)',
                  helper: 'مثال: 16 بوصة، 205/55 R16',
                  prefixIcon: const Icon(Icons.circle_outlined),
                ),
              ),
            ).animate().fadeIn(duration: 240.ms),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.payments_outlined,
              title: 'السعر',
              child: TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_ThousandsSeparatorInputFormatter()],
                decoration: _fieldDecoration(
                  context,
                  label: 'السعر (دينار) *',
                  prefixIcon: const Icon(Icons.payments_rounded),
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(',', '').trim();
                  if (digits.isEmpty) return 'السعر مطلوب';
                  final p = double.tryParse(digits);
                  if (p == null) return 'سعر غير صحيح';
                  if (p <= 0) return 'السعر يجب أن يكون أكبر من صفر';
                  return null;
                },
              ),
            ).animate().fadeIn(duration: 260.ms),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.description_outlined,
              title: 'الوصف',
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: _fieldDecoration(
                  context,
                  label: 'الوصف التفصيلي *',
                  helper:
                      'تفاصيل الحالة، الضمان، ملاحظات التركيب…',
                  prefixIcon: const Icon(Icons.article_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'الوصف مطلوب';
                  }
                  return null;
                },
              ),
            ).animate().fadeIn(duration: 280.ms),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.photo_library_outlined,
              title: 'صور المنتج',
              accent: cs.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_keptExistingImageUrls.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _keptExistingImageUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _keptExistingImageUrls[i],
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 112,
                                  height: 112,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Material(
                                color: Colors.black87,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                  onPressed: () => _removeExistingImage(i),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_keptExistingImageUrls.isNotEmpty &&
                      _imagePreviewBytes.isNotEmpty)
                    const SizedBox(height: 10),
                  if (_imagePreviewBytes.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagePreviewBytes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImagePreview(i),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Material(
                                color: Colors.black87,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                  onPressed: () => _removeNewImage(i),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_keptExistingImageUrls.isNotEmpty ||
                      _imagePreviewBytes.isNotEmpty)
                    const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: _isUploading ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(
                      'اختر الصور ($_totalImageCount/$_maxImages)',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isUploading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded),
                        const SizedBox(width: 10),
                        Text(
                          _isEditing ? 'حفظ التعديلات' : 'حفظ المنتج',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _brandField(ColorScheme cs) {
    return _SectionCard(
      icon: Icons.directions_car_outlined,
      title: 'الماركة',
      subtitle: 'اختياري · عربي · English',
      child: DropdownButtonFormField<String>(
        // Controlled selection; `initialValue` alone does not track updates on all Flutter versions.
        // ignore: deprecated_member_use
        value: _selectedBrandId,
        hint: Text(
          'بدون ماركة محددة',
          style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.85)),
        ),
        decoration: _fieldDecoration(
          context,
          label: 'الماركة',
          prefixIcon: Icon(Icons.local_offer_outlined, color: cs.primary),
        ),
        isExpanded: true,
        items: kCarBrandsCatalog
            .map(
              (b) => DropdownMenuItem(
                value: b.id,
                child: Text(
                  b.displayLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() {
          _selectedBrandId = v;
          _selectedModelType = null;
          _customModelCtrl.clear();
        }),
      ),
    );
  }

  Widget _categoryField(ColorScheme cs) {
    return _SectionCard(
      icon: Icons.category_outlined,
      title: 'القسم',
      subtitle: 'إلزامي — لا يمكن الحفظ دون اختيار قسم',
      child: DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: _selectedCategory,
        hint: Text(
          'اختر القسم',
          style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.85)),
        ),
        decoration: _fieldDecoration(
          context,
          label: 'القسم *',
          prefixIcon: Icon(Icons.category_rounded, color: cs.primary),
        ),
        isExpanded: true,
        items: kSharedSpareCategories
            .map(
              (c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _selectedCategory = v),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'يجب اختيار القسم';
          }
          return null;
        },
      ),
    );
  }

  String _resolvedModelText() {
    if (_selectedBrandId != null &&
        _selectedBrandId!.isNotEmpty &&
        carModelsForBrandId(_selectedBrandId).isNotEmpty) {
      if (_selectedModelType == null || _selectedModelType!.isEmpty) return '';
      if (_selectedModelType == kCarModelOtherOption) {
        return _customModelCtrl.text.trim();
      }
      return _selectedModelType!.trim();
    }
    return _modelCtrl.text.trim();
  }

  Widget _modelField(ColorScheme cs) {
    final brandModels = carModelsForBrandId(_selectedBrandId);
    final useCatalog = _selectedBrandId != null && brandModels.isNotEmpty;

    if (!useCatalog) {
      return _SectionCard(
        icon: Icons.model_training_outlined,
        title: 'الموديل',
        subtitle: _selectedBrandId == null
            ? 'اختر الماركة لعرض الأنواع، أو اكتب الموديل يدوياً'
            : null,
        child: TextFormField(
          controller: _modelCtrl,
          decoration: _fieldDecoration(
            context,
            label: 'الموديل / سنة الصنع *',
            helper: 'مثال: كامري 2020 أو 2020',
            prefixIcon: Icon(Icons.calendar_month_outlined, color: cs.primary),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'الموديل أو سنة الصنع مطلوب';
            }
            return null;
          },
        ),
      );
    }

    final modelItems = [
      ...brandModels,
      kCarModelOtherOption,
    ];

    return _SectionCard(
      icon: Icons.model_training_outlined,
      title: 'الموديل',
      subtitle: 'اختر موديل ${brandById(_selectedBrandId)?.nameAr ?? 'الماركة'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedModelType != null &&
                    modelItems.contains(_selectedModelType)
                ? _selectedModelType
                : null,
            decoration: _fieldDecoration(
              context,
              label: 'الموديل *',
              prefixIcon: Icon(Icons.directions_car_filled_outlined,
                  color: cs.primary),
            ),
            isExpanded: true,
            items: modelItems
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _selectedModelType = v),
            validator: (v) {
              if (v == null || v.isEmpty) return 'اختر الموديل';
              return null;
            },
          ),
          if (_selectedModelType == kCarModelOtherOption) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customModelCtrl,
              decoration: _fieldDecoration(
                context,
                label: 'اكتب الموديل يدوياً *',
                prefixIcon:
                    Icon(Icons.edit_outlined, color: cs.primary),
              ),
              validator: (v) {
                if (_selectedModelType == kCarModelOtherOption &&
                    (v == null || v.trim().isEmpty)) {
                  return 'أدخل اسم الموديل';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _conditionField(ColorScheme cs) {
    return _SectionCard(
      icon: Icons.verified_outlined,
      title: 'الحالة',
      child: DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: _selectedCondition,
        decoration: _fieldDecoration(
          context,
          label: 'الحالة *',
          prefixIcon: Icon(Icons.info_outline_rounded, color: cs.primary),
        ),
        isExpanded: true,
        items: _conditions
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() => _selectedCondition = v),
        validator: (v) => v == null ? 'اختر الحالة' : null,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _modelCtrl.dispose();
    _customModelCtrl.dispose();
    _wheelCtrl.dispose();
    _yearFromCtrl.dispose();
    _yearToCtrl.dispose();
    super.dispose();
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = accent ?? cs.primary;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: c, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// يجمّع سلسلة أرقام إلى صيغة مفصولة بفواصل الآلاف: `50000` → `50,000`.
String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

/// منسّق حقل السعر: يعرض الأرقام مفصولة بفواصل الآلاف أثناء الكتابة.
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _groupDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
