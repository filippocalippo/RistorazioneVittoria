import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/delivery_orders_provider.dart';
import '../widgets/delivery_shell.dart';
import '../widgets/delivery_order_card.dart';
import '../widgets/delivery_bottom_nav.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/config/supabase_config.dart';
import '../../../providers/auth_provider.dart';
import 'delivery_analytics_screen.dart';

/// Delivery Dashboard Screen - Queue view
/// Displays the driver's assigned orders in priority order
/// User can drag to reorder the delivery queue
class DeliveryDashboardScreen extends ConsumerStatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  ConsumerState<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState
    extends ConsumerState<DeliveryDashboardScreen> {
  // Local order list that user can reorder
  List<OrderModel> _orderedList = [];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(deliveryOrdersRealtimeProvider);

    return ordersAsync.when(
      data: (orders) => _buildContent(context, orders),
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (error, stack) => _buildErrorState(context, error),
    );
  }

  void _syncOrders(List<OrderModel> serverOrders) {
    // Create a map of server orders for quick lookup
    final serverOrderMap = {for (var o in serverOrders) o.id: o};

    // Remove orders that no longer exist on server
    _orderedList.removeWhere((order) => !serverOrderMap.containsKey(order.id));

    // Update existing orders with fresh data (preserving local order)
    _orderedList = _orderedList.map((order) {
      return serverOrderMap[order.id] ?? order;
    }).toList();

    // Add new orders that we haven't seen
    final existingIds = _orderedList.map((o) => o.id).toSet();
    final newOrders = serverOrders
        .where((o) => !existingIds.contains(o.id))
        .toList();

    // Sort new orders: delivering first, then by creation time
    newOrders.sort((a, b) {
      if (a.stato == OrderStatus.delivering &&
          b.stato != OrderStatus.delivering) {
        return -1;
      }
      if (a.stato != OrderStatus.delivering &&
          b.stato == OrderStatus.delivering) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    // Insert new orders at the beginning
    _orderedList.insertAll(0, newOrders);
  }

  Widget _buildContent(BuildContext context, List<OrderModel> orders) {
    // Sync with server orders while preserving local order
    _syncOrders(orders);

    return Column(
      children: [
        _buildHeader(context, _orderedList),
        Expanded(
          child: _orderedList.isEmpty
              ? _buildEmptyState()
              : _buildOrdersList(context, _orderedList),
        ),
        const DeliveryBottomNav(currentView: DeliveryView.queue),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<OrderModel> orders) {
    final totalCount = orders.length;

    // Calcolo ETA semplice: 15 minuti per ordine
    final estimatedMinutes = totalCount * 15;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl +
            MediaQuery.of(context).padding.top, // Add safe area top padding
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.xs,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSEGNE',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: AppTypography.extraBold,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        '$totalCount ORDINI',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: AppTypography.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '•   ~ $estimatedMinutes min',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppTypography.medium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Button column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Analytics Button
              Material(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DeliveryAnalyticsScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'ANALITICHE',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Scan Button
              Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                child: InkWell(
                  onTap: _scanQrCode,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'SCANSIONA',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, List<OrderModel> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with hint
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CODA PRIORITARIA',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: AppTypography.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Trascina per riordinare',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemCount: orders.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = _orderedList.removeAt(oldIndex);
                _orderedList.insert(newIndex, item);
              });
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final animValue = Curves.easeInOut.transform(animation.value);
                  final elevation = 4 + 8 * animValue;
                  final scale = 1.0 + 0.02 * animValue;
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final order = orders[index];
              final orderIndex = index + 1;
              final isRecommendedNext =
                  index == 0 && order.stato == OrderStatus.ready;

              return Padding(
                key: ValueKey(order.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: DeliveryOrderCard(
                  order: order,
                  index: orderIndex,
                  isRecommendedNext: isRecommendedNext,
                  showDragHandle: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Tutto completato!',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nessuna consegna attiva al momento',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Errore nel caricamento degli ordini',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error.toString(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(deliveryOrdersRealtimeProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const _SimpleScannerScreen()),
    );

    if (result != null && result is String) {
      if (!mounted) return;
      _assignOrder(result);
    }
  }

  Future<void> _assignOrder(String orderId) async {
    try {
      final user = ref.read(authProvider).value;
      if (user == null) return;

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifica ordine in corso...'),
            duration: Duration(milliseconds: 500),
          ),
        );
      }

      // Check current status of the order
      final orderResponse = await SupabaseConfig.client
          .from('ordini')
          .select('id, assegnato_delivery_id, numero_ordine')
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore: Ordine non trovato.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final assignedTo = orderResponse['assegnato_delivery_id'] as String?;
      final orderNumber = orderResponse['numero_ordine'];

      // Check if already assigned
      if (assignedTo != null) {
        if (assignedTo == user.id) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ordine #$orderNumber già assegnato a te.'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Attenzione: Ordine #$orderNumber già assegnato a un altro driver!',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
        return; // Stop here, do not re-assign
      }

      // Proceed to assign
      final updatedRow = await SupabaseConfig.client
          .from('ordini')
          .update({'assegnato_delivery_id': user.id})
          .eq('id', orderId)
          .select();

      if (updatedRow.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Impossibile assegnare: L\'ordine potrebbe non essere pronto o è stato modificato.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ordine #$orderNumber assegnato con successo!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore assegnazione: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _SimpleScannerScreen extends StatefulWidget {
  const _SimpleScannerScreen();

  @override
  State<_SimpleScannerScreen> createState() => _SimpleScannerScreenState();
}

class _SimpleScannerScreenState extends State<_SimpleScannerScreen> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona QR Ordine'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_hasScanned) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              _hasScanned = true;
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}
