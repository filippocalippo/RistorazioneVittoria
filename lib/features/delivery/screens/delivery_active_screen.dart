import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/delivery_orders_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../widgets/delivery_shell.dart';
import '../widgets/completion_slider.dart';

/// State provider for expanded details
final detailsExpandedProvider = StateProvider<bool>((ref) => false);

/// Active delivery screen showing current delivery in progress
class DeliveryActiveScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const DeliveryActiveScreen({super.key, required this.order});

  @override
  ConsumerState<DeliveryActiveScreen> createState() =>
      _DeliveryActiveScreenState();
}

class _DeliveryActiveScreenState extends ConsumerState<DeliveryActiveScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final detailsExpanded = ref.watch(detailsExpandedProvider);
    final settingsAsync = ref.watch(pizzeriaSettingsProvider);

    final pizzeriaCenter =
        settingsAsync.value?.pizzeria.latitude != null &&
            settingsAsync.value?.pizzeria.longitude != null
        ? LatLng(
            settingsAsync.value!.pizzeria.latitude!,
            settingsAsync.value!.pizzeria.longitude!,
          )
        : null;

    final orderLocation =
        widget.order.latitudeConsegna != null &&
            widget.order.longitudeConsegna != null
        ? LatLng(
            widget.order.latitudeConsegna!,
            widget.order.longitudeConsegna!,
          )
        : null;

    return Stack(
      children: [
        // Background map
        _buildMap(pizzeriaCenter, orderLocation),

        // Back Button (top left)
        Positioned(
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          child: _buildFloatingButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              ref.read(deliveryViewProvider.notifier).state =
                  DeliveryView.queue;
            },
            color: AppColors.textPrimary,
          ),
        ),

        // Floating tools (top right)
        Positioned(
          top: AppSpacing.lg,
          right: AppSpacing.lg,
          child: Column(
            children: [
              _buildFloatingButton(
                icon: Icons.my_location_outlined,
                onTap: () => _centerMap(pizzeriaCenter, orderLocation),
                color: AppColors.primary,
              ),
            ],
          ),
        ),

        // Bottom sheet
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomSheet(detailsExpanded),
        ),
      ],
    );
  }

  Widget _buildMap(LatLng? pizzeriaCenter, LatLng? orderLocation) {
    final center =
        orderLocation ?? pizzeriaCenter ?? const LatLng(37.507877, 15.083012);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
        minZoom: 10.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rotante.app',
          retinaMode: RetinaMode.isHighDensity(context),
        ),

        // Route line if both points exist
        if (pizzeriaCenter != null && orderLocation != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [pizzeriaCenter, orderLocation],
                color: AppColors.success,
                strokeWidth: 4,
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            // Pizzeria marker
            if (pizzeriaCenter != null)
              Marker(
                point: pizzeriaCenter,
                width: 60,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

            // Destination marker
            if (orderLocation != null)
              Marker(
                point: orderLocation,
                width: 60,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.circular),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.circular),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: color ?? AppColors.textPrimary, size: 24),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(bool detailsExpanded) {
    final isCash =
        widget.order.metodoPagamento == PaymentMethod.cash &&
        !widget.order.pagato;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xxxl),
          topRight: Radius.circular(AppRadius.xxxl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          GestureDetector(
            onTap: () {
              ref.read(detailsExpandedProvider.notifier).state =
                  !detailsExpanded;
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Header info
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              'CONSEGNA CORRENTE',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.success,
                                fontWeight: AppTypography.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            widget.order.indirizzoConsegna ??
                                'Indirizzo non disponibile',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: AppTypography.extraBold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.order.nomeCliente,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: AppTypography.medium,
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
                          '€${widget.order.totale.toStringAsFixed(2)}',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                        if (isCash) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 12,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'CONTANTI',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: AppTypography.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Quick actions grid
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.navigation_outlined,
                      label: 'Mappa',
                      color: AppColors.info,
                      onTap: _launchNavigation,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _buildQuickAction(
                      icon: Icons.phone_outlined,
                      label: 'Chiama',
                      color: AppColors.success,
                      onTap: _launchPhoneCall,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _buildQuickAction(
                      icon: Icons.message_outlined,
                      label: 'Messaggio',
                      color: AppColors.primary,
                      onTap: _showQuickMessages,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _buildQuickAction(
                      icon: Icons.list_alt_outlined,
                      label: 'Articoli',
                      color: AppColors.textSecondary,
                      onTap: () {
                        ref.read(detailsExpandedProvider.notifier).state =
                            !detailsExpanded;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expanded content (notes & items)
          AnimatedSize(
            duration: AppAnimations.normal,
            curve: Curves.easeInOut,
            child: detailsExpanded
                ? _buildExpandedContent()
                : const SizedBox.shrink(),
          ),

          // Slider
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: CompletionSlider(onCompleted: _completeDelivery),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: AppTypography.semiBold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note card
            if (widget.order.note != null && widget.order.note!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warmWhite,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'NOTA',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.order.note!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: AppTypography.medium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Order items
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ARTICOLI ORDINE',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: AppTypography.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '#${widget.order.id.toString().padLeft(6, '0')}',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...widget.order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Center(
                              child: Text(
                                '${item.quantita}x',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: AppTypography.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              item.nomeProdotto,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: AppTypography.medium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centerMap(LatLng? pizzeriaCenter, LatLng? orderLocation) {
    if (pizzeriaCenter != null && orderLocation != null) {
      final bounds = LatLngBounds.fromPoints([pizzeriaCenter, orderLocation]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    } else if (orderLocation != null) {
      _mapController.move(orderLocation, 15);
    }
  }

  Future<void> _launchNavigation() async {
    // Construct the full address from parts
    final addressParts = [
      widget.order.indirizzoConsegna,
      widget.order.cittaConsegna,
      widget.order.capConsegna,
    ].where((part) => part != null && part.trim().isNotEmpty).toList();

    final String fullAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : (widget.order.latitudeConsegna != null &&
                  widget.order.longitudeConsegna != null
              ? '${widget.order.latitudeConsegna},${widget.order.longitudeConsegna}'
              : '');

    if (fullAddress.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indirizzo non disponibile'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final query = Uri.encodeComponent(fullAddress);

    // Use geo: scheme for Android Google Maps
    final geoUri = Uri.parse('geo:0,0?q=$query');

    try {
      await launchUrl(geoUri);
    } catch (e) {
      // Fallback to Google Maps web URL
      final webUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
      try {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossibile aprire la navigazione: $e2'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _launchPhoneCall() async {
    final url = Uri.parse('tel:${widget.order.telefonoCliente}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showQuickMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xxxl),
            topRight: Radius.circular(AppRadius.xxxl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messaggio Rapido',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildMessageButton(
              icon: Icons.access_time_rounded,
              message: "Arrivo tra 5 minuti.",
              context: context,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildMessageButton(
              icon: Icons.location_on_outlined,
              message: "Sono arrivato.",
              context: context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageButton({
    required IconData icon,
    required String message,
    required BuildContext context,
  }) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Messaggio inviato: $message'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeDelivery() async {
    try {
      // Complete the delivery
      await ref
          .read(deliveryOrdersProvider.notifier)
          .completeDelivery(widget.order.id);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consegnato! Guadagnato €${widget.order.totale.toStringAsFixed(2)}',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Clear active order and go back to queue
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          ref.read(activeDeliveryOrderProvider.notifier).state = null;
          ref.read(deliveryViewProvider.notifier).state = DeliveryView.queue;
          ref.read(detailsExpandedProvider.notifier).state = false;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel completamento della consegna: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
