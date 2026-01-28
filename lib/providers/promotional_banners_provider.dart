import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/promotional_banner_model.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

part 'promotional_banners_provider.g.dart';

@riverpod
class PromotionalBanners extends _$PromotionalBanners {
  @override
  Future<List<PromotionalBannerModel>> build() async {
    return _fetchBanners();
  }

  Future<List<PromotionalBannerModel>> _fetchBanners() async {
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      // SECURITY: Require organization context to prevent cross-tenant data access
      if (orgId == null) {
        Logger.warning('No organization context for banners', tag: 'Banners');
        return [];
      }

      final response = await SupabaseConfig.client
          .from('promotional_banners')
          .select()
          .eq('attivo', true)
          .eq('organization_id', orgId)
          .order('priorita', ascending: false)
          .order('ordine', ascending: true);

      final now = DateTime.now();
      final banners = (response as List)
          .map((json) => PromotionalBannerModel.fromJson(json))
          .where((banner) {
            // Filter by date range
            if (banner.dataInizio != null && banner.dataInizio!.isAfter(now)) {
              return false;
            }
            if (banner.dataFine != null && banner.dataFine!.isBefore(now)) {
              return false;
            }
            return true;
          })
          .toList();

      Logger.info('✓ Loaded ${banners.length} active banners', tag: 'Banners');
      return banners;
    } catch (e, stack) {
      Logger.error(
        'Failed to fetch banners',
        tag: 'Banners',
        error: e,
        stackTrace: stack,
      );
      // Return empty list on error to prevent app crash
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchBanners());
  }

  Future<void> incrementView(String bannerId) async {
    try {
      await SupabaseConfig.client.rpc(
        'increment_banner_view',
        params: {'banner_id': bannerId},
      );
    } catch (e) {
      Logger.warning('Failed to increment banner view: $e', tag: 'Banners');
    }
  }

  Future<void> incrementClick(String bannerId) async {
    try {
      await SupabaseConfig.client.rpc(
        'increment_banner_click',
        params: {'banner_id': bannerId},
      );
    } catch (e) {
      Logger.warning('Failed to increment banner click: $e', tag: 'Banners');
    }
  }
}

// Filtered providers for device-specific banners
@riverpod
List<PromotionalBannerModel> mobileBanners(Ref ref) {
  final banners = ref.watch(promotionalBannersProvider).value ?? [];
  return banners.where((b) => !b.mostraSoloDesktop).toList();
}

@riverpod
List<PromotionalBannerModel> desktopBanners(Ref ref) {
  final banners = ref.watch(promotionalBannersProvider).value ?? [];
  return banners.where((b) => !b.mostraSoloMobile).toList();
}
