import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/welcome_popup_manager.dart';
import '../../../providers/kitchen_orders_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart'; // Extension methods for safe variant access
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/widgets/error_boundary.dart';

/// High-performance kitchen orders screen optimized for 24/7 operation
/// Features: auto-retry on errors, periodic time updates, debounced actions, crash-safe variant parsing
class KitchenOrdersScreen extends ConsumerStatefulWidget {
  const KitchenOrdersScreen({super.key});

  @override
  ConsumerState<KitchenOrdersScreen> createState() => _KitchenOrdersScreenState();
}

class _KitchenOrdersScreenState extends ConsumerState<KitchenOrdersScreen> {
  Timer? _refreshTimer;
  Timer? _retryTimer;
  final Map<String, bool> _processingOrders = {};
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    // Periodic refresh every minute to update elapsed time displays
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    
    // Listen for stream errors and auto-retry
    ref.listenManual(kitchenOrdersRealtimeProvider, (prev, next) {
      next.when(
        data: (_) {
          _errorCount = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
        },
        loading: () {},
        error: (error, stack) {
          _errorCount++;
          if (_retryTimer == null && _errorCount < 10) {
            // Exponential backoff: 5s, 10s, 20s, 40s, max 60s
            final delay = Duration(seconds: (5 * (1 << (_errorCount - 1))).clamp(5, 60));
            _retryTimer = Timer(delay, () {
              if (mounted) {
                ref.invalidate(kitchenOrdersRealtimeProvider);
              }
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return ErrorBoundaryWithLogger(
      contextTag: 'KitchenOrdersScreen',
      child: authState.when(
      data: (user) {
        if (user == null) {
          return _buildSessionExpiredState(context);
        }

        final ordersState = ref.watch(kitchenOrdersRealtimeProvider);
        return ordersState.when(
          data: (_) {
            // Use the optimized grouped provider to avoid repeated filtering
            final grouped = ref.watch(groupedKitchenOrdersProvider);
            final confirmedOrders = grouped[OrderStatus.confirmed] ?? [];
            final preparingOrders = grouped[OrderStatus.preparing] ?? [];
            final readyOrders = grouped[OrderStatus.ready] ?? [];

            if (confirmedOrders.isEmpty && preparingOrders.isEmpty && readyOrders.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                // Compact stats bar
                _buildStatsBar(
                  confirmedOrders.length,
                  preparingOrders.length,
                  readyOrders.length,
                ),

                // Kanban columns
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildColumn(
                          context,
                          'DA FARE',
                          confirmedOrders,
                          AppColors.warning,
                          OrderStatus.confirmed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildColumn(
                          context,
                          'IN PREPARAZIONE',
                          preparingOrders,
                          AppColors.info,
                          OrderStatus.preparing,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildColumn(
                          context,
                          'PRONTI',
                          readyOrders,
                          AppColors.success,
                          OrderStatus.ready,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (error, stack) => _buildErrorState(error),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stack) => _buildAuthErrorState(error),
    ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: AppColors.success),
          SizedBox(height: 16),
          Text(
            'Nessun ordine',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Tutti gli ordini sono stati completati',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Errore caricamento${_errorCount > 0 ? ' (tentativo $_errorCount/10)' : ''}',
            style: const TextStyle(fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _errorCount = 0;
              _retryTimer?.cancel();
              _retryTimer = null;
              ref.invalidate(kitchenOrdersRealtimeProvider);
            },
            child: const Text('Riprova ora'),
          ),
          if (_retryTimer != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Tentativo automatico in corso...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            'Errore autenticazione',
            style: TextStyle(fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(authProvider),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionExpiredState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 64, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text(
              'Sessione scaduta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Accedi nuovamente per continuare a ricevere gli ordini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await WelcomePopupManager.reset();
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sessione terminata. Effettua di nuovo l\'accesso.'),
                    ),
                  );
                }
              },
              child: const Text('Vai al login'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(authProvider),
              child: const Text('Riprova il collegamento'),
            ),
          ],
        ),
      ),
    );
  }

  // Compact stats bar
  Widget _buildStatsBar(int confirmed, int preparing, int ready) {
    return Container(
      height: 50,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatItem('DA FARE', confirmed, AppColors.warning),
          const SizedBox(width: 24),
          _buildStatItem('IN PREP', preparing, AppColors.info),
          const SizedBox(width: 24),
          _buildStatItem('PRONTI', ready, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Column builder
  Widget _buildColumn(
    BuildContext context,
    String title,
    List<OrderModel> orders,
    Color color,
    OrderStatus status,
  ) {
    return Container(
      color: color.withValues(alpha: 0.05),
      child: Column(
        children: [
          Container(
            height: 40,
            color: color.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${orders.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? const Center(
                    child: Text(
                      'Vuoto',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(context, orders[index], status);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Order card with full details and crash-safe variant parsing
  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    OrderStatus status,
  ) {
    final elapsed = order.elapsedTime;
    final minutes = elapsed?.inMinutes ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: minutes == 0 ? AppColors.error : AppColors.border,
          width: minutes == 0 ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                '#${order.displayNumeroOrdine}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (elapsed != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getTimeColor(minutes),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatTime(elapsed),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                order.tipo == OrderType.delivery ? '🚚 Consegna' : '🏪 Ritiro',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.nomeCliente,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Scheduled slot display
              if (order.slotPrenotatoStart != null) ...[
                Builder(builder: (context) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '🕐 ${Formatters.time(order.slotPrenotatoStart!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
          if (order.telefonoCliente.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              order.telefonoCliente,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const Divider(height: 16),

          // Order items with full details
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantita}x',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title format: Category-Name-Size (using safe accessors)
                        Text(
                          item.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Display added ingredients (using safe accessors)
                        if (item.addedIngredients.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          ...item.addedIngredients.map((ing) {
                            final name = ing['name'] as String? ?? '';
                            final quantity = ing['quantity'] ?? 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                '➕ $name x$quantity',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            );
                          }),
                        ],
                        // Display removed ingredients (using safe accessors)
                        if (item.removedIngredients.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          ...item.removedIngredients.map((ing) {
                            final name = ing['name'] as String? ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                '❌ SENZA $name',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            );
                          }),
                        ],
                        // Display note from variants or fallback to item note (using safe accessors)
                        if (item.variantNote.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '📝 ${item.variantNote}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ] else if (item.note != null &&
                            item.note!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '📝 ${item.note}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    Formatters.currency(item.subtotale),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 16),

          // Total
          Row(
            children: [
              const Text(
                'TOTALE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                Formatters.currency(order.totale),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          // Order notes
          if (order.note != null && order.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.note!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action button with debouncing to prevent double-taps
          if (status != OrderStatus.ready) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _processingOrders[order.id] == true
                    ? null
                    : () {
                        final messenger = ScaffoldMessenger.of(context);
                        _onOrderActionPressed(messenger, status, order);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == OrderStatus.confirmed
                      ? AppColors.info
                      : AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _processingOrders[order.id] == true
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        status == OrderStatus.confirmed
                            ? 'INIZIA PREPARAZIONE'
                            : 'SEGNA COME PRONTO',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onOrderActionPressed(
    ScaffoldMessengerState messenger,
    OrderStatus status,
    OrderModel order,
  ) async {
    // Set processing state to prevent concurrent calls
    setState(() {
      _processingOrders[order.id] = true;
    });

    try {
      if (status == OrderStatus.confirmed) {
        await ref
            .read(kitchenOrdersProvider.notifier)
            .startPreparing(order.id);
      } else if (status == OrderStatus.preparing) {
        await ref
            .read(kitchenOrdersProvider.notifier)
            .markAsReady(order.id);
      }
    } on AuthException catch (e) {
      // Don't immediately log out - allow retry first
      _showSnack(messenger, '${e.message} Riprova o riaccedi.');
      // Only invalidate auth to trigger re-check, don't force logout
      ref.invalidate(authProvider);
    } on AppException catch (e) {
      _showSnack(messenger, e.message);
    } catch (e) {
      _showSnack(messenger, 'Errore: ${e.toString()}');
    } finally {
      // Clear processing state after completion or error
      if (mounted) {
        setState(() {
          _processingOrders[order.id] = false;
        });
      }
    }
  }

  void _showSnack(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _getTimeColor(int minutes) {
    if (minutes == 0) return AppColors.error;  // No time left
    if (minutes < 5) return AppColors.warning;  // Less than 5 minutes left
    return AppColors.success;  // Plenty of time remaining
  }

  String _formatTime(Duration duration) {
    if (duration.inMinutes >= 60) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h${minutes}m';
      }
    } else {
      return '${duration.inMinutes}min';
    }
  }
}
