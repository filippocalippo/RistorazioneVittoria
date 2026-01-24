import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../providers/delivery_orders_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../widgets/delivery_map_widget.dart';
import '../widgets/delivery_shell.dart';
import '../../../core/utils/enums.dart';

/// State provider for selected order on map
final selectedMapOrderProvider = StateProvider<OrderModel?>((ref) => null);

/// Global map view showing all assigned delivery orders
class DeliveryGlobalMapScreen extends ConsumerStatefulWidget {
  const DeliveryGlobalMapScreen({super.key});

  @override
  ConsumerState<DeliveryGlobalMapScreen> createState() => _DeliveryGlobalMapScreenState();
}

class _DeliveryGlobalMapScreenState extends ConsumerState<DeliveryGlobalMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(deliveryOrdersRealtimeProvider);
    final settingsAsync = ref.watch(pizzeriaSettingsProvider);
    final selectedOrder = ref.watch(selectedMapOrderProvider);

    return ordersAsync.when(
      data: (orders) {
        final pizzeriaCenter = settingsAsync.value?.pizzeria.latitude != null &&
                settingsAsync.value?.pizzeria.longitude != null
            ? LatLng(
                settingsAsync.value!.pizzeria.latitude!,
                settingsAsync.value!.pizzeria.longitude!,
              )
            : null;

        return _buildMapView(context, orders, pizzeriaCenter, selectedOrder);
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Errore nel caricamento della mappa',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error.toString(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(
    BuildContext context,
    List<OrderModel> orders,
    LatLng? pizzeriaCenter,
    OrderModel? selectedOrder,
  ) {
    // Build order locations map
    final orderLocations = <String, LatLng>{};
    for (final order in orders) {
      if (order.latitudeConsegna != null && order.longitudeConsegna != null) {
        orderLocations[order.id] = LatLng(
          order.latitudeConsegna!,
          order.longitudeConsegna!,
        );
      }
    }

    return Stack(
      children: [
        // Map
        DeliveryMapWidget(
          pizzeriaCenter: pizzeriaCenter,
          orderLocations: orderLocations,
          orders: orders,
          zones: const [], // No zones in delivery view
          selectedOrderId: selectedOrder?.id,
          onOrderTap: (order) {
            ref.read(selectedMapOrderProvider.notifier).state = order;
          },
          mapController: _mapController,
          showZones: false,
        ),

        // Floating back button
        Positioned(
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.circular),
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            child: InkWell(
              onTap: () {
                ref.read(deliveryViewProvider.notifier).state = DeliveryView.queue;
                ref.read(selectedMapOrderProvider.notifier).state = null;
              },
              borderRadius: BorderRadius.circular(AppRadius.circular),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Vista Lista',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom preview card
        if (selectedOrder != null)
          Positioned(
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _buildPreviewCard(selectedOrder),
          ),
      ],
    );
  }

  Widget _buildPreviewCard(OrderModel order) {
    final isCash = order.metodoPagamento == PaymentMethod.cash && !order.pagato;
    final isDelivering = order.stato == OrderStatus.delivering;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.indirizzoConsegna ?? 'Indirizzo non disponibile',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isDelivering ? 'In consegna' : 'Pronto per il ritiro',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '€${order.totale.toStringAsFixed(2)}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isCash
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      isCash ? 'CONTANTI' : 'PAGATO',
                      style: AppTypography.captionSmall.copyWith(
                        color: isCash ? AppColors.warning : AppColors.success,
                        fontWeight: AppTypography.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Switch to queue view
                ref.read(deliveryViewProvider.notifier).state = DeliveryView.queue;
                // Clear selection
                ref.read(selectedMapOrderProvider.notifier).state = null;
                
                // TODO: Scroll to and expand the selected order card
                // This would require passing a ScrollController and order ID
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                elevation: 0,
              ),
              child: const Text('Seleziona Ordine'),
            ),
          ),
        ],
      ),
    );
  }
}

