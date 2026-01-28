// Version Management Module for Supabase Edge Functions
// Provides version tracking and client compatibility checking
// Part of Section 8.2 Backend Production Readiness

import { createClient } from 'supabase'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// =============================================================================
// INTERFACES
// =============================================================================

export interface VersionInfo {
  function_name: string
  version: string
  deployed_at: string
  is_active: boolean
  min_client_version?: string
  max_client_version?: string
  changelog?: string
}

export interface ClientVersion {
  major: number
  minor: number
  patch: number
  prerelease?: string
  build?: string
}

export interface CompatibilityResult {
  compatible: boolean
  client_version: string
  function_version: string
  min_version?: string
  max_version?: string
  reason?: string
}

// =============================================================================
// CURRENT FUNCTION VERSIONS
// =============================================================================

/**
 * Current version of this edge function
 * Each edge function should export their own FUNCTION_VERSION constant
 */
export const DEFAULT_FUNCTION_VERSION = '1.0.0'
export const DEFAULT_MIN_CLIENT_VERSION = '1.0.0'

// =============================================================================
// VERSION PARSING
// =============================================================================

/**
 * Parses a semantic version string
 * @param version - Version string (e.g., "1.2.0" or "1.2.0-beta.1")
 * @returns Parsed version object
 */
export function parseVersion(version: string): ClientVersion | null {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9.-]+))?(?:\+([a-zA-Z0-9.-]+))?$/)

  if (!match) {
    return null
  }

  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
    prerelease: match[4],
    build: match[5],
  }
}

/**
 * Compares two version strings
 * @param v1 - First version string
 * @param v2 - Second version string
 * @returns -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
 */
export function compareVersions(v1: string, v2: string): number {
  const parsed1 = parseVersion(v1)
  const parsed2 = parseVersion(v2)

  if (!parsed1 || !parsed2) {
    // If we can't parse, do string comparison
    return v1.localeCompare(v2)
  }

  // Compare major, minor, patch
  if (parsed1.major !== parsed2.major) {
    return Math.sign(parsed1.major - parsed2.major)
  }
  if (parsed1.minor !== parsed2.minor) {
    return Math.sign(parsed1.minor - parsed2.minor)
  }
  if (parsed1.patch !== parsed2.patch) {
    return Math.sign(parsed1.patch - parsed2.patch)
  }

  // If we have prerelease versions, they are lower than stable versions
  if (!parsed1.prerelease && parsed2.prerelease) {
    return 1
  }
  if (parsed1.prerelease && !parsed2.prerelease) {
    return -1
  }
  if (parsed1.prerelease && parsed2.prerelease) {
    return parsed1.prerelease.localeCompare(parsed2.prerelease)
  }

  return 0
}

/**
 * Checks if a version is compatible with a version range
 * @param version - Version to check
 * @param minVersion - Minimum version (inclusive)
 * @param maxVersion - Maximum version (inclusive, optional)
 * @returns True if version is in range
 */
export function isVersionInRange(
  version: string,
  minVersion: string,
  maxVersion?: string
): boolean {
  const minCompare = compareVersions(version, minVersion)
  if (minCompare < 0) {
    return false // Version is below minimum
  }

  if (maxVersion) {
    const maxCompare = compareVersions(version, maxVersion)
    if (maxCompare > 0) {
      return false // Version is above maximum
    }
  }

  return true
}

// =============================================================================
// VERSION RETRIEVAL
// =============================================================================

/**
 * Gets the current active version of a function
 * @param functionName - The function name
 * @returns Version info or null
 */
export async function getFunctionVersion(
  functionName: string
): Promise<VersionInfo | null> {
  try {
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data, error } = await supabaseAdmin
      .from('function_versions')
      .select('function_name, version, deployed_at, is_active, changelog')
      .eq('function_name', functionName)
      .eq('is_active', true)
      .order('deployed_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (error || !data) {
      console.warn(`[Version] No active version found for ${functionName}`)
      return null
    }

    // Get client compatibility info
    const { data: compatData } = await supabaseAdmin
      .from('function_client_compatibility')
      .select('min_client_version, max_client_version')
      .eq('function_name', functionName)
      .order('min_client_version', { ascending: false })
      .limit(1)
      .maybeSingle()

    return {
      ...data,
      min_client_version: compatData?.min_client_version,
      max_client_version: compatData?.max_client_version,
    }
  } catch (error) {
    console.error(`[Version] Error getting version for ${functionName}:`, error)
    return null
  }
}

/**
 * Gets all versions of a function (for rollback purposes)
 * @param functionName - The function name
 * @param limit - Maximum number of versions to return
 * @returns Array of version info
 */
export async function getFunctionVersions(
  functionName: string,
  limit: number = 5
): Promise<VersionInfo[]> {
  try {
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data, error } = await supabaseAdmin
      .from('function_versions')
      .select('*')
      .eq('function_name', functionName)
      .order('deployed_at', { ascending: false })
      .limit(limit)

    if (error) {
      console.error(`[Version] Error getting versions for ${functionName}:`, error)
      return []
    }

    return data || []
  } catch (error) {
    console.error(`[Version] Error getting versions for ${functionName}:`, error)
    return []
  }
}

// =============================================================================
// CLIENT COMPATIBILITY CHECKING
// =============================================================================

/**
 * Checks if a client version is compatible with a function
 * @param functionName - The function name
 * @param clientVersion - The client version string
 * @returns Compatibility result
 */
