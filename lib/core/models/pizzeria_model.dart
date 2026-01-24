import 'package:freezed_annotation/freezed_annotation.dart';
import '../utils/constants.dart';

part 'pizzeria_model.freezed.dart';
part 'pizzeria_model.g.dart';

@freezed
class PizzeriaModel with _$PizzeriaModel {
  const factory PizzeriaModel({
    required String id,
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
  
  // Getters for hardcoded pizzeria info
  String get nome => AppConstants.pizzeriaName;
  String get logoUrl => AppConstants.pizzeriaLogo;
}
