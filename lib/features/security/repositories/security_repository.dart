import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityRepository {
  final SupabaseClient _client;

  SecurityRepository(this._client);

  Future<Map<String, dynamic>?> getSecuritySettings() async {
    try {
      final response = await _client
          .from('dashboard_security')
          .select()
          .maybeSingle();
      return response;
    } catch (e) {
      // If table doesn't exist or RLS blocks it, return null
      return null;
    }
  }

  Future<void> initializeSecurity({
    required String passwordHash,
    required String salt,
    required List<String> recoveryHashes,
  }) async {
    // Check if entry exists first
    final existing = await getSecuritySettings();

    if (existing != null) {
      await _client.from('dashboard_security').update({
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_hashes': recoveryHashes,
        'last_updated_at': DateTime.now().toIso8601String(),
        'updated_by': _client.auth.currentUser?.id,
      }).eq('id', existing['id']);
    } else {
      await _client.from('dashboard_security').insert({
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_hashes': recoveryHashes,
        'updated_by': _client.auth.currentUser?.id,
      });
    }
  }

  Future<void> updatePassword({
    required String passwordHash,
    required String salt,
    required List<String> recoveryHashes,
  }) async {
    // We assume ID is fetched or we just update the single row allowed by RLS
    // But better to fetch ID first to be safe
    final existing = await getSecuritySettings();
    if (existing == null) throw Exception('Security settings not initialized');

    await _client.from('dashboard_security').update({
      'password_hash': passwordHash,
      'salt': salt,
      'recovery_hashes': recoveryHashes,
      'last_updated_at': DateTime.now().toIso8601String(),
      'updated_by': _client.auth.currentUser?.id,
    }).eq('id', existing['id']);
  }
}
