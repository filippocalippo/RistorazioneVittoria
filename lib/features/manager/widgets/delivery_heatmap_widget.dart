import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/heatmap_data_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../core/services/google_geocoding_service.dart';

/// Advanced delivery heatmap visualization widget
class DeliveryHeatmapWidget extends ConsumerStatefulWidget {
  final LatLng? pizzeriaCenter;

  const DeliveryHeatmapWidget({super.key, this.pizzeriaCenter});

  @override
  ConsumerState<DeliveryHeatmapWidget> createState() =>
      _DeliveryHeatmapWidgetState();
}

class _DeliveryHeatmapWidgetState extends ConsumerState<DeliveryHeatmapWidget> {
  final MapController _mapController = MapController();
  final StreamController<void> _rebuildStream =
      StreamController<void>.broadcast();

  // Heatmap configuration
  static final List<Map<double, MaterialColor>> _gradientPresets = [
    // Default: Blue to Red
    {
      0.25: Colors.blue,
      0.55: Colors.green,
      0.85: Colors.yellow,
      1.0: Colors.red,
    },
    // Alternative: Purple to Orange
    {
      0.25: Colors.purple,
      0.55: Colors.blue,
      0.85: Colors.orange,
      1.0: Colors.red,
    },
    // Cool: Cyan to Magenta
    {
      0.25: Colors.cyan,
      0.55: Colors.teal,
      0.85: Colors.amber,
      1.0: Colors.deepOrange,
    },
  ];

  int _currentGradientIndex = 0;
  double _radiusScale = 30.0;
  double _blur = 15.0;
  double _minOpacity = 0.05;

