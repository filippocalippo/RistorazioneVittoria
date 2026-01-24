// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import '../utils/enums.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? nome,
    String? cognome,
    String? telefono,
    String? indirizzo,
    String? citta,
    String? cap,
    required UserRole ruolo,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'fcm_token') String? fcmToken,
    @Default(true) bool attivo,
    @JsonKey(name: 'ultimo_accesso') DateTime? ultimoAccesso,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

extension UserModelX on UserModel {
  String get nomeCompleto {
    if (nome != null && cognome != null) {
      return '$nome $cognome';
    }
    return nome ?? cognome ?? email;
  }

  bool get isStaff =>
      [UserRole.manager, UserRole.kitchen, UserRole.delivery].contains(ruolo);

  bool get isCustomer => ruolo == UserRole.customer;
}
