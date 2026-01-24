import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cities_service.dart';
import '../core/models/allowed_city_model.dart';
import 'organization_provider.dart';

part 'cities_provider.g.dart';

@riverpod
CitiesService citiesService(Ref ref) {
  return CitiesService();
}

@riverpod
class AllowedCities extends _$AllowedCities {
  @override
  Future<List<AllowedCityModel>> build() async {
    final service = ref.watch(citiesServiceProvider);
    final orgId = await ref.read(currentOrganizationProvider.future);
    return await service.getAllowedCities(organizationId: orgId);
  }

  Future<void> createCity({
    required String nome,
    required String cap,
    bool attiva = true,
  }) async {
    final orgId = await ref.read(currentOrganizationProvider.future);
    if (orgId == null) return;

    final service = ref.read(citiesServiceProvider);
    await service.createCity(
      nome: nome,
      cap: cap,
      organizationId: orgId,
      attiva: attiva,
    );

    ref.invalidateSelf();
  }

  Future<void> updateCity(String cityId, Map<String, dynamic> updates) async {
    final service = ref.read(citiesServiceProvider);
    final orgId = await ref.read(currentOrganizationProvider.future);
    if (orgId == null) return;

    await service.updateCity(
      cityId: cityId,
      updates: updates,
      organizationId: orgId,
    );
    ref.invalidateSelf();
  }

  Future<void> deleteCity(String cityId) async {
    final service = ref.read(citiesServiceProvider);
    final orgId = await ref.read(currentOrganizationProvider.future);
    if (orgId == null) return;

    await service.deleteCity(
      cityId: cityId,
      organizationId: orgId,
    );
    ref.invalidateSelf();
  }
}

@riverpod
class AllCities extends _$AllCities {
  @override
  Future<List<AllowedCityModel>> build() async {
    final service = ref.watch(citiesServiceProvider);
    final orgId = await ref.read(currentOrganizationProvider.future);
    return await service.getAllCities(organizationId: orgId);
  }
}
