// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'kitchen_management_settings.freezed.dart';
part 'kitchen_management_settings.g.dart';

@freezed
class KitchenManagementSettings with _$KitchenManagementSettings {
  const factory KitchenManagementSettings({
    @JsonKey(name: 'stampa_automatica_ordini')
    @Default(false)
    bool stampaAutomaticaOrdini,
    @JsonKey(name: 'mostra_note_cucina') @Default(true) bool mostraNoteCucina,
    @JsonKey(name: 'alert_sonoro_nuovo_ordine')
    @Default(true)
    bool alertSonoroNuovoOrdine,
  }) = _KitchenManagementSettings;

  const KitchenManagementSettings._();

  factory KitchenManagementSettings.fromJson(Map<String, dynamic> json) =>
      _$KitchenManagementSettingsFromJson(json);

  factory KitchenManagementSettings.defaults() =>
      const KitchenManagementSettings();
}
