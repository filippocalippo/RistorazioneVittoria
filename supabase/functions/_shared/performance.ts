// Performance Tracking Module for Supabase Edge Functions
// Provides utilities for measuring and reporting execution times
// Part of Section 8.2 Backend Production Readiness

import * as Sentry from "https://deno.land/x/sentry@7.82.0/mod.ts"

// Configuration
const ALERT_THRESHOLDS = {
  edge_function_ms: 3000,      // Alert if edge function takes > 3s
  database_query_ms: 500,      // Alert if DB query takes > 500ms
  external_api_ms: 1000,       // Alert if external API takes > 1s
  stripe_api_ms: 1000,         // Alert if Stripe API takes > 1s
  firebase_api_ms: 500,        // Alert if Firebase API takes > 500ms
}

// =============================================================================
// PERFORMANCE TRACKER CLASS
// =============================================================================

/**
 * Tracks execution time of operations
 * Automatically reports to Sentry and logs slow operations
 */
export class PerformanceTracker {
  private startTime: number
  private operation: string
  private tags: Record<string, string>
  private ended = false

  /**
   * Creates a new performance tracker
   *
   * @param operation - The operation name (e.g., 'database_query', 'stripe_api_call')
   * @param tags - Optional tags for filtering
   */
  constructor(operation: string, tags: Record<string, string> = {}) {
    this.operation = operation
    this.tags = tags
    this.startTime = performance.now()

    // Add breadcrumb for visibility
    try {
      Sentry.addBreadcrumb({
        category: 'perf',
        message: `Started: ${operation}`,
        level: 'info',
        data: tags,
      })
    } catch {
      // Ignore Sentry errors
    }
  }

  /**
   * Ends the tracking and reports the duration
   *
   * @param additionalData - Optional additional data to include in report
   * @returns The duration in milliseconds
   */
  end(additionalData?: Record<string, any>): number {
    if (this.ended) {
      console.warn(`[Performance] Already ended tracking for ${this.operation}`)
      return 0
    }

    const endTime = performance.now()
    const duration = endTime - this.startTime
    this.ended = true

    // Determine if this is slow
    const threshold = this.getThreshold()
    const isSlow = duration > threshold

    // Log the result
    const logLevel = isSlow ? 'warn' : 'info'
    console[logLevel](`[Performance] ${this.operation}: ${duration.toFixed(2)}ms${isSlow ? ' (SLOW!)' : ''}`)

    // Add breadcrumb with result
    try {
      Sentry.addBreadcrumb({
        category: 'perf',
        message: `${this.operation} completed`,
        level: isSlow ? 'warning' : 'info',
        data: {
          duration_ms: duration,
          threshold_ms: threshold,
          slow: isSlow,
          ...this.tags,
          ...additionalData,
        },
      })
    } catch {
      // Ignore Sentry errors
    }

    // If very slow, also capture as a message
    if (duration > threshold * 2) {
      console.error(`[Performance] CRITICAL SLOW: ${this.operation} took ${duration.toFixed(2)}ms`)
      try {
        Sentry.captureMessage(
          `Performance Alert: ${this.operation} took ${duration.toFixed(2)}ms`,
          'warning',
          {
            duration_ms: duration,
            threshold_ms: threshold,
            operation: this.operation,
            tags: this.tags,
            ...additionalData,
          }
        )
      } catch {
        // Ignore Sentry errors
      }
    }

    return duration
  }

  /**
   * Ends the tracking and returns a promise with the duration
   * Useful for async operations
   *
   * @param additionalData - Optional additional data
   * @returns Promise resolving to the duration
   */
  async endAsync(additionalData?: Record<string, any>): Promise<number> {
    return this.end(additionalData)
  }

  /**
   * Gets the threshold for this operation type
   */
  private getThreshold(): number {
    // Check thresholds by operation type
    const op = this.operation.toLowerCase()

    if (op.includes('database') || op.includes('db')) {
      return ALERT_THRESHOLDS.database_query_ms
    }
    if (op.includes('stripe')) {
      return ALERT_THRESHOLDS.stripe_api_ms
    }
    if (op.includes('firebase')) {
      return ALERT_THRESHOLDS.firebase_api_ms
    }
    if (op.includes('api') || op.includes('http')) {
      return ALERT_THRESHOLDS.external_api_ms
    }

    // Default to edge function threshold
    return ALERT_THRESHOLDS.edge_function_ms
  }

