import 'package:flutter/material.dart';

/// عرض موحّد لحالات الطلب بين تطبيق المستخدم والتاجر.
class OrderStatusDisplay {
  OrderStatusDisplay._();

  static String _norm(String? raw) =>
      (raw ?? 'pending').toString().trim().toLowerCase();

  /// النص المعروض في الشارة / الحالة (نفس المعنى للطرفين).
  static String label(String? raw) {
    switch (_norm(raw)) {
      case 'pending':
      case 'pending_promoter_review':
        return 'قيد الانتظار';
      case 'approved':
        return 'تم القبول';
      case 'shipped':
        return 'يتم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
      case 'rejected':
        return 'تم إلغاء الطلب';
      default:
        return 'قيد الانتظار';
    }
  }

  /// وصف إضافي في قائمة طلبات المستخدم.
  static String userListDescription(String? raw) {
    switch (_norm(raw)) {
      case 'pending':
      case 'pending_promoter_review':
        return 'بانتظار موافقة التاجر';
      case 'approved':
        return 'تم قبول الطلب — جاري التجهيز للشحن';
      case 'shipped':
        return 'يتم الشحن حالياً';
      case 'delivered':
        return 'تم التسليم بنجاح';
      case 'cancelled':
      case 'rejected':
        return 'تم إلغاء الطلب';
      default:
        return '';
    }
  }

  static Color accentColor(String? raw) {
    switch (_norm(raw)) {
      case 'pending':
      case 'pending_promoter_review':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'shipped':
        return Colors.cyan;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static bool isCancelledOrRejected(String? raw) {
    final s = _norm(raw);
    return s == 'cancelled' || s == 'rejected';
  }

  static bool isDelivered(String? raw) => _norm(raw) == 'delivered';
}
