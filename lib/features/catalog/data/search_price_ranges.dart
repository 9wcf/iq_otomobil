/// نطاقات سعر جاهزة للبحث (دينار عراقي).
class SearchPriceRange {
  const SearchPriceRange({
    required this.id,
    required this.min,
    this.max,
  });

  final String id;
  final int min;

  /// `null` = بدون حد أعلى (أكثر من مليون).
  final int? max;

  String get label => formatSearchPriceRangeIraqi(min, max);
}

const kSearchPriceRanges = <SearchPriceRange>[
  SearchPriceRange(id: '5k_10k', min: 5000, max: 10000),
  SearchPriceRange(id: '10k_15k', min: 10000, max: 15000),
  SearchPriceRange(id: '15k_25k', min: 15000, max: 25000),
  SearchPriceRange(id: '25k_35k', min: 25000, max: 35000),
  SearchPriceRange(id: '35k_50k', min: 35000, max: 50000),
  SearchPriceRange(id: '50k_75k', min: 50000, max: 75000),
  SearchPriceRange(id: '75k_100k', min: 75000, max: 100000),
  SearchPriceRange(id: '100k_150k', min: 100000, max: 150000),
  SearchPriceRange(id: '150k_250k', min: 150000, max: 250000),
  SearchPriceRange(id: '250k_350k', min: 250000, max: 350000),
  SearchPriceRange(id: '350k_500k', min: 350000, max: 500000),
  SearchPriceRange(id: '500k_750k', min: 500000, max: 750000),
  SearchPriceRange(id: '750k_1m', min: 750000, max: 1000000),
  SearchPriceRange(id: '1m_plus', min: 1000000, max: null),
];

/// خيارات سعر جاهزة للاختيار في "من سعر" و"إلى سعر".
const kSearchPriceSelectableValues = <int>[
  5000,
  10000,
  25000,
  50000,
  100000,
  250000,
  500000,
  750000,
  1000000,
];

SearchPriceRange? priceRangeById(String? id) {
  if (id == null) return null;
  for (final r in kSearchPriceRanges) {
    if (r.id == id) return r;
  }
  return null;
}

/// مبلغ واحد بصيغة عراقية: «5 آلاف دينار»، «مليون دينار»…
String formatIqdIraqiAmount(int amount) {
  if (amount <= 0) return '0 دينار';
  if (amount >= 1000000) {
    final millions = amount ~/ 1000000;
    final rest = amount % 1000000;
    if (rest == 0) {
      return millions == 1 ? 'مليون دينار' : '$millions مليون دينار';
    }
    return '$millions مليون و${_thousandsPhrase(rest)} دينار';
  }
  if (amount >= 1000) {
    return '${_thousandsPhrase(amount)} دينار';
  }
  return '$amount دينار';
}

/// نطاق سعر: «من 5 آلاف إلى 10 آلاف دينار» أو «أكثر من مليون دينار».
String formatSearchPriceRangeIraqi(int min, int? max) {
  if (max == null) {
    return 'أكثر من ${formatIqdIraqiAmount(min)}';
  }
  return 'من ${_thousandsPhrase(min)} إلى ${_thousandsPhrase(max)} دينار';
}

String _thousandsPhrase(int amount) {
  if (amount >= 1000000) {
    final m = amount ~/ 1000000;
    final r = amount % 1000000;
    if (r == 0) return m == 1 ? 'مليون' : '$m مليون';
    return '$m مليون و${_thousandsPhrase(r)}';
  }
  if (amount < 1000) return '$amount';
  final k = amount ~/ 1000;
  if (k == 1) return 'ألف';
  if (k == 2) return 'ألفين';
  if (k >= 3 && k <= 10) return '$k آلاف';
  return '$k ألف';
}

/// سنوات التوافق للبحث.
int get kSearchYearMin => 1990;
int get kSearchYearMax => DateTime.now().year + 1;

List<int> get kSearchYearOptions => List.generate(
      kSearchYearMax - kSearchYearMin + 1,
      (i) => kSearchYearMax - i,
    );
