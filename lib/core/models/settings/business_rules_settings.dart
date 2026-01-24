// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../utils/model_parsers.dart';

part 'business_rules_settings.freezed.dart';
part 'business_rules_settings.g.dart';

DateTime? _dateFromJson(dynamic value) => ModelParsers.parseDateTime(value);
String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();

@freezed
class BusinessRulesSettings with _$BusinessRulesSettings {
  const factory BusinessRulesSettings({
    @Default(true) bool attiva,
    @JsonKey(name: 'chiusura_temporanea')
    @Default(false)
    bool chiusuraTemporanea,
    @JsonKey(
      name: 'data_chiusura_da',
      fromJson: _dateFromJson,
      toJson: _dateToJson,
    )
    DateTime? dataChiusuraDa,
    @JsonKey(
      name: 'data_chiusura_a',
      fromJson: _dateFromJson,
      toJson: _dateToJson,
    )
    DateTime? dataChiusuraA,
  }) = _BusinessRulesSettings;

  const BusinessRulesSettings._();

  factory BusinessRulesSettings.fromJson(Map<String, dynamic> json) =>
      _$BusinessRulesSettingsFromJson(json);

  factory BusinessRulesSettings.defaults() => const BusinessRulesSettings();
}
