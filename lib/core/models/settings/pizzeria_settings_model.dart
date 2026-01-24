import 'package:freezed_annotation/freezed_annotation.dart';

import '../pizzeria_model.dart';
import 'business_rules_settings.dart';
import 'delivery_configuration_settings.dart';
import 'display_branding_settings.dart';
import 'kitchen_management_settings.dart';
import 'order_management_settings.dart';

part 'pizzeria_settings_model.freezed.dart';

@freezed
class PizzeriaSettingsModel with _$PizzeriaSettingsModel {
  const factory PizzeriaSettingsModel({
    required PizzeriaModel pizzeria,
    required OrderManagementSettings orderManagement,
    required DeliveryConfigurationSettings deliveryConfiguration,
    required DisplayBrandingSettings branding,
    required KitchenManagementSettings kitchen,
    required BusinessRulesSettings businessRules,
  }) = _PizzeriaSettingsModel;

  const PizzeriaSettingsModel._();

  factory PizzeriaSettingsModel.initial(PizzeriaModel pizzeria) =>
      PizzeriaSettingsModel(
        pizzeria: pizzeria,
        orderManagement: OrderManagementSettings.defaults(),
        deliveryConfiguration: DeliveryConfigurationSettings.defaults(),
        branding: DisplayBrandingSettings.defaults(),
        kitchen: KitchenManagementSettings.defaults(),
        businessRules: BusinessRulesSettings.defaults(),
      );
}
