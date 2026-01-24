import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';

/// A radial tier with radius in km and price
class RadialTier {
  double km;
  double price;
  Color color;

  RadialTier({required this.km, required this.price, required this.color});

  Map<String, dynamic> toJson() => {'km': km, 'price': price};

  factory RadialTier.fromMap(Map<String, dynamic> m, Color color) {
    return RadialTier(
      km: (m['km'] as num?)?.toDouble() ?? 0,
      price: (m['price'] as num?)?.toDouble() ?? 0,
      color: color,
    );
  }
}

/// Full-screen visual editor for radial delivery zones
class RadialZoneEditor extends StatefulWidget {
  final LatLng center;
  final List<Map<String, dynamic>> initialTiers;
  final double initialOuterPrice;
  final bool initialIsRadial;
  final Function(
    bool isRadial,
    List<Map<String, dynamic>> tiers,
    double outerPrice,
  )?
  onSave;

  const RadialZoneEditor({
    super.key,
    required this.center,
    required this.initialTiers,
    required this.initialOuterPrice,
    required this.initialIsRadial,
    this.onSave,
  });

  @override
  State<RadialZoneEditor> createState() => _RadialZoneEditorState();
}

class _RadialZoneEditorState extends State<RadialZoneEditor> {
  final MapController _mapController = MapController();
  late List<RadialTier> _tiers;
  late double _outerPrice;
  late bool _isRadial;
  int? _selectedTierIndex;
  int? _draggingTierIndex;
  bool _isSaving = false;

