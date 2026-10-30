import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/widgets/fly_to_cart.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/cart/screens/cart_screen.dart';

/// أيقونة السلة مع عداد العناصر.
/// هدف لحركة «الطيران إلى السلة»: العداد لا يزيد إلا عند هبوط العنصر، ثم تقفز الأيقونة.
class CartIconButton extends StatefulWidget {
  const CartIconButton({
    super.key,
    this.iconColor = Colors.black,
    this.backgroundColor,
    this.size = 40,
  });

  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> with SingleTickerProviderStateMixin {
  final _targetKey = GlobalKey();
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    FlyToCart.registerTarget(_targetKey);
    FlyToCart.landed.addListener(_onLanded);
    FlyToCart.pending.addListener(_rebuild);
  }

  @override
  void dispose() {
    FlyToCart.unregisterTarget(_targetKey);
    FlyToCart.landed.removeListener(_onLanded);
    FlyToCart.pending.removeListener(_rebuild);
    _bounce.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onLanded() {
    if (!mounted) return;
    setState(() {});
    _bounce.forward(from: 0);
  }

  Future<void> _openCart(BuildContext context) async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok == true && context.mounted) {
        await context.read<CartService>().refresh();
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final realCount = context.watch<CartService>().itemsCount;
    final count = math.max(0, realCount - FlyToCart.pending.value);
    final size = widget.size;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCart(context),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final t = _bounce.value;
            // قفزة مرنة: تكبر ثم تهتز قليلاً وتستقر
            final scale = 1 + 0.32 * math.sin(t * math.pi) * (1 - t * 0.5);
            final wobble = math.sin(t * math.pi * 4) * 0.18 * (1 - t);
            return Transform.rotate(
              angle: wobble,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            key: _targetKey,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  count > 0 ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined,
                  color: widget.iconColor,
                  size: 22,
                ),
                Positioned(
                  top: 2,
                  left: 2,
                  child: AnimatedScale(
                    scale: count > 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 380),
                    curve: count > 0 ? Curves.elasticOut : Curves.easeIn,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      decoration: BoxDecoration(
                        gradient: RastUi.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.3),
                        boxShadow: [
                          BoxShadow(color: RastUi.purple.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, anim) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.9), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutBack))
                              .animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          key: ValueKey(count),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر نصي للسلة (مثلاً في الملف الشخصي).
class CartListTile extends StatelessWidget {
  const CartListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;
    final count = context.watch<CartService>().itemsCount;

    return ListTile(
      leading: const Icon(Icons.shopping_cart_outlined),
      title: Text(AppStrings.t('cart', lang)),
      subtitle: count > 0
          ? Text(AppStrings.t('cartItemsCount', lang).replaceAll('%d', '$count'))
          : Text(AppStrings.t('cartEmptyHint', lang)),
      trailing: count > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : const Icon(Icons.chevron_left),
      onTap: () {
        if (!AuthService.isLoggedIn) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
      },
    );
  }
}
