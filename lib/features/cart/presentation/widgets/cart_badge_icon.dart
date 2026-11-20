import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iq_otomobil/core/widgets/count_badge.dart';
import 'package:iq_otomobil/features/cart/presentation/providers/cart_provider.dart';

class CartBadgeIcon extends ConsumerWidget {
  const CartBadgeIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountNotifierProvider);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => context.go('/cart'),
        ),
        CountBadge(count: count, right: 4, top: 4),
      ],
    );
  }
}