  // Colors for tiers (from inner to outer)
  static const List<Color> tierColors = [
    Color(0xFF10b981), // Green
    Color(0xFF3b82f6), // Blue
    Color(0xFFf59e0b), // Amber
    Color(0xFFef4444), // Red
    Color(0xFF8b5cf6), // Purple
    Color(0xFFec4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _isRadial = widget.initialIsRadial;
    _outerPrice = widget.initialOuterPrice;
    _initializeTiers();
  }

  void _initializeTiers() {
    _tiers = [];
    final sortedTiers = List<Map<String, dynamic>>.from(widget.initialTiers)
      ..sort(
        (a, b) => ((a['km'] as num?) ?? 0).compareTo((b['km'] as num?) ?? 0),
      );

    for (int i = 0; i < sortedTiers.length; i++) {
      _tiers.add(
        RadialTier.fromMap(sortedTiers[i], tierColors[i % tierColors.length]),
      );
    }

    // Add a default tier if none exist
    if (_tiers.isEmpty && _isRadial) {
      _addTier();
    }
  }

  void _addTier() {
    final newKm = _tiers.isEmpty ? 3.0 : (_tiers.last.km + 2.0);
    final newPrice = _tiers.isEmpty ? 2.0 : (_tiers.last.price + 1.0);
    setState(() {
      _tiers.add(
        RadialTier(
          km: newKm,
          price: newPrice,
          color: tierColors[_tiers.length % tierColors.length],
        ),
      );
      _selectedTierIndex = _tiers.length - 1;
    });
  }

  void _removeTier(int index) {
    setState(() {
      _tiers.removeAt(index);
      // Reassign colors
      for (int i = 0; i < _tiers.length; i++) {
        _tiers[i].color = tierColors[i % tierColors.length];
      }
      _selectedTierIndex = null;
    });
  }

  void _sortTiers() {
    _tiers.sort((a, b) => a.km.compareTo(b.km));
    // Reassign colors after sorting
    for (int i = 0; i < _tiers.length; i++) {
      _tiers[i].color = tierColors[i % tierColors.length];
    }
  }

  LatLng _calculatePointAtDistance(double km, double bearing) {
    const earthRadius = 6371.0; // km
    final lat1 = widget.center.latitude * math.pi / 180;
    final lon1 = widget.center.longitude * math.pi / 180;
    final angularDistance = km / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  double _calculateDistanceFromCenter(LatLng point) {
    const earthRadius = 6371.0; // km
    final lat1 = widget.center.latitude * math.pi / 180;
    final lon1 = widget.center.longitude * math.pi / 180;
    final lat2 = point.latitude * math.pi / 180;
    final lon2 = point.longitude * math.pi / 180;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  void _handleDrag(LatLng point) {
    if (_draggingTierIndex == null) return;

    final distance = _calculateDistanceFromCenter(point);
    setState(() {
      _tiers[_draggingTierIndex!].km =
          (distance * 10).round() / 10; // Round to 0.1 km
    });
  }

  void _handleDragEnd() {
    if (_draggingTierIndex != null) {
      setState(() {
        _sortTiers();
        _draggingTierIndex = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      _sortTiers();
      final tierMaps = _tiers.map((t) => t.toJson()).toList();
      widget.onSave?.call(_isRadial, tierMaps, _outerPrice);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Configura Zone di Consegna',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Save button
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(Icons.save_rounded, size: 18),
              label: Text(
                _isSaving ? 'Salvataggio...' : 'Salva',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left sidebar - Controls
          Container(
            width: 360,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Mode toggle
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isRadial
                                ? Icons.radar_rounded
                                : Icons.attach_money_rounded,
                            color: _isRadial
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tariffe Radiali',
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _isRadial
                                      ? 'Prezzo basato sulla distanza'
                                      : 'Prezzo fisso per tutte le consegne',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isRadial,
                            onChanged: (v) {
                              setState(() {
                                _isRadial = v;
                                if (v && _tiers.isEmpty) {
                                  _addTier();
                                }
                              });
                            },
                            activeTrackColor: AppColors.primary,
                            thumbColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return null;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tier list
                Expanded(
                  child: _isRadial ? _buildTierList() : _buildFixedFeeMessage(),
                ),

                // Add tier button
                if (_isRadial)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addTier,
                        icon: Icon(Icons.add_circle_outline, size: 20),
                        label: Text('Aggiungi Zona'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right side - Map
          Expanded(
            child: Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.center,
                    initialZoom: 12.5,
                    minZoom: 10.0,
                    maxZoom: 16.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPointerHover: (event, point) {
                      if (_draggingTierIndex != null) {
                        _handleDrag(point);
                      }
                    },
                    onTap: (tapPosition, point) {
                      if (_draggingTierIndex != null) {
                        _handleDragEnd();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.rotante.app',
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    // Radial circles (drawn from outer to inner)
                    if (_isRadial) CircleLayer(circles: _buildCircles()),
                    // Drag handles
                    if (_isRadial) MarkerLayer(markers: _buildDragHandles()),
                    // Center marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.center,
                          width: 56,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Instructions overlay
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _draggingTierIndex != null
                              ? 'Clicca sulla mappa per confermare'
                              : 'Trascina i cerchi per regolare il raggio',
                          style: AppTypography.captionSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Legend
                if (_isRadial && _tiers.isNotEmpty)
                  Positioned(
                    bottom: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: _buildLegend(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _tiers.length + 1, // +1 for outer zone
      itemBuilder: (context, index) {
        if (index == _tiers.length) {
          // Outer zone card
          return _buildOuterZoneCard();
        }
        return _buildTierCard(_tiers[index], index);
      },
    );
  }

  Widget _buildTierCard(RadialTier tier, int index) {
    final isSelected = _selectedTierIndex == index;
    final isDragging = _draggingTierIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected || isDragging
              ? tier.color.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected || isDragging ? tier.color : AppColors.border,
            width: isSelected || isDragging ? 2 : 1,
          ),
          boxShadow: isSelected || isDragging ? AppShadows.sm : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tier.color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppTypography.captionSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Zona ${index + 1}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Drag handle indicator
                if (isDragging)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tier.color,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'TRASCINANDO',
                      style: AppTypography.captionSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20),
                  color: AppColors.error,
                  onPressed: () => _removeTier(index),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Inputs
            Row(
              children: [
                // Distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distanza',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    tier.km.toStringAsFixed(1),
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'km',
                                    style: AppTypography.captionSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          // Drag to edit button
                          Tooltip(
                            message: 'Trascina sulla mappa',
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _draggingTierIndex = index;
                                  _selectedTierIndex = index;
                                });
                              },
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Container(
                                padding: EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: isDragging
                                      ? tier.color
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  border: Border.all(
                                    color: isDragging
                                        ? tier.color
                                        : AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  isDragging
                                      ? Icons.pan_tool_alt
                                      : Icons.open_with,
                                  size: 18,
                                  color: isDragging
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prezzo',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: tier.price.toStringAsFixed(2),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          prefixText: '€ ',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs + 2,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(color: tier.color, width: 2),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null) {
                            setState(() => tier.price = parsed);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Description
            Text(
              index == 0
                  ? 'Da 0 a ${tier.km.toStringAsFixed(1)} km dal locale'
                  : 'Da ${_tiers[index - 1].km.toStringAsFixed(1)} a ${tier.km.toStringAsFixed(1)} km dal locale',
              style: AppTypography.captionSmall.copyWith(color: tier.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOuterZoneCard() {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.public_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Fuori Zona',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: _outerPrice.toStringAsFixed(2),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Prezzo consegna fuori zone',
              prefixText: '€ ',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) {
                setState(() => _outerPrice = parsed);
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _tiers.isNotEmpty
                ? 'Per consegne oltre ${_tiers.last.km.toStringAsFixed(1)} km'
                : 'Per tutte le consegne',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedFeeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_money_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tariffa Fissa',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Attiva le tariffe radiali per\nconfiguare zone di consegna basate\nsulla distanza dal locale.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CircleMarker> _buildCircles() {
    // Sort descending so larger circles are drawn first
    final sortedIndices = List.generate(_tiers.length, (i) => i)
      ..sort((a, b) => _tiers[b].km.compareTo(_tiers[a].km));

    return sortedIndices.map((index) {
      final tier = _tiers[index];
      final isSelected = _selectedTierIndex == index;
      final isDragging = _draggingTierIndex == index;

      return CircleMarker(
        point: widget.center,
        radius: tier.km * 1000, // km to meters
        useRadiusInMeter: true,
        color: tier.color.withValues(
          alpha: isSelected || isDragging ? 0.25 : 0.12,
        ),
        borderColor: tier.color,
        borderStrokeWidth: isSelected || isDragging ? 3 : 2,
      );
    }).toList();
  }

  List<Marker> _buildDragHandles() {
    final markers = <Marker>[];

    for (int i = 0; i < _tiers.length; i++) {
      final tier = _tiers[i];
      final isSelected = _selectedTierIndex == i;
      final isDragging = _draggingTierIndex == i;

      // Place handles at 4 cardinal directions
      for (final bearing in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
        final point = _calculatePointAtDistance(tier.km, bearing);

        markers.add(
          Marker(
            point: point,
            width: isDragging ? 36 : 28,
            height: isDragging ? 36 : 28,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() {
                    _draggingTierIndex = i;
                    _selectedTierIndex = i;
                  });
                },
                onPanUpdate: (details) {
                  // This won't work well, we handle via map pointer events
                },
                onPanEnd: (_) => _handleDragEnd(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isDragging
                        ? tier.color
                        : (isSelected ? tier.color : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: tier.color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: tier.color.withValues(alpha: 0.4),
                        blurRadius: isDragging ? 12 : 6,
                        spreadRadius: isDragging ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.open_with,
                    size: isDragging ? 18 : 14,
                    color: isDragging || isSelected ? Colors.white : tier.color,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Add price label on one side
      final labelPoint = _calculatePointAtDistance(tier.km * 0.5, math.pi / 4);
      markers.add(
        Marker(
          point: labelPoint,
          width: 60,
          height: 28,
          child: IgnorePointer(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: tier.color,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: AppShadows.sm,
              ),
              child: Center(
                child: Text(
                  Formatters.currency(tier.price),
                  style: AppTypography.captionSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildLegend() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEGENDA',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._tiers.asMap().entries.map((entry) {
            final index = entry.key;
            final tier = entry.value;
            final fromKm = index == 0 ? 0.0 : _tiers[index - 1].km;
            return Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tier.color.withValues(alpha: 0.3),
                      border: Border.all(color: tier.color, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${fromKm.toStringAsFixed(1)}-${tier.km.toStringAsFixed(1)} km',
                    style: AppTypography.captionSmall,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Formatters.currency(tier.price),
                    style: AppTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tier.color,
                    ),
                  ),
                ],
              ),
            );
          }),
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.textSecondary,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '>${_tiers.last.km.toStringAsFixed(1)} km',
                  style: AppTypography.captionSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  Formatters.currency(_outerPrice),
                  style: AppTypography.captionSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
