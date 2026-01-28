// Sentry Integration Module for Supabase Edge Functions
// Provides centralized error tracking and performance monitoring
// Part of Section 8.2 Backend Production Readiness

import * as Sentry from "https://deno.land/x/sentry@7.82.0/mod.ts"

// Configuration
let SENTRY_INITIALIZED = false
const SENTRY_DSN = Deno.env.get('SENTRY_DSN_EDGE') || 'https://examplePublicKey@o0.ingest.sentry.io/0'
const SENTRY_ENVIRONMENT = Deno.env.get('SENTRY_ENVIRONMENT') || 'production'
const SENTRY_RELEASE = Deno.env.get('SENTRY_RELEASE') || '1.0.0'
const SENTRY_TRACES_SAMPLE_RATE = parseFloat(Deno.env.get('SENTRY_TRACES_SAMPLE_RATE') || '0.1')

// =============================================================================
// INITIALIZATION
// =============================================================================

/**
 * Initializes Sentry for error tracking
 * Should be called once at the start of each edge function invocation
 *
 * Note: Sentry.init() is idempotent, so calling it multiple times is safe
 * It will only initialize once per process
 */
export function initSentry(): void {
  if (SENTRY_INITIALIZED) {
    return
  }

  try {
    Sentry.init({
      dsn: SENTRY_DSN,
      environment: SENTRY_ENVIRONMENT,
      release: SENTRY_RELEASE,
      tracesSampleRate: SENTRY_TRACES_SAMPLE_RATE,

      // Edge Function specific settings
      integrations: [
        new Sentry.Integrations.Http({ tracing: true }),
        new Sentry.Integrations.FunctionToString(),
        new Sentry.Integrations.LinkedErrors(),
        new Sentry.Integrations.RequestData(),
      ],

      // Before send hook to filter sensitive data
      beforeSend(event, hint) {
        // Remove sensitive headers
        if (event.request?.headers) {
          delete event.request.headers['authorization']
          delete event.request.headers['x-api-key']
          delete event.request.headers['cookie']
        }

        // Add function context
        if (event.tags) {
          event.tags.runtime = 'edge-function'
          event.tags.edge_runtime = 'deno'
        }

        return event
      },

      // Before send transaction hook for performance
      beforeSendTransaction(event) {
        // Filter out successful transactions to save quota
        if (event.contexts?.trace?.op === 'http.server') {
          const status = (event as any).transaction
          // Only send slow transactions (>1s) or errors
          const duration = event.end_timestamp ? event.end_timestamp - event.start_timestamp : 0
          if (duration < 1 && !event.exception) {
            return null
          }
        }
        return event
      },

      // Debug mode for development
      debug: SENTRY_ENVIRONMENT === 'development',

      // Sample rate for errors (100% to catch all)
      sampleRate: 1.0,
    })

    SENTRY_INITIALIZED = true
    console.log('[Sentry] Initialized successfully')
  } catch (error) {
    console.error('[Sentry] Initialization failed:', error)
  }
}

// =============================================================================
// ERROR CAPTURE
// =============================================================================

/**
 * Captures an exception with additional context
 *
 * @param error - The error to capture
 * @param context - Additional context information
 * @param tags - Tags for filtering in Sentry
 * @returns The event ID
 */
export function captureException(
  error: Error | unknown,
  context?: {
    function?: string
    organizationId?: string
    userId?: string
    requestId?: string
    [key: string]: any
  },
  tags?: Record<string, string | number | boolean>
): string | undefined {
  if (!SENTRY_INITIALIZED) {
    console.error('[Sentry] Not initialized, cannot capture exception:', error)
    return undefined
  }

  try {
    const eventId = Sentry.captureException(error, {
      tags: {
        ...tags,
        ...(context?.function && { function: context.function }),
        ...(context?.organizationId && { organization_id: context.organizationId }),
        ...(context?.userId && { user_id: context.userId }),
      },
      extra: {
        ...context,
        timestamp: new Date().toISOString(),
      },
      user: context?.userId ? { id: context.userId } : undefined,
    })

    if (eventId) {
      console.log(`[Sentry] Captured exception: ${eventId}`)
    }

    return eventId
  } catch (err) {
    console.error('[Sentry] Failed to capture exception:', err)
    return undefined
  }
}

/**
 * Captures a message as an event
 *
 * @param message - The message to send
 * @param level - The severity level
 * @param context - Additional context
 * @returns The event ID
 */
export function captureMessage(
  message: string,
  level: 'fatal' | 'error' | 'warning' | 'log' | 'info' | 'debug' = 'info',
  context?: Record<string, any>
): string | undefined {
  if (!SENTRY_INITIALIZED) {
    console.log(`[Sentry] Not initialized, skipping message: [${level}] ${message}`)
    return undefined
  }

  try {
    const eventId = Sentry.captureMessage(message, {
      level,
      extra: {
        ...context,
        timestamp: new Date().toISOString(),
      },
    })

    if (eventId) {
      console.log(`[Sentry] Captured message: ${eventId}`)
    }

    return eventId
  } catch (err) {
    console.error('[Sentry] Failed to capture message:', err)
    return undefined
  }
}

// =============================================================================
// USER CONTEXT
// =============================================================================

/**
 * Sets the user context for subsequent events
 *
 * @param userId - The user's ID
 * @param email - The user's email
 * @param organizationId - The user's organization ID
 * @param additionalData - Any additional user data
 */
