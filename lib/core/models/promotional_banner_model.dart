import 'package:freezed_annotation/freezed_annotation.dart';

part 'promotional_banner_model.freezed.dart';
part 'promotional_banner_model.g.dart';

@freezed
class PromotionalBannerModel with _$PromotionalBannerModel {
  const factory PromotionalBannerModel({
    @JsonKey(name: 'organization_id') String? organizationId,
    required String id,
    required String titolo,
    String? descrizione,
    @JsonKey(name: 'immagine_url') required String immagineUrl,
    @JsonKey(name: 'action_type') required String actionType,
    @JsonKey(name: 'action_data') required Map<String, dynamic> actionData,
    @JsonKey(name: 'text_overlay') Map<String, dynamic>? textOverlay,
    required bool attivo,
    @JsonKey(name: 'data_inizio') DateTime? dataInizio,
    @JsonKey(name: 'data_fine') DateTime? dataFine,
    @Default(0) int priorita,
    @Default(0) int ordine,
    @JsonKey(name: 'mostra_solo_mobile') @Default(false) bool mostraSoloMobile,
    @JsonKey(name: 'mostra_solo_desktop')
    @Default(false)
    bool mostraSoloDesktop,
    @Default(0) int visualizzazioni,
    @Default(0) int click,
    @JsonKey(name: 'is_sponsorizzato') @Default(false) bool isSponsorizzato,
    @JsonKey(name: 'sponsor_nome') String? sponsorNome,
    @JsonKey(name: 'sponsor_logo_url') String? sponsorLogoUrl,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'created_by') String? createdBy,
  }) = _PromotionalBannerModel;

  factory PromotionalBannerModel.fromJson(Map<String, dynamic> json) =>
      _$PromotionalBannerModelFromJson(json);
}

/// Action Type Enum
enum BannerActionType {
  externalLink('external_link'),
  internalRoute('internal_route'),
  product('product'),
  category('category'),
  specialOffer('special_offer'),
  none('none');

  const BannerActionType(this.value);
  final String value;

  static BannerActionType fromString(String value) {
    return BannerActionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BannerActionType.none,
    );
  }
}
