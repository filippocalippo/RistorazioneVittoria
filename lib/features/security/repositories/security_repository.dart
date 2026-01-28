import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/organization_provider.dart';

class SecurityRepository {
  final SupabaseClient _client;

  SecurityRepository(this._client);

  /// Get security settings for the current organization.
  /// RLS ensures only the user's current org settings are returned.
  /// After migration 012, organization_id is the primary key.
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

  /// Initialize or update security settings for the current organization.
  /// Note: After migration 012, organization_id is the PK and will be auto-set
  /// by the RLS policy using get_current_organization_id().
  Future<void> initializeSecurity({
    required String passwordHash,
    required String salt,
    required List<String> recoveryHashes,
  }) async {
    // Check if entry exists first
    final existing = await getSecuritySettings();

    if (existing != null) {
      // Update existing - RLS ensures only current org's row can be updated
      // After migration 012, organization_id is the PK
      await _client.from('dashboard_security').update({
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_hashes': recoveryHashes,
        'last_updated_at': DateTime.now().toIso8601String(),
        'updated_by': _client.auth.currentUser?.id,
      }).eq('organization_id', existing['organization_id']);
    } else {
      // Insert new - RLS will enforce organization_id = current org
      // We need to explicitly set organization_id for INSERT
      await _client.from('dashboard_security').insert({
        'organization_id': _getCurrentOrganizationId(),
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_hashes': recoveryHashes,
        'updated_by': _client.auth.currentUser?.id,
      });
    }
  }

  /// Update password for the current organization.
  Future<void> updatePassword({
    required String passwordHash,
    required String salt,
    required List<String> recoveryHashes,
  }) async {
    final existing = await getSecuritySettings();
    if (existing == null) throw Exception('Security settings not initialized');

    // Update using organization_id (PK after migration 012)
    await _client.from('dashboard_security').update({
      'password_hash': passwordHash,
      'salt': salt,
      'recovery_hashes': recoveryHashes,
      'last_updated_at': DateTime.now().toIso8601String(),
      'updated_by': _client.auth.currentUser?.id,
    }).eq('organization_id', existing['organization_id']);
  }

  /// Helper to get current organization ID from profile
  String? _getCurrentOrganizationId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // Get from current session/user profile
    // This is a fallback - ideally the caller should provide the orgId
    final profile = _client.auth.currentUser?.userMetadata;
    return profile?['current_organization_id'] as String?;
  }
}