export function setUserContext(
  userId: string,
  email?: string,
  organizationId?: string,
  additionalData?: Record<string, any>
): void {
  if (!SENTRY_INITIALIZED) {
    return
  }

  try {
    Sentry.setUser({
      id: userId,
      email: email,
      ...(organizationId && { organization_id: organizationId }),
      ...additionalData,
    })
  } catch (error) {
    console.error('[Sentry] Failed to set user context:', error)
  }
}

/**
 * Clears the user context
 */
export function clearUserContext(): void {
  if (!SENTRY_INITIALIZED) {
    return
  }

  try {
    Sentry.setUser(null)
  } catch (error) {
    console.error('[Sentry] Failed to clear user context:', error)
  }
}

// =============================================================================
// BREADCRUMBS
// =============================================================================

/**
 * Adds a breadcrumb for tracking the execution path
 *
 * @param category - The category of breadcrumb
 * @param message - The breadcrumb message
 * @param data - Additional data
 * @param level - The severity level
 */
export function addBreadcrumb(
  category: string,
  message: string,
  data?: Record<string, any>,
  level: 'fatal' | 'error' | 'warning' | 'log' | 'info' | 'debug' = 'info'
): void {
  if (!SENTRY_INITIALIZED) {
    return
  }

  try {
    Sentry.addBreadcrumb({
      category,
      message,
      data,
      level,
      timestamp: Date.now() / 1000,
    })
  } catch (error) {
    console.error('[Sentry] Failed to add breadcrumb:', error)
  }
}

// =============================================================================
// PERFORMANCE TRACKING
// =============================================================================

/**
 * Starts a performance transaction
 *
 * @param name - The transaction name
 * @param op - The operation type (e.g., 'http.server', 'db.query')
 * @returns The transaction object (call .finish() to complete)
 */
export function startTransaction(
  name: string,
  op: string = 'edge-function'
): Sentry.Transaction | undefined {
  if (!SENTRY_INITIALIZED) {
    return undefined
  }

  try {
    const transaction = Sentry.startTransaction({
      name,
      op,
    })

    console.log(`[Sentry] Started transaction: ${name}`)
    return transaction
  } catch (error) {
    console.error('[Sentry] Failed to start transaction:', error)
    return undefined
  }
}

/**
 * Sets a transaction as the current active transaction
 *
 * @param transaction - The transaction to set as active
 */
export function setTransaction(transaction: Sentry.Transaction | undefined): void {
  if (!transaction) {
    return
  }

  try {
    Sentry.getCurrentHub().setScope((scope) => {
      scope.setTransaction(transaction)
      return scope
    })
  } catch (error) {
    console.error('[Sentry] Failed to set transaction:', error)
  }
}

/**
 * Adds a child span to a transaction
 *
 * @param parent - The parent transaction
 * @param op - The operation type
 * @param description - The span description
 * @returns The span object (call .finish() to complete)
 */
export function startSpan(
  parent: Sentry.Transaction,
  op: string,
  description: string
): Sentry.Span | undefined {
  if (!parent) {
    return undefined
  }

  try {
    return parent.startChild({
      op,
      description,
    })
  } catch (error) {
    console.error('[Sentry] Failed to start span:', error)
    return undefined
  }
}

// =============================================================================
// HEALTH CHECK
// =============================================================================

/**
 * Checks if Sentry is properly initialized and configured
 *
 * @returns True if Sentry is ready to capture events
 */
export function isSentryReady(): boolean {
  return SENTRY_INITIALIZED && !!SENTRY_DSN
}

/**
 * Gets the Sentry configuration (for debugging)
 *
 * @returns Configuration details (without sensitive data)
 */
export function getSentryConfig(): {
  initialized: boolean
  dsn: string
  environment: string
  release: string
  tracesSampleRate: number
} {
  return {
    initialized: SENTRY_INITIALIZED,
    dsn: SENTRY_DSN.replace(/@[^@]+\./, '@***.'), // Hide project ID
    environment: SENTRY_ENVIRONMENT,
    release: SENTRY_RELEASE,
    tracesSampleRate: SENTRY_TRACES_SAMPLE_RATE,
  }
}

// =============================================================================
// WRAPPER FUNCTION
// =============================================================================

/**
 * Wraps an async function with Sentry error tracking and performance monitoring
 *
 * @param fn - The function to wrap
 * @param context - Context for error reporting
 * @returns Wrapped function with Sentry tracking
 */
export function withSentry<T extends any[], R>(
  fn: (...args: T) => Promise<R>,
  context: {
    functionName: string
    organizationId?: string
    userId?: string
  }
): (...args: T) => Promise<R> {
  return async (...args: T): Promise<R> => {
    initSentry()

    const transaction = startTransaction(context.functionName, 'edge-function')

    try {
      const result = await fn(...args)
      return result
    } catch (error) {
      captureException(error, context, {
        function: context.functionName,
        organization_id: context.organizationId,
        user_id: context.userId,
      })
      throw error
    } finally {
      if (transaction) {
        transaction.finish()
      }
    }
  }
}

// =============================================================================
// EXPORTS
// =============================================================================

export const SentryLevels = {
  FATAL: 'fatal' as const,
  ERROR: 'error' as const,
  WARNING: 'warning' as const,
  LOG: 'log' as const,
  INFO: 'info' as const,
  DEBUG: 'debug' as const,
}

// Re-export Sentry types for convenience
export type { Transaction, Span, Breadcrumb, Hub } from "https://deno.land/x/sentry@7.82.0/mod.ts"
