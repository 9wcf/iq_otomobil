import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iq_otomobil/core/theme/app_colors.dart';
import 'package:iq_otomobil/core/utils/money_iqd.dart';
import 'package:iq_otomobil/features/favorites/presentation/providers/favorites_provider.dart';

/// خلفية ناعمة لقوائم المنتجات (رمادي فاتح).
const Color kProductListBackground = Color(0xFFF3F4F6);

/// ارتفاع/عرض الصورة — يحدد ارتفاع منطقة المحتوى (+20% عن 96).
const double kProductCardImageSize = 115.0;

/// حشوة البطاقة الداخلية (+20% عن 8).
const double kProductCardPadding = 10.0;

/// المسافة العمودية بين البطاقات في القائمة (-50% عن 12).
const double kProductCardListSpacing = 6.0;

/// ألوان بطاقة المنتج.
abstract final class _ProductCardPalette {
  static const primary = Color(0xFF4F7CFF);
  static const card = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF3F4F6);
  static const imageBg = Color(0xFFF0F2F5);
  static const textPrimary = Color(0xFF1A1D26);
  static const textSecondary = Color(0xFF6B7280);
  static const favorite = Color(0xFFE53935);
  static const price = AppColors.error;
  static const shadow = Color(0x141A1D26);
}

/// بطاقة منتج أفقية — RTL، زر التفاصيل مثبت أسفل اليسار.
class UserProductListTile extends ConsumerStatefulWidget {
  const UserProductListTile({
    super.key,
    required this.productId,
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
    this.brandLabel,
    this.price,
    this.conditionLabel,
  });

  final String productId;
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final String? brandLabel;
  final dynamic price;
  final String? conditionLabel;
  final VoidCallback onTap;

  @override
  ConsumerState<UserProductListTile> createState() =>
      _UserProductListTileState();
}

class _UserProductListTileState extends ConsumerState<UserProductListTile> {
  bool _pressed = false;

  String get _secondaryLine {
    final parts = <String>[
      if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty)
        widget.subtitle!.trim(),
      if (widget.brandLabel != null && widget.brandLabel!.trim().isNotEmpty)
        widget.brandLabel!.trim(),
    ];
    return parts.join(' • ');
  }

  String get _priceText => formatIQD(
        widget.price is num ? widget.price : num.tryParse('${widget.price}'),
      );

  @override
  Widget build(BuildContext context) {
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final isFavorite = favoriteIds.contains(widget.productId);
    final condition = widget.conditionLabel?.trim();
    final showCondition = condition != null && condition.isNotEmpty;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.988 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _ProductCardPalette.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _ProductCardPalette.shadow,
                blurRadius: _pressed ? 6 : 14,
                offset: Offset(0, _pressed ? 1 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: _ProductCardPalette.card,
              child: InkWell(
                onTap: widget.onTap,
                splashColor:
                    _ProductCardPalette.primary.withValues(alpha: 0.10),
                highlightColor:
                    _ProductCardPalette.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(kProductCardPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: [
                      _ProductImage(imageUrl: widget.imageUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: kProductCardImageSize,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: _FavoriteButton(
                                    isFavorite: isFavorite,
                                    onPressed: () => ref
                                        .read(favoriteIdsProvider.notifier)
                                        .toggle(widget.productId),
                                  ),
                                ),
                                const Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: _DetailsButton(),
                                ),
                                Positioned(
                                  left: 40,
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showCondition) ...[
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: _ConditionBadge(
                                            label: condition,
                                            compact: true,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              widget.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              textDirection: TextDirection.rtl,
                                              style: const TextStyle(
                                                color: _ProductCardPalette
                                                    .textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                height: 1.15,
                                                letterSpacing: -0.15,
                                              ),
                                            ),
                                            if (_secondaryLine.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _secondaryLine,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                textDirection: TextDirection.rtl,
                                                style: const TextStyle(
                                                  color: _ProductCardPalette
                                                      .textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 11,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _priceText,
                                              maxLines: 1,
                                              softWrap: false,
                                              textAlign: TextAlign.right,
                                              textDirection: TextDirection.rtl,
                                              style: const TextStyle(
                                                color: _ProductCardPalette.price,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                height: 1,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = kProductCardImageSize;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: _ProductCardPalette.imageBg),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  memCacheWidth: (size * 2).round(),
                  memCacheHeight: (size * 2).round(),
                  fadeInDuration: const Duration(milliseconds: 120),
                  placeholder: (_, __) => const _ImagePlaceholder(),
                  errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                )
              : const _ImagePlaceholder(),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _ProductCardPalette.imageBg,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: _ProductCardPalette.textSecondary,
          size: 32,
        ),
      ),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  bool get _isNew => label == 'جديد';

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 8.0 : 10.0;
    final vPad = compact ? 4.0 : 4.0;
    final fontSize = compact ? 10.0 : 11.0;

    if (_isNew) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F7CFF), Color(0xFF3D6AE8)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: _ProductCardPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _ProductCardPalette.textSecondary,
          fontSize: fontSize - 1,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: _ProductCardPalette.favorite.withValues(alpha: 0.12),
        child: Ink(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: _ProductCardPalette.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _ProductCardPalette.favorite,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _DetailsButton extends StatelessWidget {
  const _DetailsButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: _ProductCardPalette.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'التفاصيل',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(width: 3),
          Icon(
            Icons.chevron_left_rounded,
            size: 14,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

String? productConditionLabelAr(String? condition) {
  return switch (condition) {
    'new' => 'جديد',
    'used' => 'مستعمل',
    'refurbished' => 'مجدد',
    'american_import' => 'وارد امريكي',
    'korean_import' => 'وارد كوري',
    _ => null,
  };
}
