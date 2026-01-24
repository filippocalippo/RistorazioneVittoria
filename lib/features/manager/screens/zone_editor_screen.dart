import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/delivery_zone_model.dart';
import '../../../providers/delivery_zones_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/geometry_utils.dart';

/// Screen for creating and editing delivery zones
class ZoneEditorScreen extends ConsumerStatefulWidget {
  final LatLng? initialCenter;
  final DeliveryZoneModel? editingZone;

  const ZoneEditorScreen({
    super.key,
    this.initialCenter,
    this.editingZone,
  });

  @override
  ConsumerState<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends ConsumerState<ZoneEditorScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  
  List<LatLng> _polygonPoints = [];
  Color _selectedColor = AppColors.primary;
  bool _isDrawing = false;
  bool _isSaving = false;
  int? _selectedPointIndex;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    if (widget.editingZone != null) {
      _nameController.text = widget.editingZone!.name;
      _selectedColor = widget.editingZone!.color;
      _polygonPoints = List.from(widget.editingZone!.polygon);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _polygonPoints.clear();
      _selectedPointIndex = null;
      _errorMessage = null;
    });
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      if (widget.editingZone != null) {
        _polygonPoints = List.from(widget.editingZone!.polygon);
      } else {
        _polygonPoints.clear();
      }
      _selectedPointIndex = null;
      _errorMessage = null;
    });
  }

  void _finishDrawing() {
    if (_polygonPoints.length < 3) {
      setState(() {
        _errorMessage = 'La zona deve avere almeno 3 punti';
      });
      return;
    }

    setState(() {
      _isDrawing = false;
      _selectedPointIndex = null;
      _errorMessage = null;
    });
  }

  void _addPoint(LatLng point) {
    if (!_isDrawing) return;

    setState(() {
      _polygonPoints.add(point);
      _errorMessage = null;
    });
  }

  void _removePoint(int index) {
    if (_polygonPoints.length <= 3 && !_isDrawing) {
      setState(() {
        _errorMessage = 'Non puoi rimuovere punti: minimo 3 richiesti';
      });
      return;
    }

    setState(() {
      _polygonPoints.removeAt(index);
      _selectedPointIndex = null;
      _errorMessage = null;
    });
  }

  Future<void> _saveZone() async {
    // Validation
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Inserisci un nome per la zona');
      return;
    }

    if (_polygonPoints.length < 3) {
      setState(() => _errorMessage = 'La zona deve avere almeno 3 punti');
      return;
    }

    // Create zone model
    final orgId = await ref.read(currentOrganizationProvider.future);
    final zone = DeliveryZoneModel(
      id: widget.editingZone?.id ?? '',
      organizationId: orgId ?? widget.editingZone?.organizationId,
      name: _nameController.text.trim(),
      color: _selectedColor,
      polygon: _polygonPoints,
      displayOrder: widget.editingZone?.displayOrder ?? 0,
      isActive: true,
      createdAt: widget.editingZone?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Validate polygon
    if (!zone.isValidPolygon) {
      setState(() => _errorMessage = 'Poligono non valido: controlla che non ci siano intersezioni');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(deliveryZonesServiceProvider);
      
      if (widget.editingZone != null) {
        await service.updateZone(
          widget.editingZone!.id,
          zone,
          organizationId: orgId,
        );
      } else {
        await service.createZone(zone, organizationId: orgId);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.error('Failed to save zone', tag: 'ZoneEditor', error: e);
      setState(() {
        _errorMessage = 'Errore durante il salvataggio: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _pickColor() async {
    const availableColors = [
      Color(0xFFE74C3C), // Red
      Color(0xFFE67E22), // Orange
      Color(0xFFF39C12), // Yellow
      Color(0xFF27AE60), // Green
      Color(0xFF3498DB), // Blue
      Color(0xFF9B59B6), // Purple
      Color(0xFF1ABC9C), // Teal
      Color(0xFF34495E), // Dark Gray
      Color(0xFFE91E63), // Pink
      Color(0xFF00BCD4), // Cyan
      Color(0xFF8BC34A), // Light Green
      Color(0xFFFF5722), // Deep Orange
    ];

    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona Colore'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: availableColors.length,
            itemBuilder: (context, index) {
              final color = availableColors[index];
              final isSelected = color.toARGB32() == _selectedColor.toARGB32();
              
              return InkWell(
                onTap: () => Navigator.of(context).pop(color),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: isSelected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (pickedColor != null) {
      setState(() => _selectedColor = pickedColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter ?? const LatLng(37.507877, 15.083012);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          widget.editingZone != null ? 'Modifica Zona' : 'Nuova Zona',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _saveZone,
              icon: const Icon(Icons.check_rounded),
              tooltip: 'Salva',
            ),
        ],
      ),
      body: Column(
        children: [
          // Form section
          _buildFormSection(),
          
          // Error message
          if (_errorMessage != null) _buildErrorBanner(),
          
          // Drawing controls
          _buildDrawingControls(),
          
          // Map
          Expanded(
            child: _buildMap(center),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Name input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nome Zona',
              hintText: 'es. Centro, Periferia Nord',
              prefixIcon: const Icon(Icons.label_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Color picker
          InkWell(
            onTap: _pickColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text('Colore Zona'),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingControls() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          if (!_isDrawing && _polygonPoints.isEmpty)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startDrawing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_location_rounded),
                label: const Text('Inizia a Disegnare'),
              ),
            )
          else if (_isDrawing) ...[
            Expanded(
              child: Text(
                'Tocca la mappa per aggiungere punti (${_polygonPoints.length})',
                style: AppTypography.bodySmall,
              ),
            ),
            TextButton(
              onPressed: _cancelDrawing,
              child: const Text('Annulla'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: _polygonPoints.length >= 3 ? _finishDrawing : null,
              child: const Text('Completa'),
            ),
          ] else ...[
            Expanded(
              child: Text(
                '${_polygonPoints.length} punti',
                style: AppTypography.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _startDrawing,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Ridisegna'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(LatLng center) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            onTap: (_, point) {
              if (_isDrawing) {
                _addPoint(point);
              }
            },
            onLongPress: (_, point) {
              if (!_isDrawing && _polygonPoints.isNotEmpty) {
                // Find nearest point for editing
                double minDist = double.infinity;
                int? nearestIndex;
                
                for (int i = 0; i < _polygonPoints.length; i++) {
                  final dist = GeometryUtils.calculateDistance(_polygonPoints[i], point);
                  if (dist < minDist && dist < 50) { // 50 meters threshold
                    minDist = dist;
                    nearestIndex = i;
                  }
                }
                
                if (nearestIndex != null) {
                  setState(() => _selectedPointIndex = nearestIndex);
                }
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rotante.app',
            ),
            
            // Polygon layer
            if (_polygonPoints.isNotEmpty)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _polygonPoints,
                    color: _selectedColor.withValues(alpha: 0.3),
                    borderColor: _selectedColor,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            
            // Vertex markers
            if (_polygonPoints.isNotEmpty)
              MarkerLayer(
                markers: _polygonPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final isSelected = _selectedPointIndex == index;
                  
                  return Marker(
                    point: point,
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: GestureDetector(
                      onTap: () {
                        if (!_isDrawing) {
                          setState(() => _selectedPointIndex = index);
                        }
                      },
                      onLongPress: () {
                        if (!_isDrawing) {
                          _showPointOptions(index);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.error : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor,
                            width: isSelected ? 4 : 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected ? Colors.white : _selectedColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        
        // Info panel
        if (_polygonPoints.isNotEmpty && !_isDrawing)
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Area: ${GeometryUtils.calculatePolygonArea(_polygonPoints).toStringAsFixed(6)}°²',
                    style: AppTypography.captionSmall,
                  ),
                  Text(
                    'Punti: ${_polygonPoints.length}',
                    style: AppTypography.captionSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showPointOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text('Rimuovi Punto'),
              onTap: () {
                Navigator.pop(context);
                _removePoint(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
