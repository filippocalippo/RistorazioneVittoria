import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_address_model.freezed.dart';
part 'user_address_model.g.dart';

@freezed
class UserAddressModel with _$UserAddressModel {
  const factory UserAddressModel({
    required String id,
    required String userId,
    String? allowedCityId,
    String? etichetta,
    required String indirizzo,
    required String citta,
    required String cap,
    String? note,
    @Default(false) bool isDefault,
    double? latitude,
    double? longitude,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _UserAddressModel;

  factory UserAddressModel.fromJson(Map<String, dynamic> json) =>
      _$UserAddressModelFromJson(json);
}

extension UserAddressModelX on UserAddressModel {
  String get displayLabel => etichetta ?? 'Indirizzo';
  
  String get fullAddress {
    final parts = [indirizzo, '$cap $citta'];
    return parts.join(', ');
  }
}
