import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/promotional_banner_model.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

part 'banner_management_provider.g.dart';

/// Provider for all banners (managers can see all, not just active)
/// Used in the management screen to display all banners for CRUD operations
@riverpod
Future<List<PromotionalBannerModel>> allBanners(Ref ref) async {
  final orgId = await ref.watch(currentOrganizationProvider.future);

  try {
    dynamic response;
    if (orgId != null) {
      response = await SupabaseConfig.client
          .from('promotional_banners')
          .select()
          .or('organization_id.eq.$orgId,organization_id.is.null')
          .order('created_at', ascending: false);
    } else {
      response = await SupabaseConfig.client
          .from('promotional_banners')
          .select()
          .order('created_at', ascending: false);
    }

    return (response as List)
        .map((json) => PromotionalBannerModel.fromJson(json))
        .toList();
  } catch (e, stack) {
    Logger.error(
      'Failed to fetch all banners',
      tag: 'BannerManagement',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
}
