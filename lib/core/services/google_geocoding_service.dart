import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for geocoding addresses using Google Maps Geocoding API
/// Requires GOOGLE_MAPS_API_KEY in .env file
/// Pricing: Free tier includes 2,500 requests/day, then $5 per 1,000 requests
class GoogleGeocodingService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  
  // Cache to avoid repeated API calls for same addresses
  static final Map<String, LatLng?> _cache = {};

  /// Get the API key from environment
  static String get _apiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (key.isEmpty) {
      Logger.error(
        'GOOGLE_MAPS_API_KEY not found in .env file',
        tag: 'GoogleGeocodingService',
      );
    }
    return key;
  }

  /// Geocode an Italian address to coordinates using Google Maps API
  /// Returns null if geocoding fails or API key is missing
  static Future<LatLng?> geocodeAddress({
    String? indirizzo,
    String? citta,
    String? cap,
    String? provincia,
    LatLng? proximity,
  }) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      Logger.error(
        'Cannot geocode: Google Maps API key is missing',
        tag: 'GoogleGeocodingService',
      );
      return null;
    }

    final street = _normalize(indirizzo);
    final city = _normalize(citta);
    final postalCode = _normalize(cap);
    final province = _normalize(provincia);

    if (street == null && city == null && postalCode == null && province == null) {
      Logger.warning('Empty address for geocoding', tag: 'GoogleGeocodingService');
      return null;
    }

    // Build address string for Google
    final addressParts = <String>[];
    if (street != null) addressParts.add(street);
    if (city != null) addressParts.add(city);
    if (province != null) addressParts.add(province);
    if (postalCode != null) addressParts.add(postalCode);
    addressParts.add('Italia');
    
    final addressString = addressParts.join(', ');

    // Check cache first
    final cacheKey = _cacheKey(street, city, postalCode, province);
    if (_cache.containsKey(cacheKey)) {
      Logger.debug('Geocoding cache hit for: $cacheKey', tag: 'GoogleGeocodingService');
      return _cache[cacheKey];
    }

    try {
      // Build query parameters
      final queryParams = {
        'address': addressString,
        'key': apiKey,
        'region': 'it', // Bias results to Italy
        'language': 'it', // Use Italian language
      };

      // Add proximity bias if provided (location bias)
      if (proximity != null) {
        queryParams['location'] = '${proximity.latitude},${proximity.longitude}';
        queryParams['radius'] = '6000'; // 6km radius bias
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      
      Logger.debug('Geocoding request dispatched', tag: 'GoogleGeocodingService');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Geocoding request timeout');
        },
      );

      if (response.statusCode != 200) {
        Logger.warning(
          'Google Geocoding API returned status ${response.statusCode}',
          tag: 'GoogleGeocodingService',
        );
        _cache[cacheKey] = null;
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      // Handle different status codes
      if (status == 'ZERO_RESULTS') {
        Logger.warning(
          'Google Geocoding returned no results',
          tag: 'GoogleGeocodingService',
        );
        _cache[cacheKey] = null;
        return null;
      }

      if (status == 'OVER_QUERY_LIMIT') {
        Logger.error(
          'Google Geocoding API quota exceeded',
          tag: 'GoogleGeocodingService',
        );
        return null; // Don't cache, might work later
      }

      if (status == 'REQUEST_DENIED') {
        Logger.error(
          'Google Geocoding API request denied - check API key',
          tag: 'GoogleGeocodingService',
        );
        return null;
      }

      if (status == 'INVALID_REQUEST') {
        Logger.warning(
          'Invalid geocoding request (check address components)',
          tag: 'GoogleGeocodingService',
        );
        _cache[cacheKey] = null;
        return null;
      }

      if (status != 'OK') {
        Logger.warning(
          'Google Geocoding API returned status: $status',
          tag: 'GoogleGeocodingService',
        );
        return null;
      }

      // Parse results
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        Logger.warning(
          'Google Geocoding returned empty results',
          tag: 'GoogleGeocodingService',
        );
        _cache[cacheKey] = null;
        return null;
      }

      // Get the first result
      final firstResult = results.first as Map<String, dynamic>;
      final geometry = firstResult['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      if (location == null) {
        Logger.warning(
          'Google Geocoding result missing location data',
          tag: 'GoogleGeocodingService',
        );
        _cache[cacheKey] = null;
        return null;
      }

      final lat = location['lat'] as num?;
      final lng = location['lng'] as num?;

      if (lat == null || lng == null) {
        Logger.warning(
          'Google Geocoding result missing lat/lng',
          tag: 'GoogleGeocodingService',
        );
        _cache[cacheKey] = null;
        return null;
      }

      final coordinates = LatLng(lat.toDouble(), lng.toDouble());
      _cache[cacheKey] = coordinates;

      // Log location type for quality assessment
      final locationType = geometry?['location_type'] as String?;
      Logger.debug(
        'Geocoding response type: $locationType',
        tag: 'GoogleGeocodingService',
      );

      return coordinates;
    } catch (e, stackTrace) {
      Logger.error(
        'Error during Google geocoding: $e',
        tag: 'GoogleGeocodingService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Geocode just a city name
  static Future<LatLng?> geocodeCity({
    required String citta,
    String? provincia,
  }) async {
    return geocodeAddress(
      indirizzo: null,
      citta: citta,
      provincia: provincia,
    );
  }

  /// Clear the geocoding cache
  static void clearCache() {
    _cache.clear();
    Logger.info('Google geocoding cache cleared', tag: 'GoogleGeocodingService');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'addresses': _cache.keys.toList(),
    };
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _cacheKey(
    String? street,
    String? city,
    String? postalCode,
    String? province,
  ) {
    return [
      street?.toLowerCase() ?? '',
      city?.toLowerCase() ?? '',
      postalCode?.toLowerCase() ?? '',
      province?.toLowerCase() ?? '',
    ].join('|');
  }
}
