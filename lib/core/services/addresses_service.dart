import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../config/supabase_config.dart';
import '../models/user_address_model.dart';
import '../exceptions/app_exceptions.dart';
import 'google_geocoding_service.dart';
import '../utils/logger.dart';

class AddressesService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<UserAddressModel>> getUserAddresses(
    String userId,
  ) async {
    try {
      final data = await _client
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return data.map((json) => _parseAddressFromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero indirizzi: ${e.message}');
    }
  }

  Future<UserAddressModel?> getDefaultAddress(
    String userId,
  ) async {
    try {
      final data = await _client
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      if (data == null) return null;
      return _parseAddressFromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore recupero indirizzo: ${e.message}');
    }
  }

  Future<UserAddressModel> createAddress({
    required String userId,
    String? allowedCityId,
    String? etichetta,
    required String indirizzo,
    required String citta,
    required String cap,
    String? note,
    bool isDefault = false,
    String? provincia,
  }) async {
    try {
      _ensureAddressIsValid(indirizzo);

      // Geocode the address before saving
      LatLng? coordinates;
      try {
        coordinates = await GoogleGeocodingService.geocodeAddress(
          indirizzo: indirizzo,
          citta: citta,
          cap: cap,
          provincia: provincia,
        );
        if (coordinates != null) {
          Logger.debug(
            'Geocoded new address successfully',
            tag: 'AddressesService',
          );
        }
      } catch (e) {
        Logger.warning(
          'Failed to geocode address during creation: $e',
          tag: 'AddressesService',
        );
      }

      final data = await _client
          .from('user_addresses')
          .insert({
            'user_id': userId,
            'allowed_city_id': allowedCityId,
            'etichetta': etichetta,
            'indirizzo': indirizzo,
            'citta': citta,
            'cap': cap,
            'note': note,
            'is_default': isDefault,
            if (coordinates != null) 'latitude': coordinates.latitude,
            if (coordinates != null) 'longitude': coordinates.longitude,
          })
          .select()
          .single();

      return _parseAddressFromJson(data);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore creazione indirizzo: ${e.message}');
    }
  }

  Future<void> updateAddress({
    required String addressId,
    required Map<String, dynamic> updates,
    String? provincia,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(updates);
      payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // If address fields changed, re-geocode
      final addressFieldsChanged = updates.containsKey('indirizzo') ||
          updates.containsKey('citta') ||
          updates.containsKey('cap');

      if (updates.containsKey('indirizzo')) {
        final updatedAddress = updates['indirizzo'];
        if (updatedAddress is String) {
          _ensureAddressIsValid(updatedAddress);
        }
      }

      if (addressFieldsChanged) {
        try {
          final coordinates = await GoogleGeocodingService.geocodeAddress(
            indirizzo: updates['indirizzo'] as String?,
            citta: updates['citta'] as String?,
            cap: updates['cap'] as String?,
            provincia: provincia,
          );
          if (coordinates != null) {
            payload['latitude'] = coordinates.latitude;
            payload['longitude'] = coordinates.longitude;
            Logger.debug(
              'Re-geocoded updated address',
              tag: 'AddressesService',
            );
          }
        } catch (e) {
          Logger.warning(
            'Failed to geocode address during update: $e',
            tag: 'AddressesService',
          );
        }
      }

      await _client
          .from('user_addresses')
          .update(payload)
          .eq('id', addressId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore aggiornamento indirizzo: ${e.message}');
    }
  }

  Future<void> deleteAddress({
    required String addressId,
  }) async {
    try {
      await _client
          .from('user_addresses')
          .delete()
          .eq('id', addressId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore eliminazione indirizzo: ${e.message}');
    }
  }

  Future<void> setDefaultAddress({
    required String addressId,
    required String userId,
  }) async {
    try {
      // The trigger will handle unsetting other defaults
      await _client
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', addressId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw DatabaseException('Errore impostazione predefinito: ${e.message}');
    }
  }

  /// Update geocoding coordinates for an existing address
  Future<void> updateGeocodingCoordinates({
    required String addressId,
    required String indirizzo,
    required String citta,
    required String cap,
    String? provincia,
  }) async {
    try {
      final coordinates = await GoogleGeocodingService.geocodeAddress(
        indirizzo: indirizzo,
        citta: citta,
        cap: cap,
        provincia: provincia,
      );

      if (coordinates != null) {
        await _client
            .from('user_addresses')
            .update({
              'latitude': coordinates.latitude,
              'longitude': coordinates.longitude,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', addressId);

        Logger.debug(
          'Updated missing geocoding for address record',
          tag: 'AddressesService',
        );
      }
    } catch (e) {
      Logger.warning(
        'Failed to update geocoding coordinates: $e',
        tag: 'AddressesService',
      );
    }
  }

  UserAddressModel _parseAddressFromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return UserAddressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      allowedCityId: json['allowed_city_id'] as String?,
      etichetta: json['etichetta'] as String?,
      indirizzo: json['indirizzo'] as String,
      citta: json['citta'] as String,
      cap: json['cap'] as String,
      note: json['note'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      createdAt: parseDateTime(json['created_at'])!,
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  void _ensureAddressIsValid(String indirizzo) {
    if (!_looksLikeValidAddress(indirizzo)) {
      throw ValidationException(
        'Indirizzo non valido. Includi nome via e numero civico.',
      );
    }
  }

  bool _looksLikeValidAddress(String? raw) {
    if (raw == null) return false;
    final value = raw.trim();
    if (value.isEmpty || value.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    return hasLetter && hasDigit && parts.length >= 2;
  }
}