  LatLng? _currentCenter;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _loadPizzeriaCenter();
  }

  @override
  void dispose() {
    _rebuildStream.close();
    super.dispose();
  }

  Future<void> _loadPizzeriaCenter() async {
    if (widget.pizzeriaCenter != null) {
      setState(() => _currentCenter = widget.pizzeriaCenter);
      return;
    }

    try {
      final settings = await ref.read(pizzeriaSettingsProvider.future);
      if (settings == null || !mounted) return;

      final pizzeria = settings.pizzeria;

      if (pizzeria.latitude != null && pizzeria.longitude != null) {
        setState(() {
          _currentCenter = LatLng(pizzeria.latitude!, pizzeria.longitude!);
        });
      } else if (pizzeria.citta != null) {
        final coords = await GoogleGeocodingService.geocodeCity(
          citta: pizzeria.citta!,
          provincia: pizzeria.provincia,
        );
        if (mounted && coords != null) {
          setState(() => _currentCenter = coords);
        }
      }
    } catch (_) {
      // Fallback to default
    }
  }

  void _cycleGradient() {
    setState(() {
      _currentGradientIndex =
          (_currentGradientIndex + 1) % _gradientPresets.length;
    });
    _rebuildStream.add(null);
  }

  @override
  Widget build(BuildContext context) {
    final heatmapAsync = ref.watch(deliveryHeatmapDataProvider);

    return heatmapAsync.when(
      data: (data) => _buildContent(data),
      loading: () => _buildLoadingState(),
      error: (e, s) => _buildErrorState(e),
    );
  }

  Widget _buildContent(HeatmapData data) {
    return Row(
      children: [
        // Main map area
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              _buildMap(data),
              // Controls overlay
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: _buildMapControls(),
              ),
              // Legend overlay
              Positioned(
                bottom: AppSpacing.md,
                left: AppSpacing.md,
                child: _buildLegend(),
              ),
              // Settings panel
              if (_showSettings)
                Positioned(
                  top: 60,
                  right: AppSpacing.md,
                  child: _buildSettingsPanel(),
                ),
            ],
          ),
        ),
        // Stats sidebar
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: _buildStatsSidebar(data),
        ),
      ],
    );
  }

  Widget _buildMap(HeatmapData data) {
    final center =
        data.center ?? _currentCenter ?? const LatLng(41.9028, 12.4964);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 12.0,
          minZoom: 8.0,
          maxZoom: 18.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // Base tile layer
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.rotante.app',
            retinaMode: RetinaMode.isHighDensity(context),
          ),
          // Heatmap layer
          if (data.isNotEmpty)
            HeatMapLayer(
              heatMapDataSource: InMemoryHeatMapDataSource(data: data.points),
              heatMapOptions: HeatMapOptions(
                gradient: _gradientPresets[_currentGradientIndex],
                minOpacity: _minOpacity,
                blurFactor: _blur,
                radius: _radiusScale,
              ),
              reset: _rebuildStream.stream,
            ),
          // Pizzeria marker
          if (_currentCenter != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentCenter!,
                  width: 50,
                  height: 50,
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
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMapControls() {
    return Column(
      children: [
        // Settings toggle
        _buildControlButton(
          icon: Icons.tune_rounded,
          tooltip: 'Impostazioni',
          isActive: _showSettings,
          onTap: () => setState(() => _showSettings = !_showSettings),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Gradient switcher
        _buildControlButton(
          icon: Icons.palette_rounded,
          tooltip: 'Cambia Gradiente',
          onTap: _cycleGradient,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Zoom controls
        _buildControlButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom In',
          onTap: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom + 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildControlButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom Out',
          onTap: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom - 1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Center on pizzeria
        if (_currentCenter != null)
          _buildControlButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Centra su Pizzeria',
            onTap: () => _mapController.move(_currentCenter!, 13),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 4,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Impostazioni Heatmap',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Radius control
            Text(
              'Raggio: ${_radiusScale.toInt()}',
              style: AppTypography.labelSmall,
            ),
            Slider(
              value: _radiusScale,
              min: 10,
              max: 80,
              divisions: 14,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() => _radiusScale = v);
                _rebuildStream.add(null);
              },
            ),
            // Blur control
            Text(
              'Sfumatura: ${_blur.toInt()}',
              style: AppTypography.labelSmall,
            ),
            Slider(
              value: _blur,
              min: 5,
              max: 40,
              divisions: 7,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() => _blur = v);
                _rebuildStream.add(null);
              },
            ),
            // Opacity control
            Text(
              'Opacità min: ${(_minOpacity * 100).toInt()}%',
              style: AppTypography.labelSmall,
            ),
            Slider(
              value: _minOpacity,
              min: 0,
              max: 0.5,
              divisions: 10,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() => _minOpacity = v);
                _rebuildStream.add(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final gradient = _gradientPresets[_currentGradientIndex];
    final colors = gradient.values.toList();

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bassa',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(colors: colors),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Alta',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSidebar(HeatmapData data) {
    final stats = data.stats;
    final dateFormat = DateFormat('d MMM yyyy', 'it_IT');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistiche',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ultimi 2 mesi',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Main stats cards
          _buildStatCard(
            'Ordini Consegna',
            stats.totalOrders.toString(),
            Icons.shopping_bag_outlined,
            AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildStatCard(
            'Punti su Mappa',
            '${stats.geocodedOrders} (${stats.coveragePercent.toStringAsFixed(0)}%)',
            Icons.location_on_outlined,
            AppColors.success,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Date range
          if (stats.oldestOrder != null && stats.newestOrder != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${dateFormat.format(stats.oldestOrder!)} - ${dateFormat.format(stats.newestOrder!)}',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Top zone
          if (stats.topZone != null) ...[
            Text(
              'Zona più frequente',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      stats.topZone!,
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${stats.ordersByZone[stats.topZone]} ordini',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Peak hour
          if (stats.peakHour != null) ...[
            Text(
              'Orario di punta',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: 0.1),
                    AppColors.warning.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${stats.peakHour!.toString().padLeft(2, '0')}:00 - ${(stats.peakHour! + 1).toString().padLeft(2, '0')}:00',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  Text(
                    '${stats.ordersByHour[stats.peakHour]} ordini',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Zones breakdown
          if (stats.ordersByZone.isNotEmpty) ...[
            Text(
              'Distribuzione per zona',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...(stats.ordersByZone.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
                .map(
                  (e) => _buildZoneRow(e.key, e.value, stats.geocodedOrders),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRow(String zone, int count, int total) {
    final percent = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  zone,
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count (${(percent * 100).toStringAsFixed(0)}%)',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Caricamento dati heatmap...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Analisi ordini degli ultimi 2 mesi',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Errore caricamento heatmap',
              style: AppTypography.titleMedium.copyWith(color: AppColors.error),
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
            FilledButton.icon(
              onPressed: () => ref.invalidate(deliveryHeatmapDataProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
