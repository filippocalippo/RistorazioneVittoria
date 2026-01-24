import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/supabase_config.dart';
import '../core/models/delivery_zone_model.dart';
import '../core/utils/logger.dart';

/// Provider for delivery zones with real-time updates
final deliveryZonesProvider = StreamProvider<List<DeliveryZoneModel>>((ref) {
  final stream = SupabaseConfig.client
      .from('delivery_zones')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('display_order', ascending: false);

  return stream.map((data) {
    try {
      return data
          .map((json) => DeliveryZoneModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      Logger.error('Failed to parse delivery zones', tag: 'DeliveryZones', error: e, stackTrace: stack);
      return <DeliveryZoneModel>[];
    }
  });
});

/// Provider for zone management operations
final deliveryZonesServiceProvider = Provider((ref) => DeliveryZonesService());

/// Service for managing delivery zones
class DeliveryZonesService {
  /// Create a new delivery zone
  Future<DeliveryZoneModel?> createZone(DeliveryZoneModel zone) async {
    try {
      // Validate polygon
      if (!zone.isValidPolygon) {
        Logger.warning('Invalid polygon provided for zone creation', tag: 'DeliveryZones');
        throw Exception('Invalid polygon: must have at least 3 points and no self-intersections');
      }

      final response = await SupabaseConfig.client
          .from('delivery_zones')
          .insert(zone.toJson())
          .select()
          .single();

      Logger.info('Created delivery zone: ${zone.name}', tag: 'DeliveryZones');
      return DeliveryZoneModel.fromJson(response);
    } catch (e, stack) {
      Logger.error('Failed to create delivery zone', tag: 'DeliveryZones', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update an existing delivery zone
  Future<DeliveryZoneModel?> updateZone(String id, DeliveryZoneModel zone) async {
    try {
      // Validate polygon
      if (!zone.isValidPolygon) {
        Logger.warning('Invalid polygon provided for zone update', tag: 'DeliveryZones');
        throw Exception('Invalid polygon: must have at least 3 points and no self-intersections');
      }

      final response = await SupabaseConfig.client
          .from('delivery_zones')
          .update(zone.toJson())
          .eq('id', id)
          .select()
          .single();

      Logger.info('Updated delivery zone: ${zone.name}', tag: 'DeliveryZones');
      return DeliveryZoneModel.fromJson(response);
    } catch (e, stack) {
      Logger.error('Failed to update delivery zone', tag: 'DeliveryZones', error: e, stackTrace: stack);
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
      Logger.error('Failed to delete delivery zone', tag: 'DeliveryZones', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Hard delete a delivery zone (permanent)
  Future<void> hardDeleteZone(String id) async {
    try {
      await SupabaseConfig.client
          .from('delivery_zones')
          .delete()
          .eq('id', id);

      Logger.info('Permanently deleted delivery zone: $id', tag: 'DeliveryZones');
    } catch (e, stack) {
      Logger.error('Failed to permanently delete delivery zone', tag: 'DeliveryZones', error: e, stackTrace: stack);
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
      Logger.info('Reordered ${zones.length} delivery zones', tag: 'DeliveryZones');
    } catch (e, stack) {
      Logger.error('Failed to reorder delivery zones', tag: 'DeliveryZones', error: e, stackTrace: stack);
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
      Logger.error('Failed to fetch all delivery zones', tag: 'DeliveryZones', error: e, stackTrace: stack);
      return [];
    }
  }
}
