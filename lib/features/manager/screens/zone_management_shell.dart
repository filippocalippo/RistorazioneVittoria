import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/delivery_zone_model.dart';
import '../../../providers/delivery_zones_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/geometry_utils.dart';

/// Modern zone management shell - stays inside management layout
class ZoneManagementShell extends ConsumerStatefulWidget {
  final LatLng? pizzeriaCenter;

  const ZoneManagementShell({super.key, this.pizzeriaCenter});

  @override
  ConsumerState<ZoneManagementShell> createState() =>
      _ZoneManagementShellState();
}

class _ZoneManagementShellState extends ConsumerState<ZoneManagementShell> {
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();

  List<LatLng> _polygonPoints = [];
  Color _selectedColor = const Color(0xFF10b981); // Emerald green
  bool _isDrawing = false;
  bool _isEditingPolygon = false; // Editing existing zone's polygon
  String? _errorMessage;
  DeliveryZoneModel? _selectedZone;
  DeliveryZoneModel? _editingZone; // Zone being edited (null = creating new)
  int? _draggingIndex; // Index of point currently being dragged

  final List<Color> _availableColors = [
    const Color(0xFFef4444), // Red
    const Color(0xFF3b82f6), // Blue
    const Color(0xFF10b981), // Emerald
    const Color(0xFFf59e0b), // Amber
    const Color(0xFF8b5cf6), // Violet
    const Color(0xFFec4899), // Pink
    const Color(0xFF14b8a6), // Teal
    const Color(0xFFf97316), // Orange
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _isEditingPolygon = false;
      _polygonPoints = [];
      _selectedZone = null;
      _editingZone = null;
      _errorMessage = null;
      _nameController.clear();
      _selectedColor = const Color(0xFF10b981);
    });
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      _isEditingPolygon = false;
      _polygonPoints = [];
      _editingZone = null;
      _errorMessage = null;
    });
  }

  void _finishDrawing() {
    if (_polygonPoints.length < 3) {
      setState(() => _errorMessage = 'La zona deve avere almeno 3 punti');
      return;
    }

    setState(() {
      _isDrawing = false;
      _errorMessage = null;
    });

    // Show zone creation modal
    _showZoneModal();
  }

  void _addPoint(LatLng point) {
    if (!_isDrawing && !_isEditingPolygon) return;

    setState(() {
      _polygonPoints = List.from(_polygonPoints)..add(point);
      _errorMessage = null;
    });
  }

  void _removeLastPoint() {
    if (_polygonPoints.isEmpty) return;
    setState(() {
      _polygonPoints = List.from(_polygonPoints)..removeLast();
    });
  }

  void _removePoint(int index) {
    if (_polygonPoints.length <= 3 && !_isDrawing) {
      setState(() => _errorMessage = 'La zona deve avere almeno 3 punti');
      return;
    }
    setState(() {
      _polygonPoints = List.from(_polygonPoints)..removeAt(index);
    });
  }

  void _movePoint(int index, LatLng newPosition) {
    setState(() {
      _polygonPoints = List.from(_polygonPoints);
      _polygonPoints[index] = newPosition;
    });
  }

  void _startEditZone(DeliveryZoneModel zone) {
    setState(() {
      _editingZone = zone;
      _selectedZone = zone;
      _nameController.text = zone.name;
      _selectedColor = zone.color;
      _polygonPoints = List.from(zone.polygon);
      _isEditingPolygon = false;
      _isDrawing = false;
    });
    _showEditZoneModal(zone);
  }

  void _startEditPolygon() {
    if (_editingZone == null) return;
    Navigator.of(context).pop(); // Close the edit modal
    setState(() {
      _isEditingPolygon = true;
      _polygonPoints = List.from(_editingZone!.polygon);
    });
  }

  void _finishEditPolygon() {
    if (_polygonPoints.length < 3) {
      setState(() => _errorMessage = 'La zona deve avere almeno 3 punti');
      return;
    }
    setState(() {
      _isEditingPolygon = false;
    });
    // Reopen the edit modal
    if (_editingZone != null) {
      _showEditZoneModal(_editingZone!);
    }
  }

  void _cancelEditPolygon() {
    setState(() {
      _isEditingPolygon = false;
      _polygonPoints = [];
      _editingZone = null;
    });
  }

  void _showZoneModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Row(
            children: [
              Icon(Icons.map_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Create Delivery Zone',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone Name Input
                Text(
                  'ZONE NAME',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Downtown, North Side',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  style: AppTypography.bodyMedium,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Color Picker
                Text(
                  'COLOR CODE',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _availableColors.map((color) {
                    final isSelected =
                        color.toARGB32() == _selectedColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => _selectedColor = color);
                        setState(() {}); // Update preview on map
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _cancelDrawing();
              },
              child: Text(
                'Discard',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _saveZone();
              },
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
              child: Text(
                'Save Zone',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditZoneModal(DeliveryZoneModel zone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Edit Zone',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone Name Input
                Text(
                  'ZONE NAME',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Downtown, North Side',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  style: AppTypography.bodyMedium,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Color Picker
                Text(
                  'COLOR CODE',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _availableColors.map((color) {
                    final isSelected =
                        color.toARGB32() == _selectedColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => _selectedColor = color);
                        setState(() {}); // Update preview on map
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Edit Polygon Button
                OutlinedButton.icon(
                  onPressed: _startEditPolygon,
                  icon: Icon(Icons.edit_location_alt_rounded, size: 18),
                  label: Text('Edit Zone Shape'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(color: AppColors.info),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Drag points to adjust, long-press to delete',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _editingZone = null;
                  _polygonPoints = [];
                });
              },
              child: Text(
                'Cancel',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _updateZone();
              },
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
              child: Text(
                'Save Changes',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveZone() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Inserisci un nome per la zona');
      return;
    }

    if (_polygonPoints.length < 3) {
      setState(() => _errorMessage = 'La zona deve avere almeno 3 punti');
      return;
    }

    final zone = DeliveryZoneModel(
      id: '',
      name: _nameController.text.trim(),
      color: _selectedColor,
      polygon: List.from(_polygonPoints),
      displayOrder: 0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!zone.isValidPolygon) {
      setState(() => _errorMessage = 'Poligono non valido');
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final service = ref.read(deliveryZonesServiceProvider);
      await service.createZone(zone);

      // Force refresh the provider
      ref.invalidate(deliveryZonesProvider);

      if (mounted) {
        _cancelDrawing();
        _nameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zona "${zone.name}" creata con successo'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to save zone', tag: 'ZoneManagement', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore durante il salvataggio';
        });
      }
    }
  }

  Future<void> _updateZone() async {
    if (_editingZone == null) return;

    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Inserisci un nome per la zona');
      return;
    }

    final updatedZone = _editingZone!.copyWith(
      name: _nameController.text.trim(),
      color: _selectedColor,
      polygon: _polygonPoints.isNotEmpty ? List.from(_polygonPoints) : null,
      updatedAt: DateTime.now(),
    );

    if (!updatedZone.isValidPolygon) {
      setState(() => _errorMessage = 'Poligono non valido');
      return;
    }

    setState(() => _errorMessage = null);

    try {
      final service = ref.read(deliveryZonesServiceProvider);
      await service.updateZone(_editingZone!.id, updatedZone);

      // Force refresh the provider
      ref.invalidate(deliveryZonesProvider);

      if (mounted) {
        setState(() {
          _editingZone = null;
          _polygonPoints = [];
        });
        _nameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zona "${updatedZone.name}" aggiornata'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to update zone', tag: 'ZoneManagement', error: e);
      if (mounted) {
        setState(() => _errorMessage = 'Errore durante l\'aggiornamento');
      }
    }
  }

  Future<void> _deleteZone(DeliveryZoneModel zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('Elimina Zona'),
        content: Text('Sei sicuro di voler eliminare "${zone.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(deliveryZonesServiceProvider).deleteZone(zone.id);

        // Force refresh the provider
        ref.invalidate(deliveryZonesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Zona "${zone.name}" eliminata'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante l\'eliminazione'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(deliveryZonesProvider);
    final center = widget.pizzeriaCenter ?? const LatLng(37.507877, 15.083012);

    return Row(
      children: [
        // Left Sidebar - Zone List
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              right: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Sidebar Header
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Zones',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Define areas for delivery fees',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (_isDrawing || _isEditingPolygon)
                          ? null
                          : _startDrawing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(Icons.add, size: 16),
                      label: Text(
                        'Add New',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Zone List
              Expanded(
                child: zonesAsync.when(
                  data: (zones) {
                    if (zones.isEmpty && !_isDrawing && !_isEditingPolygon) {
                      return _buildEmptyState();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: zones.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final zone = zones[index];
                        return _buildZoneCard(zone);
                      },
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (error, _) => Center(
                    child: Text(
                      'Errore: $error',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),

              // Drawing Instructions Panel
              if (_isDrawing) _buildDrawingPanel(),

              // Edit Polygon Instructions Panel
              if (_isEditingPolygon) _buildEditPolygonPanel(),
            ],
          ),
        ),

        // Right Side - Map
        Expanded(
          child: _buildMap(
            center,
            zonesAsync.maybeWhen(data: (zones) => zones, orElse: () => []),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawingPanel() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_location_rounded,
                size: 16,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Drawing Mode',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_polygonPoints.length} points',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Click on the map to place points. Drag points to adjust. Long-press to delete a point.',
            style: AppTypography.captionSmall.copyWith(color: AppColors.info),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // Undo button
              IconButton(
                onPressed: _polygonPoints.isNotEmpty ? _removeLastPoint : null,
                icon: Icon(Icons.undo_rounded, size: 18),
                tooltip: 'Undo last point',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.info,
                  backgroundColor: AppColors.info.withValues(alpha: 0.1),
                ),
                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelDrawing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(color: AppColors.info),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  child: Text('Cancel', style: AppTypography.labelSmall),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _polygonPoints.length >= 3 ? _finishDrawing : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  child: Text(
                    'Complete',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
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

  Widget _buildEditPolygonPanel() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_location_alt_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Editing Zone: ${_editingZone?.name ?? ''}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Drag points to move. Long-press to delete. Tap map to add new points.',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEditPolygon,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  child: Text('Cancel', style: AppTypography.labelSmall),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _polygonPoints.length >= 3
                      ? _finishEditPolygon
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.map_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Zones Defined',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first delivery zone by clicking "Add New" above.',
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

  Widget _buildZoneCard(DeliveryZoneModel zone) {
    final isSelected = _selectedZone?.id == zone.id;
    final isEditing = _editingZone?.id == zone.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedZone = zone),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected || isEditing
                ? zone.color.withValues(alpha: 0.05)
                : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isEditing
                  ? AppColors.warning
                  : isSelected
                  ? zone.color.withValues(alpha: 0.5)
                  : AppColors.border,
              width: (isSelected || isEditing) ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: zone.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: zone.color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  zone.name,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Edit button
              IconButton(
                onPressed: (_isDrawing || _isEditingPolygon)
                    ? null
                    : () => _startEditZone(zone),
                icon: Icon(Icons.edit_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                style: IconButton.styleFrom(foregroundColor: AppColors.info),
                tooltip: 'Edit zone',
              ),
              // Delete button
              IconButton(
                onPressed: (_isDrawing || _isEditingPolygon)
                    ? null
                    : () => _deleteZone(zone),
                icon: Icon(Icons.delete_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                ),
                tooltip: 'Delete zone',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(LatLng center, List<DeliveryZoneModel> zones) {
    final isInteractive = _isDrawing || _isEditingPolygon;
    final displayColor = _isEditingPolygon
        ? (_editingZone?.color ?? _selectedColor)
        : _selectedColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // The map itself - disable gestures when dragging a point
            IgnorePointer(
              ignoring: _draggingIndex != null,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.0,
                  onPositionChanged: (position, hasGesture) {
                    // Rebuild overlay when map moves (pan/zoom)
                    if (isInteractive &&
                        _polygonPoints.isNotEmpty &&
                        hasGesture) {
                      setState(() {});
                    }
                  },
                  onTap: (_, point) {
                    if (_draggingIndex != null) {
                      return; // Ignore taps while dragging
                    }
                    if (_isDrawing || _isEditingPolygon) {
                      // Check if clicking near first point to close (only in drawing mode)
                      if (_isDrawing && _polygonPoints.length > 2) {
                        final firstPoint = _polygonPoints.first;
                        final dist = GeometryUtils.calculateDistance(
                          firstPoint,
                          point,
                        );
                        if (dist < 100) {
                          // 100 meters threshold
                          _finishDrawing();
                          return;
                        }
                      }
                      _addPoint(point);
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

                  // Existing zones (hide the one being edited)
                  if (zones.isNotEmpty)
                    PolygonLayer(
                      polygons: zones
                          .where((zone) => zone.id != _editingZone?.id)
                          .map((zone) {
                            return Polygon(
                              points: zone.polygon,
                              color: zone.color.withValues(alpha: 0.15),
                              borderColor: zone.color,
                              borderStrokeWidth: 2,
                            );
                          })
                          .toList(),
                    ),

                  // Drawing/Editing polygon
                  if (_polygonPoints.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _polygonPoints,
                          color: displayColor.withValues(alpha: 0.3),
                          borderColor: displayColor,
                          borderStrokeWidth: 3,
                        ),
                      ],
                    ),

                  // Static markers (when not interactive, just display)
                  if (_polygonPoints.isNotEmpty && !isInteractive)
                    MarkerLayer(
                      markers: _polygonPoints.asMap().entries.map((entry) {
                        final index = entry.key;
                        final point = entry.value;
                        final isFirst = index == 0;

                        return Marker(
                          point: point,
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFirst ? displayColor : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: displayColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: AppTypography.captionSmall.copyWith(
                                  color: isFirst ? Colors.white : displayColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // Overlay for draggable markers - this captures gestures ABOVE the map
            if (_polygonPoints.isNotEmpty && isInteractive)
              ..._buildDraggableMarkerOverlay(displayColor),

            // Error message
            if (_errorMessage != null)
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.lg,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _errorMessage = null),
                        icon: Icon(Icons.close, color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build draggable marker overlays positioned absolutely on screen
  List<Widget> _buildDraggableMarkerOverlay(Color displayColor) {
    final camera = _mapController.camera;
    final markers = <Widget>[];

    for (int index = 0; index < _polygonPoints.length; index++) {
      final point = _polygonPoints[index];
      final screenPoint = camera.latLngToScreenPoint(point);
      final isFirst = index == 0;
      final canClose = _isDrawing && isFirst && _polygonPoints.length > 2;
      final isDragging = _draggingIndex == index;

      // Marker size
      final markerSize = canClose ? 44.0 : 36.0;
      // Hit area is larger for easier grabbing
      final hitSize = 56.0;

      markers.add(
        Positioned(
          left: screenPoint.x - hitSize / 2,
          top: screenPoint.y - hitSize / 2,
          width: hitSize,
          height: hitSize,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                setState(() => _draggingIndex = index);
              },
              onPanUpdate: (details) {
                if (_draggingIndex != index) return;
                // Get the current screen position of this point
                final currentScreenPoint = camera.latLngToScreenPoint(
                  _polygonPoints[index],
                );
                // Apply the delta
                final newScreenPoint = math.Point<double>(
                  currentScreenPoint.x + details.delta.dx,
                  currentScreenPoint.y + details.delta.dy,
                );
                // Convert back to LatLng
                final newLatLng = camera.pointToLatLng(newScreenPoint);
                _movePoint(index, newLatLng);
              },
              onPanEnd: (details) {
                setState(() => _draggingIndex = null);
              },
              onLongPress: () {
                _removePoint(index);
              },
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: isDragging ? markerSize + 8 : markerSize,
                  height: isDragging ? markerSize + 8 : markerSize,
                  decoration: BoxDecoration(
                    color: canClose
                        ? AppColors.success
                        : (isFirst ? displayColor : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDragging ? Colors.white : displayColor,
                      width: isDragging ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDragging
                            ? displayColor.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.3),
                        blurRadius: isDragging ? 12 : 4,
                        spreadRadius: isDragging ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: canClose
                        ? Icon(
                            Icons.check,
                            color: Colors.white,
                            size: isDragging ? 22 : 18,
                          )
                        : Text(
                            '${index + 1}',
                            style: AppTypography.captionSmall.copyWith(
                              color: isFirst ? Colors.white : displayColor,
                              fontWeight: FontWeight.bold,
                              fontSize: isDragging ? 12 : 10,
                            ),
                          ),
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
}
