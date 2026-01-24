import 'package:freezed_annotation/freezed_annotation.dart';

part 'allowed_city_model.freezed.dart';
part 'allowed_city_model.g.dart';

@freezed
class AllowedCityModel with _$AllowedCityModel {
  const factory AllowedCityModel({
    required String id,
    required String nome,
    required String cap,
    @Default(true) bool attiva,
    @Default(0) int ordine,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _AllowedCityModel;

  factory AllowedCityModel.fromJson(Map<String, dynamic> json) =>
      _$AllowedCityModelFromJson(json);
}
