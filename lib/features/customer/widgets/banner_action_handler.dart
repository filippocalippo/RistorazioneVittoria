import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/promotional_banner_model.dart';
import '../../../core/utils/logger.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/banner_navigation_provider.dart';
import '../widgets/product_customization_modal.dart';

/// Handles banner tap actions based on action type
class BannerActionHandler {
  static Future<void> handle(
    BuildContext context,
    PromotionalBannerModel banner,
    {WidgetRef? ref}
  ) async {
    final actionType = BannerActionType.fromString(banner.actionType);
    
    try {
      switch (actionType) {
        case BannerActionType.externalLink:
          await _handleExternalLink(banner.actionData);
          break;
          
        case BannerActionType.internalRoute:
          if (context.mounted) {
            _handleInternalRoute(context, banner.actionData);
          }
          break;
          
        case BannerActionType.product:
          if (context.mounted && ref != null) {
            await _handleProduct(context, banner.actionData, ref);
          }
          break;
          
        case BannerActionType.category:
          if (context.mounted && ref != null) {
            _handleCategory(context, banner.actionData, ref);
          }
          break;
          
        case BannerActionType.specialOffer:
          if (context.mounted) {
            await _handleSpecialOffer(context, banner.actionData);
          }
          break;
          
        case BannerActionType.none:
          // No action
          break;
      }
    } catch (e, stack) {
      Logger.error(
        'Banner action failed',
        tag: 'BannerAction',
        error: e,
        stackTrace: stack,
      );
      if (context.mounted) {
        _showError(context);
      }
    }
  }

  static Future<void> _handleExternalLink(Map<String, dynamic> data) async {
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _handleInternalRoute(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final route = data['route'] as String?;
    if (route == null || route.isEmpty) return;

    final params = data['params'] as Map<String, dynamic>?;
    
    if (params != null && params.isNotEmpty) {
      context.go(route, extra: params);
    } else {
      context.go(route);
    }
  }

  static Future<void> _handleProduct(
    BuildContext context,
    Map<String, dynamic> data,
    WidgetRef ref,
  ) async {
    final productId = data['product_id'] as String?;
    if (productId == null || productId.isEmpty) return;

    Logger.info('Opening product: $productId', tag: 'BannerAction');
    
    try {
      // Fetch the product from menu provider
      final menuAsync = ref.read(menuProvider);
      
      menuAsync.when(
        data: (products) {
          final product = products.firstWhere(
            (item) => item.id == productId,
            orElse: () => throw Exception('Product not found'),
          );
          
          // Open product customization modal - context is used synchronously here
          if (context.mounted) {
            ProductCustomizationModal.show(context, product);
          }
        },
        loading: () {
          if (context.mounted) {
            _showMessage(context, 'Caricamento prodotto...', AppColors.textSecondary);
          }
        },
        error: (error, _) {
          if (context.mounted) {
            _showMessage(context, 'Prodotto non trovato', AppColors.error);
          }
        },
      );
    } catch (e) {
      Logger.error('Failed to open product', tag: 'BannerAction', error: e);
      if (context.mounted) {
        _showMessage(context, 'Prodotto non disponibile', AppColors.error);
      }
    }
  }

  static void _handleCategory(
    BuildContext context,
    Map<String, dynamic> data,
    WidgetRef ref,
  ) {
    final categoryId = data['category_id'] as String?;
    if (categoryId == null || categoryId.isEmpty) return;

    Logger.info('Navigating to category: $categoryId', tag: 'BannerAction');

    // Set the category navigation state for MenuScreen to pick up
    ref.read(bannerNavigationProvider.notifier).setCategoryId(categoryId);
    
    // Navigate to menu (menu screen will check the provider and select category)
    context.go('/menu');
  }

  static Future<void> _handleSpecialOffer(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final promoCode = data['promo_code'] as String?;
    
    // TODO: Implement special offer handling
    // This would require integration with cart provider for promo codes
    Logger.info('Applying promo code: $promoCode', tag: 'BannerAction');
    
    if (promoCode != null && promoCode.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Codice promo "$promoCode" disponibile!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  static void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossibile aprire il contenuto'),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 2),
      ),
    );
  }

  static void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
