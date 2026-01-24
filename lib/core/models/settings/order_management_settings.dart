// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_management_settings.freezed.dart';
part 'order_management_settings.g.dart';

@freezed
class OrderManagementSettings with _$OrderManagementSettings {
  const factory OrderManagementSettings({
    @JsonKey(name: 'organization_id') String? organizationId,
    @JsonKey(name: 'ordini_consegna_attivi')
    @Default(true)
    bool ordiniConsegnaAttivi,
    @JsonKey(name: 'ordini_asporto_attivi')
    @Default(true)
    bool ordiniAsportoAttivi,
    @JsonKey(name: 'ordini_tavolo_attivi')
    @Default(true)
    bool ordiniTavoloAttivi,
    @JsonKey(name: 'ordine_minimo') @Default(10.0) double ordineMinimo,
    @JsonKey(name: 'tempo_preparazione_medio')
    @Default(30)
    int tempoPreparazioneMedio,
    // Legacy fields kept to satisfy generated code until codegen runs again.
    // They are excluded from JSON to avoid breaking API after DB migration.
    @JsonKey(
      name: 'max_ordini_simultanei',
      includeToJson: false,
      includeFromJson: false,
    )
    @Default(50)
    int maxOrdiniSimultanei,
    @JsonKey(
      name: 'accetta_ordini_programmati',
      includeToJson: false,
      includeFromJson: false,
    )
    @Default(true)
    bool accettaOrdiniProgrammati,
    @JsonKey(
      name: 'anticipo_massimo_ore',
      includeToJson: false,
      includeFromJson: false,
    )
    @Default(48)
    int anticipoMassimoOre,
    @JsonKey(name: 'tempo_slot_minuti') @Default(30) int tempoSlotMinuti,
    @JsonKey(name: 'pausa_ordini_attiva')
    @Default(false)
    bool pausaOrdiniAttiva,
    @JsonKey(name: 'accetta_pagamenti_contanti')
    @Default(true)
    bool accettaPagamentiContanti,
    @JsonKey(name: 'accetta_pagamenti_carta')
    @Default(true)
    bool accettaPagamentiCarta,
  }) = _OrderManagementSettings;

  const OrderManagementSettings._();

  factory OrderManagementSettings.fromJson(Map<String, dynamic> json) =>
      _$OrderManagementSettingsFromJson(json);

  factory OrderManagementSettings.defaults() => const OrderManagementSettings();
}