  /**
   * Gets the current elapsed time without ending tracking
   */
  getElapsed(): number {
    return performance.now() - this.startTime
  }
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Tracks an async operation
 *
 * @param operation - The operation name
 * @param fn - The async function to track
 * @param tags - Optional tags
 * @returns The result of the function
 */
export async function trackAsync<T>(
  operation: string,
  fn: () => Promise<T>,
  tags?: Record<string, string>
): Promise<T> {
  const tracker = new PerformanceTracker(operation, tags)
  try {
    const result = await fn()
    tracker.end()
    return result
  } catch (error) {
    tracker.end({ error: String(error) })
    throw error
  }
}

/**
 * Tracks a synchronous operation
 *
 * @param operation - The operation name
 * @param fn - The function to track
 * @param tags - Optional tags
 * @returns The result of the function
 */
export function trackSync<T>(
  operation: string,
  fn: () => T,
  tags?: Record<string, string>
): T {
  const tracker = new PerformanceTracker(operation, tags)
  try {
    const result = fn()
    tracker.end()
    return result
  } catch (error) {
    tracker.end({ error: String(error) })
    throw error
  }
}

/**
 * Measures the duration of a database query
 *
 * @param queryType - The type of query (select, insert, update, delete)
 * @param tableName - The table being queried
 * @param fn - The query function
 * @returns The query result
 */
export async function trackQuery<T>(
  queryType: string,
  tableName: string,
  fn: () => Promise<T>
): Promise<T> {
  return trackAsync(
    `database_query`,
    fn,
    {
      query_type: queryType,
      table: tableName,
    }
  )
}

/**
 * Measures the duration of an external API call
 *
 * @param apiName - The name of the API (e.g., 'stripe', 'firebase')
 * @param endpoint - The endpoint being called
 * @param fn - The API call function
 * @returns The API result
 */
export async function trackApiCall<T>(
  apiName: string,
  endpoint: string,
  fn: () => Promise<T>
): Promise<T> {
  return trackAsync(
    `external_api_${apiName}`,
    fn,
    {
      api: apiName,
      endpoint: endpoint,
    }
  )
}

/**
 * Creates a middleware for tracking request duration
 * Useful for wrapping entire edge function handlers
 *
 * @param functionName - The name of the edge function
 * @returns A wrapper function
 */
export function createRequestTracker(functionName: string) {
  return function<T extends (...args: any[]) => Promise<any>>(
    handler: T
  ): T {
    return (async (...args: any[]) => {
      const tracker = new PerformanceTracker(functionName, {
        function: functionName,
      })

      try {
        const result = await handler(...args)
        tracker.end({ success: true })
        return result
      } catch (error) {
        tracker.end({
          success: false,
          error: String(error),
        })
        throw error
      }
    }) as T
  }
}

// =============================================================================
// MEMORY TRACKING (if available)
// =============================================================================

/**
 * Gets current memory usage (if available)
 * Returns undefined in environments that don't support it
 */
export function getMemoryUsage(): {
  used: number
  total: number
  limit: number
  percentage: number
} | undefined {
  try {
    // @ts-ignore - Deno-specific API
    if (typeof Deno !== 'undefined' && Deno.memoryUsage) {
      // @ts-ignore
      const usage = Deno.memoryUsage()
      return {
        used: usage.heapUsed || 0,
        total: usage.heapTotal || 0,
        limit: usage.heapLimit || 0,
        percentage: (usage.heapUsed / usage.heapLimit) * 100,
      }
    }
    return undefined
  } catch {
    return undefined
  }
}

/**
 * Tracks memory usage before and after an operation
 *
 * @param operation - The operation name
 * @param fn - The function to track
 * @returns The result
 */
export async function trackMemory<T>(
  operation: string,
  fn: () => Promise<T>
): Promise<T> {
  const before = getMemoryUsage()

  try {
    const result = await fn()
    const after = getMemoryUsage()

    if (before && after) {
      const delta = after.used - before.used
      const deltaStr = `${(delta / 1024 / 1024).toFixed(2)}MB`

      if (Math.abs(delta) > 1024 * 1024) { // More than 1MB difference
        console.log(`[Memory] ${operation}: ${deltaStr} change`)
      }

      try {
        Sentry.addBreadcrumb({
          category: 'memory',
          message: `Memory usage for ${operation}`,
          level: 'info',
          data: {
            before_mb: before.used / 1024 / 1024,
            after_mb: after.used / 1024 / 1024,
            delta_mb: delta / 1024 / 1024,
            percentage: after.percentage,
          },
        })
      } catch {
        // Ignore Sentry errors
      }
    }

    return result
  } catch (error) {
    throw error
  }
}

// =============================================================================
// PERFORMANCE REPORTING
// =============================================================================

/**
 * Generates a performance report for logging
 *
 * @param measurements - Map of operation names to durations
 * @returns Formatted report string
 */
export function generatePerformanceReport(
  measurements: Record<string, number>
): string {
  const lines = ['[Performance Report]', '='.repeat(50)]

  let totalDuration = 0
  const entries = Object.entries(measurements).sort((a, b) => b[1] - a[1])

  for (const [operation, duration] of entries) {
    totalDuration += duration
    const status = duration > ALERT_THRESHOLDS.edge_function_ms ? '❌ SLOW' : '✅ OK'
    lines.push(`  ${operation}: ${duration.toFixed(2)}ms ${status}`)
  }

  lines.push('='.repeat(50))
  lines.push(`  Total: ${totalDuration.toFixed(2)}ms`)

  return lines.join('\n')
}

// =============================================================================
// HEALTH CHECK
// =============================================================================

/**
 * Checks if the current performance is healthy
 *
 * @param measurements - Recent measurements
 * @returns Health status with details
 */
export function checkPerformanceHealth(
  measurements: Record<string, number>
): {
  healthy: boolean
  issues: string[]
} {
  const issues: string[] = []

  for (const [operation, duration] of Object.entries(measurements)) {
    const op = operation.toLowerCase()

    // Check database query performance
    if ((op.includes('database') || op.includes('db')) && duration > ALERT_THRESHOLDS.database_query_ms) {
      issues.push(`Slow database query: ${operation} (${duration.toFixed(2)}ms)`)
    }

    // Check external API performance
    if ((op.includes('stripe') || op.includes('firebase') || op.includes('api')) && duration > ALERT_THRESHOLDS.external_api_ms) {
      issues.push(`Slow external API: ${operation} (${duration.toFixed(2)}ms)`)
    }

    // Check overall function performance
    if (duration > ALERT_THRESHOLDS.edge_function_ms) {
      issues.push(`Slow operation: ${operation} (${duration.toFixed(2)}ms)`)
    }
  }

  return {
    healthy: issues.length === 0,
    issues,
  }
}

// =============================================================================
// EXPORTS
// =============================================================================

export { ALERT_THRESHOLDS }

// Re-export for convenience
export { PerformanceTracker }
