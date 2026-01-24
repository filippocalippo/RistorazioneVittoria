import 'package:supabase_flutter/supabase_flutter.dart';
import 'env_config.dart';
import '../../core/utils/logger.dart';

/// Supabase configuration for single-tenant application
class SupabaseConfig {
  /// Supabase client singleton
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Initialize Supabase with credentials from .env
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
    
    Logger.info('✓ Supabase initialized', tag: 'Supabase');
  }
  
  /// Test Supabase connection (single-tenant - checks business_rules table)
  static Future<bool> testConnection() async {
    try {
      await client.from('business_rules').select('id').limit(1);
      Logger.info('✓ Supabase connection OK', tag: 'Supabase');
      return true;
    } catch (e) {
      Logger.error('❌ Supabase connection failed: $e', tag: 'Supabase', error: e);
      return false;
    }
  }
}
