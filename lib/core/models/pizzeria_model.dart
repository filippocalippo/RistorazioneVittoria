import 'package:freezed_annotation/freezed_annotation.dart';

part 'pizzeria_model.freezed.dart';
part 'pizzeria_model.g.dart';

/// Business/organization settings model
///
/// In multi-tenant mode, nome and logoUrl are loaded dynamically
/// from the organization settings, not hardcoded constants.
@freezed
class PizzeriaModel with _$PizzeriaModel {
  const factory PizzeriaModel({
    required String id,

    /// Organization/pizzeria name (loaded dynamically)
    @Default('Rotante') String nome,

    /// Logo URL (loaded from organization settings)
    @Default('') String logoUrl,
    String? indirizzo,
    String? citta,
    String? cap,
    String? provincia,
    String? telefono,
    String? email,
    String? immagineCopertinaUrl,
    Map<String, dynamic>? orari,
    double? latitude,
    double? longitude,
    @Default(true) bool attiva,
    @Default(false) bool chiusuraTemporanea,
    DateTime? dataChiusuraDa,
    DateTime? dataChiusuraA,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _PizzeriaModel;

  factory PizzeriaModel.fromJson(Map<String, dynamic> json) =>
      _$PizzeriaModelFromJson(json);

  const PizzeriaModel._();
}
