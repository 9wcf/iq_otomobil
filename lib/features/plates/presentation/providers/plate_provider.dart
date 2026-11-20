import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:iq_otomobil/features/plates/data/plate_repository.dart';

final plateRepoProvider = Provider((ref) => PlateRepository());

final approvedPlatesProvider = FutureProvider.autoDispose((ref) async {
  try {
    return await ref.watch(plateRepoProvider).getApprovedPlates();
  } catch (e) {
    return <Map<String, dynamic>>[];
  }
});

class PlateActionNotifier extends StateNotifier<AsyncValue<void>> {
  final PlateRepository _repo;
  PlateActionNotifier(this._repo) : super(const AsyncData(null));

  Future<void> submit({
    required String plateNumber,
    required String plateType,
    String? governorate,
    String? description,
    double? price,
    required String sellerPhone,
    String? sellerName,
    List<File>? images,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.submitPlate(
        plateNumber: plateNumber,
        plateType: plateType,
        governorate: governorate,
        description: description,
        price: price,
        sellerPhone: sellerPhone,
        sellerName: sellerName,
        images: images,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final plateActionProvider =
    StateNotifierProvider<PlateActionNotifier, AsyncValue<void>>(
  (ref) => PlateActionNotifier(ref.watch(plateRepoProvider)),
);
