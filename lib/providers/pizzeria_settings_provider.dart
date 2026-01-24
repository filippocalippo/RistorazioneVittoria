import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/models/settings/pizzeria_settings_model.dart';
import '../core/models/settings/order_management_settings.dart';
import '../core/models/settings/delivery_configuration_settings.dart';
import '../core/models/settings/display_branding_settings.dart';
import '../core/models/settings/kitchen_management_settings.dart';
import '../core/models/settings/business_rules_settings.dart';
import '../core/services/database_service.dart';
import '../core/services/app_cache_service.dart';
import '../core/utils/logger.dart';

part 'pizzeria_settings_provider.g.dart';

/// Provider for fetching and managing pizzeria settings.
/// Implements cache-first strategy to prevent loading flashes on startup
@riverpod
class PizzeriaSettings extends _$PizzeriaSettings {
  DatabaseService get _database => DatabaseService();

  @override
  Future<PizzeriaSettingsModel?> build() async {
    // Fetch from database
    final settings = await _database.getPizzeriaSettings();
    
    // Cache the fetched data for next startup
    await AppCacheService.cachePizzeriaInfo(
      name: settings.pizzeria.nome,
      logoUrl: settings.pizzeria.logoUrl,
    );
    Logger.debug('Cached pizzeria info for next startup', tag: 'PizzeriaSettings');
    
    return settings;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> updatePizzeria(Map<String, dynamic> updates) async {
    await _database.updateBusinessRules(updates);
    await refresh();
  }

  Future<void> updateBusinessHours(Map<String, dynamic> hours) async {
    await updatePizzeria({'orari': hours});
  }

  Future<void> saveOrderManagement(OrderManagementSettings settings) async {
    await _database.saveOrderManagementSettings(settings);
    await refresh();
  }

  Future<void> saveOrderManagementRaw(Map<String, dynamic> values) async {
    await _database.saveOrderManagementSettingsRaw(values);
    await refresh();
  }

  Future<void> saveDeliveryConfiguration(
    DeliveryConfigurationSettings settings,
  ) async {
    await _database.saveDeliveryConfigurationSettings(settings);
    await refresh();
  }

  Future<void> saveBranding(DisplayBrandingSettings settings) async {
    await _database.saveDisplayBrandingSettings(settings);
    await refresh();
  }

  Future<void> saveKitchen(KitchenManagementSettings settings) async {
    await _database.saveKitchenManagementSettings(settings);
    await refresh();
  }

  Future<void> saveBusinessRules(BusinessRulesSettings settings) async {
    await _database.saveBusinessRulesSettings(settings);
    await refresh();
  }

  Future<void> toggleActive(bool active) async {
    await _database.updateBusinessRules({'attiva': active});

    final current = state.value;
    final business = current?.businessRules ?? BusinessRulesSettings.defaults();
    await _database.saveBusinessRulesSettings(
      business.copyWith(attiva: active),
    );
    await refresh();
  }
}
