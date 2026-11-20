import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/ad_provider.dart';

class AdBanner extends ConsumerStatefulWidget {
  /// When null, defaults to a compact strip height suitable for in-page placement.
  final double? height;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool showShimmer;

  const AdBanner({
    super.key,
    this.height,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.borderRadius = 12,
    this.showShimmer = true,
  });

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  final _pageController = PageController();
  Timer? _timer;
  int _page = 0;
  List<String> _lastAdIds = const [];
  int _lastIntervalSeconds = 5;
  bool _didRecordFirstView = false;
  ProviderSubscription<AsyncValue<List<dynamic>>>? _adsSub;
  ProviderSubscription<AsyncValue<int>>? _intervalSub;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _adsSub?.close();
    _intervalSub?.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _adsSub = ref.listenManual<AsyncValue<List<dynamic>>>(homeBannerAdsProvider, (prev, next) {
      final ads = next.valueOrNull;
      if (!mounted || ads == null) return;

      final ids =
          ads.map((a) => (a['id'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      if (ids.isEmpty) return;

      final changed = ids.length != _lastAdIds.length ||
          !List.generate(ids.length, (i) => ids[i] == _lastAdIds[i]).every((v) => v);

      if (changed) {
        _lastAdIds = ids;
        _page = 0;
        // The controller may not be attached yet if ads arrive before first build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(0);
        });
        _didRecordFirstView = false;
      }

      _startAutoScroll(ids.length, intervalSeconds: _lastIntervalSeconds);

      if (!_didRecordFirstView) {
        _didRecordFirstView = true;
        ref.read(adActionProvider.notifier).recordView(ids.first);
      }
    });

    _intervalSub = ref.listenManual<AsyncValue<int>>(
        bannerIntervalSecondsProvider, (prev, next) {
      final seconds = next.valueOrNull;
      if (seconds == null) return;
      _lastIntervalSeconds = seconds <= 0 ? 5 : seconds;
      if (_lastAdIds.isNotEmpty) {
        _startAutoScroll(_lastAdIds.length, intervalSeconds: _lastIntervalSeconds);
      }
    });
  }

  void _startAutoScroll(int itemCount, {required int intervalSeconds}) {
    _timer?.cancel();
    if (itemCount <= 1) return;
    final s = intervalSeconds <= 0 ? 5 : intervalSeconds;
    _timer = Timer.periodic(Duration(seconds: s), (_) {
      if (!mounted) return;
      _page = (_page + 1) % itemCount;
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final adsAsync = ref.watch(homeBannerAdsProvider);

    return adsAsync.when(
      data: (ads) {
        if (ads.isEmpty) return const SizedBox.shrink();

        final h = widget.height ?? 120;

        final banner = Container(
          margin: widget.margin,
          height: h,
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [Colors.blue[700]!, Colors.blue[400]!]),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: ads.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final ad = ads[i];
                  return GestureDetector(
                    onTap: () async {
                      await ref
                          .read(adActionProvider.notifier)
                          .recordClick(ad['id']);
                      final link = ad['link_url']?.toString();
                      if (link != null && link.trim().isNotEmpty) {
                        await launchUrl(Uri.parse(link));
                      }
                    },
                    child: ad['image_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: ad['image_url'],
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 120),
                            fadeOutDuration: const Duration(milliseconds: 120),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ad['title'] != null)
                                  Text(
                                    ad['title'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (ad['content'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    ad['content'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  );
                },
              ),
              if (ads.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      ads.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: i == _page ? 18 : 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white.withOpacity(0.95)
                              : Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        if (!widget.showShimmer) {
          return banner.animate().fadeIn();
        }
        return banner.animate().fadeIn().shimmer(duration: 2.seconds);
      },
      loading: () => SizedBox(
          height: widget.height ?? 120,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
