import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/supabase_config.dart';
import '../core/models/delivery_zone_model.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

/// Provider for delivery zones with real-time updates
/// Note: For multi-tenant, we use .or filter when organization is available
final deliveryZonesProvider = StreamProvider<List<DeliveryZoneModel>>((ref) {
  // Watch organization changes to rebuild stream when org changes
  final orgAsync = ref.watch(currentOrganizationProvider);
  // ignore: unused_local_variable - Used to trigger rebuild, RLS handles multi-tenant filtering
  final orgId = orgAsync.valueOrNull;

  var query = SupabaseConfig.client
      .from('delivery_zones')
      .stream(primaryKey: ['id'])
      .eq('is_active', true);

  // Note: Supabase stream doesn't support .or() filter, so RLS handles multi-tenant
  // The stream will be filtered by RLS policies at database level

  return query.order('display_order', ascending: false).map((data) {
    try {
      return data.map((json) => DeliveryZoneModel.fromJson(json)).toList();
    } catch (e, stack) {
      Logger.error(
        'Failed to parse delivery zones',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      return <DeliveryZoneModel>[];
    }
  });
});

/// Provider for zone management operations
final deliveryZonesServiceProvider = Provider((ref) => DeliveryZonesService());

/// Service for managing delivery zones
class DeliveryZonesService {
  /// Create a new delivery zone
  Future<DeliveryZoneModel?> createZone(
    DeliveryZoneModel zone, {
    String? organizationId,
  }) async {
    try {
      // Validate polygon
      if (!zone.isValidPolygon) {
        Logger.warning(
          'Invalid polygon provided for zone creation',
          tag: 'DeliveryZones',
        );
        throw Exception(
          'Invalid polygon: must have at least 3 points and no self-intersections',
        );
      }

      final payload = Map<String, dynamic>.from(zone.toJson());
      if (payload['organization_id'] == null && organizationId != null) {
        payload['organization_id'] = organizationId;
      }

      final response = await SupabaseConfig.client
          .from('delivery_zones')
          .insert(payload)
          .select()
          .single();

      Logger.info('Created delivery zone: ${zone.name}', tag: 'DeliveryZones');
      return DeliveryZoneModel.fromJson(response);
    } catch (e, stack) {
      Logger.error(
        'Failed to create delivery zone',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Update an existing delivery zone
  Future<DeliveryZoneModel?> updateZone(
    String id,
    DeliveryZoneModel zone, {
    String? organizationId,
  }) async {
    try {
      // Validate polygon
      if (!zone.isValidPolygon) {
        Logger.warning(
          'Invalid polygon provided for zone update',
          tag: 'DeliveryZones',
        );
        throw Exception(
          'Invalid polygon: must have at least 3 points and no self-intersections',
        );
      }

      final payload = Map<String, dynamic>.from(zone.toJson());
      if (payload['organization_id'] == null && organizationId == null) {
        payload.remove('organization_id');
      } else if (organizationId != null) {
        payload['organization_id'] = organizationId;
      }

      final response = await SupabaseConfig.client
          .from('delivery_zones')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      Logger.info('Updated delivery zone: ${zone.name}', tag: 'DeliveryZones');
      return DeliveryZoneModel.fromJson(response);
    } catch (e, stack) {
      Logger.error(
        'Failed to update delivery zone',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Delete a delivery zone (soft delete by setting is_active = false)
  Future<void> deleteZone(String id) async {
    try {
      await SupabaseConfig.client
          .from('delivery_zones')
          .update({'is_active': false})
          .eq('id', id);

      Logger.info('Deleted delivery zone: $id', tag: 'DeliveryZones');
    } catch (e, stack) {
      Logger.error(
        'Failed to delete delivery zone',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Hard delete a delivery zone (permanent)
  Future<void> hardDeleteZone(String id) async {
    try {
      await SupabaseConfig.client.from('delivery_zones').delete().eq('id', id);

      Logger.info(
        'Permanently deleted delivery zone: $id',
        tag: 'DeliveryZones',
      );
    } catch (e, stack) {
      Logger.error(
        'Failed to permanently delete delivery zone',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Reorder zones (for overlap priority)
  Future<void> reorderZones(List<DeliveryZoneModel> zones) async {
    try {
      final updates = <Future<void>>[];

      for (int i = 0; i < zones.length; i++) {
        final zone = zones[i];
        updates.add(
          SupabaseConfig.client
              .from('delivery_zones')
              .update({'display_order': zones.length - i})
              .eq('id', zone.id)
              .then((_) {}),
        );
      }

      await Future.wait(updates);
      Logger.info(
        'Reordered ${zones.length} delivery zones',
        tag: 'DeliveryZones',
      );
    } catch (e, stack) {
      Logger.error(
        'Failed to reorder delivery zones',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Fetch all zones (including inactive)
  Future<List<DeliveryZoneModel>> fetchAllZones() async {
    try {
      final response = await SupabaseConfig.client
          .from('delivery_zones')
          .select()
          .order('display_order', ascending: false);

      return (response as List)
          .map((json) => DeliveryZoneModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      Logger.error(
        'Failed to fetch all delivery zones',
        tag: 'DeliveryZones',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }
}
