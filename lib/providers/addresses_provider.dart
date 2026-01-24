import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/addresses_service.dart';
import '../core/models/user_address_model.dart';
import 'auth_provider.dart';

part 'addresses_provider.g.dart';

@riverpod
AddressesService addressesService(Ref ref) {
  return AddressesService();
}

@riverpod
class UserAddresses extends _$UserAddresses {
  @override
  Future<List<UserAddressModel>> build() async {
    // Watch authProvider directly to ensure rebuild on auth changes
    final authState = ref.watch(authProvider);
    
    // If auth is still loading, return empty list and wait for rebuild
    if (authState.isLoading) {
      return [];
    }
    
    final user = authState.value;
    
    if (user == null) {
      return [];
    }

    final service = ref.watch(addressesServiceProvider);
    return await service.getUserAddresses(user.id);
  }

  Future<void> createAddress({
    String? allowedCityId,
    String? etichetta,
    required String indirizzo,
    required String citta,
    required String cap,
    String? note,
    bool isDefault = false,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final service = ref.read(addressesServiceProvider);
    await service.createAddress(
      userId: user.id,
      allowedCityId: allowedCityId,
      etichetta: etichetta,
      indirizzo: indirizzo,
      citta: citta,
      cap: cap,
      note: note,
      isDefault: isDefault,
    );

    ref.invalidateSelf();
  }

  Future<void> updateAddress(
    String addressId,
    Map<String, dynamic> updates,
  ) async {
    final service = ref.read(addressesServiceProvider);

    await service.updateAddress(
      addressId: addressId,
      updates: updates,
    );
    ref.invalidateSelf();
  }

  Future<void> deleteAddress(String addressId) async {
    final service = ref.read(addressesServiceProvider);

    await service.deleteAddress(
      addressId: addressId,
    );
    ref.invalidateSelf();
  }

  Future<void> setDefaultAddress(String addressId) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final service = ref.read(addressesServiceProvider);
    await service.setDefaultAddress(
      addressId: addressId,
      userId: user.id,
    );
    ref.invalidateSelf();
  }
}

@riverpod
Future<UserAddressModel?> defaultAddress(Ref ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;

  final service = ref.watch(addressesServiceProvider);
  return await service.getDefaultAddress(user.id);
}
