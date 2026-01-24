import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Service for caching simple app data to prevent loading flashes on startup
/// Caches key-value pairs like pizzeria name and logo URL
class AppCacheService {
  static const String _pizzeriaNameKey = 'cached_pizzeria_name';
  static const String _pizzeriaLogoKey = 'cached_pizzeria_logo';
  static const String _lastUpdateKey = 'cached_pizzeria_last_update';
  
  // Cache TTL (Time To Live) - refresh if older than this
  static const Duration cacheMaxAge = Duration(hours: 24);

  /// Save pizzeria basic info to cache
  static Future<void> cachePizzeriaInfo({
    required String? name,
    required String? logoUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (name != null) {
        await prefs.setString(_pizzeriaNameKey, name);
      }
      
      if (logoUrl != null) {
        await prefs.setString(_pizzeriaLogoKey, logoUrl);
      }
      
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      
      Logger.debug('Pizzeria info cached successfully', tag: 'AppCache');
    } catch (e) {
      Logger.error('Failed to cache pizzeria info: $e', tag: 'AppCache', error: e);
    }
  }

  /// Get cached pizzeria name
  static Future<String?> getCachedPizzeriaName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_pizzeriaNameKey);
      
      if (name != null) {
        Logger.debug('Loaded pizzeria name from cache: $name', tag: 'AppCache');
      }
      
      return name;
    } catch (e) {
      Logger.error('Failed to load cached pizzeria name: $e', tag: 'AppCache', error: e);
      return null;
    }
  }

  /// Get cached pizzeria logo URL
  static Future<String?> getCachedPizzeriaLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logo = prefs.getString(_pizzeriaLogoKey);
      
      if (logo != null) {
        Logger.debug('Loaded pizzeria logo from cache', tag: 'AppCache');
      }
      
      return logo;
    } catch (e) {
      Logger.error('Failed to load cached pizzeria logo: $e', tag: 'AppCache', error: e);
      return null;
    }
  }

  /// Check if cached settings are fresh (not expired)
  static Future<bool> isCacheFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      
      if (lastUpdate == null) return false;
      
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdate;
      final isFresh = cacheAge < cacheMaxAge.inMilliseconds;
      
      Logger.debug(
        'Cache age: ${Duration(milliseconds: cacheAge).inMinutes} minutes, fresh: $isFresh',
        tag: 'AppCache',
      );
      
      return isFresh;
    } catch (e) {
      Logger.error('Failed to check cache freshness: $e', tag: 'AppCache', error: e);
      return false;
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pizzeriaNameKey);
      await prefs.remove(_pizzeriaLogoKey);
      await prefs.remove(_lastUpdateKey);
      
      Logger.info('Cache cleared', tag: 'AppCache');
    } catch (e) {
      Logger.error('Failed to clear cache: $e', tag: 'AppCache', error: e);
    }
  }
}
