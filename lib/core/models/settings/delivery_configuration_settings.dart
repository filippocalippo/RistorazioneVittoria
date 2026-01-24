// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_configuration_settings.freezed.dart';
part 'delivery_configuration_settings.g.dart';

@freezed
class DeliveryConfigurationSettings with _$DeliveryConfigurationSettings {
  const factory DeliveryConfigurationSettings({
    @JsonKey(name: 'organization_id') String? organizationId,
    @JsonKey(name: 'tipo_calcolo_consegna')
    @Default('fisso')
    String tipoCalcoloConsegna,
    @JsonKey(name: 'costo_consegna_base')
    @Default(3.0)
    double costoConsegnaBase,
    @JsonKey(name: 'costo_consegna_per_km')
    @Default(0.5)
    double costoConsegnaPerKm,
    @JsonKey(name: 'raggio_consegna_km') @Default(5.0) double raggioConsegnaKm,
    @JsonKey(name: 'consegna_gratuita_sopra')
    @Default(30.0)
    double consegnaGratuitaSopra,
    @JsonKey(name: 'tempo_consegna_stimato_min')
    @Default(30)
    int tempoConsegnaStimatoMin,
    @JsonKey(name: 'tempo_consegna_stimato_max')
    @Default(60)
    int tempoConsegnaStimatoMax,
    @JsonKey(name: 'zone_consegna_personalizzate')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> zoneConsegnaPersonalizzate,
    // Radial delivery fee tiers: [{"km": 3, "price": 2.0}, {"km": 5, "price": 5.0}]
    @JsonKey(name: 'costo_consegna_radiale')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> costoConsegnaRadiale,
    // Price for deliveries outside all defined radii
    @JsonKey(name: 'prezzo_fuori_raggio')
    @Default(0.0)
    double prezzoFuoriRaggio,
  }) = _DeliveryConfigurationSettings;

  const DeliveryConfigurationSettings._();

  factory DeliveryConfigurationSettings.fromJson(Map<String, dynamic> json) =>
      _$DeliveryConfigurationSettingsFromJson(json);

  factory DeliveryConfigurationSettings.defaults() =>
      const DeliveryConfigurationSettings();
}
