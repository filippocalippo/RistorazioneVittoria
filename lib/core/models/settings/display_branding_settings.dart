// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'display_branding_settings.freezed.dart';
part 'display_branding_settings.g.dart';

@freezed
class DisplayBrandingSettings with _$DisplayBrandingSettings {
  const factory DisplayBrandingSettings({
    @JsonKey(name: 'mostra_allergeni') @Default(true) bool mostraAllergeni,
    @JsonKey(name: 'colore_primario') @Default('#FF6B35') String colorePrimario,
    @JsonKey(name: 'colore_secondario')
    @Default('#004E89')
    String coloreSecondario,
  }) = _DisplayBrandingSettings;

  const DisplayBrandingSettings._();

  factory DisplayBrandingSettings.fromJson(Map<String, dynamic> json) =>
      _$DisplayBrandingSettingsFromJson(json);

  factory DisplayBrandingSettings.defaults() => const DisplayBrandingSettings();
}
