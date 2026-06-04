import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/cart/screens/cart_screen.dart';

/// أيقونة السلة مع عداد العناصر.
class CartIconButton extends StatelessWidget {
  const CartIconButton({
    super.key,
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.size = 40,
  });

  final Color iconColor;
  final Color? backgroundColor;
  final double size;

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
    final count = context.watch<CartService>().itemsCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCart(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, color: iconColor, size: 22),
              if (count > 0)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: RastUi.purple,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
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