export async function checkClientCompatibility(
  functionName: string,
  clientVersion: string
): Promise<CompatibilityResult> {
  try {
    // Get function version info
    const versionInfo = await getFunctionVersion(functionName)

    if (!versionInfo) {
      // No version info found, assume compatible
      return {
        compatible: true,
        client_version: clientVersion,
        function_version: DEFAULT_FUNCTION_VERSION,
        reason: 'No version info available, assuming compatible',
      }
    }

    // Check if client version is in compatible range
    const minVersion = versionInfo.min_client_version || DEFAULT_MIN_CLIENT_VERSION
    const maxVersion = versionInfo.max_client_version

    const isCompatible = isVersionInRange(clientVersion, minVersion, maxVersion)

    return {
      compatible: isCompatible,
      client_version: clientVersion,
      function_version: versionInfo.version,
      min_version: minVersion,
      max_version: maxVersion,
      reason: isCompatible
        ? 'Client version is compatible'
        : `Client version ${clientVersion} is not in range [${minVersion}, ${maxVersion || 'unbounded'}]`,
    }
  } catch (error) {
    console.error(`[Version] Error checking compatibility:`, error)
    // On error, assume compatible to avoid breaking requests
    return {
      compatible: true,
      client_version: clientVersion,
      function_version: DEFAULT_FUNCTION_VERSION,
      reason: 'Compatibility check failed, assuming compatible',
    }
  }
}

/**
 * Validates client version from request headers
 * @param req - The HTTP request
 * @param functionName - The function name
 * @returns Compatibility result with appropriate HTTP response if incompatible
 */
export async function validateClientVersion(
  req: Request,
  functionName: string
): Promise<{ valid: boolean; response?: Response }> {
  const clientVersion = req.headers.get('X-Client-Version')

  // If no version header, assume compatible
  if (!clientVersion) {
    console.warn(`[Version] No X-Client-Version header for ${functionName}`)
    return { valid: true }
  }

  // Check compatibility
  const result = await checkClientCompatibility(functionName, clientVersion)

  if (!result.compatible) {
    // Return 426 Upgrade Required
    const response = new Response(
      JSON.stringify({
        error: 'Client version upgrade required',
        code: 'UPGRADE_REQUIRED',
        client_version: result.client_version,
        min_version: result.min_version,
        max_version: result.max_version,
        download_url: 'https://apps.apple.com/app/rotante', // TODO: Add actual app store URL
      }),
      {
        status: 426,
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Version': result.function_version,
        },
      }
    )

    return { valid: false, response }
  }

  return { valid: true }
}

// =============================================================================
// VERSION REGISTRATION
// =============================================================================

/**
 * Registers a new function version deployment
 * @param functionName - The function name
 * @param version - The version being deployed
 * @param changelog - Description of changes
 * @param rollbackVersion - Version to rollback to if needed
 */
export async function registerFunctionVersion(
  functionName: string,
  version: string,
  changelog?: string,
  rollbackVersion?: string
): Promise<void> {
  try {
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Mark all existing versions as inactive
    await supabaseAdmin
      .from('function_versions')
      .update({ is_active: false })
      .eq('function_name', functionName)

    // Insert new version
    await supabaseAdmin.from('function_versions').insert({
      function_name: functionName,
      version: version,
      deployed_at: new Date().toISOString(),
      is_active: true,
      rollback_version: rollbackVersion,
      changelog: changelog,
      metadata: {
        deployed_by: 'system', // TODO: Get actual user from auth context
      },
    })

    console.log(`[Version] Registered ${functionName} v${version}`)
  } catch (error) {
    console.error(`[Version] Error registering version:`, error)
  }
}

/**
 * Sets client compatibility requirements for a function
 * @param functionName - The function name
 * @param minVersion - Minimum client version
 * @param maxVersion - Maximum client version (optional)
 */
export async function setClientCompatibility(
  functionName: string,
  minVersion: string,
  maxVersion?: string
): Promise<void> {
  try {
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    await supabaseAdmin
      .from('function_client_compatibility')
      .upsert({
        function_name: functionName,
        min_client_version: minVersion,
        max_client_version: maxVersion || null,
      })

    console.log(`[Version] Set compatibility for ${functionName}: [${minVersion}, ${maxVersion || 'unbounded'}]`)
  } catch (error) {
    console.error(`[Version] Error setting compatibility:`, error)
  }
}

// =============================================================================
// ROLLBACK SUPPORT
// =============================================================================

/**
 * Rolls back to a previous version
 * @param functionName - The function name
 * @param targetVersion - The version to rollback to
 * @returns True if rollback was successful
 */
export async function rollbackToVersion(
  functionName: string,
  targetVersion: string
): Promise<boolean> {
  try {
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Deactivate current version
    await supabaseAdmin
      .from('function_versions')
      .update({ is_active: false })
      .eq('function_name', functionName)
      .eq('is_active', true)

    // Activate target version
    const { error } = await supabaseAdmin
      .from('function_versions')
      .update({ is_active: true })
      .eq('function_name', functionName)
      .eq('version', targetVersion)

    if (error) {
      console.error(`[Version] Rollback failed:`, error)
      return false
    }

    console.log(`[Version] Rolled back ${functionName} to v${targetVersion}`)
    return true
  } catch (error) {
    console.error(`[Version] Rollback error:`, error)
    return false
  }
}

// =============================================================================
// MIDDLEWARE
// =============================================================================

/**
 * Creates version checking middleware
 * @param functionName - The function name
 * @returns A middleware function
 */
export function createVersionMiddleware(functionName: string) {
  return async (req: Request): Promise<{ allowed: boolean; response?: Response }> => {
    return await validateClientVersion(req, functionName)
  }
}

// =============================================================================
// EXPORTS
// =============================================================================

export {
  parseVersion,
  compareVersions,
  isVersionInRange,
  getFunctionVersion,
  getFunctionVersions,
  checkClientCompatibility,
  validateClientVersion,
  registerFunctionVersion,
  setClientCompatibility,
  rollbackToVersion,
}

export type { VersionInfo, ClientVersion, CompatibilityResult }
