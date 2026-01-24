import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cities_service.dart';
import '../core/models/allowed_city_model.dart';
import 'auth_provider.dart';

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
    return await service.getAllowedCities();
  }

  Future<void> createCity({
    required String nome,
    required String cap,
    bool attiva = true,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final service = ref.read(citiesServiceProvider);
    await service.createCity(
      nome: nome,
      cap: cap,
      attiva: attiva,
    );

    ref.invalidateSelf();
  }

  Future<void> updateCity(String cityId, Map<String, dynamic> updates) async {
    final service = ref.read(citiesServiceProvider);
    final user = ref.read(authProvider).value;
    if (user == null) return;

    await service.updateCity(
      cityId: cityId,
      updates: updates,
    );
    ref.invalidateSelf();
  }

  Future<void> deleteCity(String cityId) async {
    final service = ref.read(citiesServiceProvider);
    final user = ref.read(authProvider).value;
    if (user == null) return;

    await service.deleteCity(
      cityId: cityId,
    );
    ref.invalidateSelf();
  }
}

@riverpod
class AllCities extends _$AllCities {
  @override
  Future<List<AllowedCityModel>> build() async {
    final service = ref.watch(citiesServiceProvider);
    return await service.getAllCities();
  }
}
