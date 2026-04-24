import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iq_otomobil/core/services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadMyReviews();
  }

  Future<void> _loadMyReviews() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client
          .from('reviews')
          .select('*, products(model, images)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _reviews = response;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في جلب تقييماتي: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('تقييماتي', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMyReviews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _reviews.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (ctx, index) =>
                      _buildReviewCard(_reviews[index], index),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('لم تقم بتقييم أي منتج بعد',
              style: TextStyle(color: Colors.grey[400], fontSize: 18)),
          const SizedBox(height: 8),
          Text('شارك تجربتك مع المنتجات التي اشتريتها',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.shopping_bag),
            label: const Text('تصفح المنتجات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, int index) {
    final product = review['products'] as Map?;
    final rating = review['rating'] as int;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] != null
        ? DateTime.parse(review['created_at'])
        : DateTime.now();
    final images = product?['images'] as List?;
    final imageUrl =
        (images != null && images.isNotEmpty) ? images[0].toString() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // صورة المنتج
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[800],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey)))
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[800],
                        child:
                            const Icon(Icons.shopping_bag, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product?['model'] ?? 'منتج',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            Text(comment,
                style: TextStyle(color: Colors.grey[300], height: 1.5)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📅 ${_formatDate(createdAt)}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              TextButton.icon(
                onPressed: () => _editReview(review['id']),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.blue[300]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editReview(String reviewId) async {
    // يمكن إضافة صفحة تعديل التقييم لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('قريباً: تعديل التقييم')),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
