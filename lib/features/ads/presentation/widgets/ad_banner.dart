import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/ad_provider.dart';

class AdBanner extends ConsumerWidget {
  final String position;
  const AdBanner({super.key, required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsProvider =
        position == 'home_top' ? homeTopAdsProvider : homeBottomAdsProvider;
    final adsAsync = ref.watch(adsProvider);

    return adsAsync.when(
      data: (ads) {
        if (ads.isEmpty) return const SizedBox.shrink();

        // عرض أول إعلان فقط (يمكن تطويره لـ Carousel)
        final ad = ads.first;

        return GestureDetector(
          onTap: () async {
            await ref.read(adActionProvider.notifier).recordClick(ad['id']);
            if (ad['link_url'] != null) {
              await launchUrl(Uri.parse(ad['link_url']));
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[400]!]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ad['image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                        imageUrl: ad['image_url'], fit: BoxFit.cover),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ad['title'] != null)
                          Text(ad['title'],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        if (ad['content'] != null) ...[
                          const SizedBox(height: 4),
                          Text(ad['content'],
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ],
                    ),
                  ),
          ),
        ).animate().fadeIn().shimmer(duration: 2.seconds);
      },
      loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
