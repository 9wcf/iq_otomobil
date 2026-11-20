import 'package:intl/intl.dart';

final _iqdInteger = NumberFormat('#,##0', 'en_US');
final _iqdDecimal = NumberFormat('#,##0.00', 'en_US');

/// Centralized money formatting for IQD display.
///
/// Note: This ONLY changes how numbers are displayed (no conversion).
String formatIQD(num? value) {
  if (value == null) return '0 د.ع';
  final d = value.toDouble();
  if (d == d.roundToDouble()) {
    return '${_iqdInteger.format(d)} د.ع';
  }
  return '${_iqdDecimal.format(d)} د.ع';
}

/// رقم فقط بفواصل كل ثلاث مراتب (بدون «د.ع»).
String formatIQDNumber(num? value) {
  if (value == null) return '0';
  final d = value.toDouble();
  if (d == d.roundToDouble()) return _iqdInteger.format(d);
  return _iqdDecimal.format(d);
}
