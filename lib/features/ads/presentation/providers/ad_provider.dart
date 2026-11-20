import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ad_repository.dart';

final adRepoProvider = Provider((ref) => AdRepository());

final homeBannerAdsProvider = FutureProvider.autoDispose(
  (ref) {
    ref.keepAlive();
    return ref
        .watch(adRepoProvider)
        .getActiveAds(position: AdRepository.kHomeBannerPosition);
  },
);

final bannerIntervalSecondsProvider = FutureProvider.autoDispose(
  (ref) {
    ref.keepAlive();
    return ref.watch(adRepoProvider).getBannerIntervalSeconds();
  },
);

class AdActionNotifier extends StateNotifier<AsyncValue<void>> {
  final AdRepository _repo;
  AdActionNotifier(this._repo) : super(const AsyncData(null));

  Future<void> recordView(String adId) async {
    await _repo.incrementView(adId);
  }

  Future<void> recordClick(String adId) async {
    await _repo.incrementClick(adId);
  }
}

final adActionProvider =
    StateNotifierProvider<AdActionNotifier, AsyncValue<void>>(
  (ref) => AdActionNotifier(ref.watch(adRepoProvider)),
);
