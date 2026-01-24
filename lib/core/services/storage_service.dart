import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../exceptions/app_exceptions.dart';
import '../utils/logger.dart';

/// Service for managing file uploads to Supabase Storage
/// 
/// IMPORTANT: Before using this service, ensure the following storage buckets exist in Supabase:
/// 1. 'menu_images' - for menu item photos (public bucket)
/// 2. 'pizzeria_images' - for pizzeria logos and covers (public bucket)
/// 3. 'promotional_banners' - for promotional banner images (public bucket)
/// 4. 'category_icons' - for category icon images (public bucket, recommended size: 1024x1024px)
/// 
/// To create buckets in Supabase Dashboard:
/// 1. Go to Storage section
/// 2. Create new bucket with the exact name
/// 3. Set as Public bucket
/// 4. Configure policies to allow authenticated users to upload
class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;
  
  // Storage bucket names - MUST match exactly with Supabase bucket names
  static const String _menuImagesBucket = 'menu_images';
  static const String _pizzeriaImagesBucket = 'pizzeria_images';
  static const String _promotionalBannersBucket = 'promotional_banners';
  static const String _categoryIconsBucket = 'category_icons';
  
  Future<File> _prepareImageForUpload(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imageFile;

    final int maxSize = 1280;
    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? maxSize : null,
      height: decoded.height >= decoded.width ? maxSize : null,
      interpolation: img.Interpolation.average,
    );

    final ext = imageFile.path.split('.').last.toLowerCase();
    List<int> encoded;
    if (ext == 'png') {
      encoded = img.encodePng(resized, level: 6);
    } else {
      // Fallback to JPEG for non-PNG images
      encoded = img.encodeJpg(resized, quality: 80);
    }

    final tempDir = Directory.systemTemp;
    final tempFile = await File(
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${imageFile.uri.pathSegments.isNotEmpty ? imageFile.uri.pathSegments.last : 'upload'}',
    ).create();
    await tempFile.writeAsBytes(encoded, flush: true);
    return tempFile;
  }

  /// Prepare image for category icon upload - crops/resizes to square 1024x1024
  Future<File> _prepareCategoryIconImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imageFile;

    const int targetSize = 1024;
    
    // Calculate crop dimensions for square crop (center crop)
    final minDimension = decoded.width < decoded.height ? decoded.width : decoded.height;
    final cropX = (decoded.width - minDimension) ~/ 2;
    final cropY = (decoded.height - minDimension) ~/ 2;
    
    // Crop to square
    final cropped = img.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: minDimension,
      height: minDimension,
    );
    
    // Resize to 1024x1024
    final resized = img.copyResize(
      cropped,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic,
    );

    final ext = imageFile.path.split('.').last.toLowerCase();
    List<int> encoded;
    String outputExt;
    
    // Check if image has transparency (alpha channel)
    final hasTransparency = resized.hasAlpha;
    
    if (ext == 'png' || hasTransparency) {
      // Preserve PNG format for transparency support
      encoded = img.encodePng(resized, level: 6);
      outputExt = 'png';
    } else {
      // Use JPEG for better compression when no transparency
      encoded = img.encodeJpg(resized, quality: 90);
      outputExt = 'jpg';
    }

    final tempDir = Directory.systemTemp;
    final tempFile = await File(
      '${tempDir.path}/category_icon_${DateTime.now().millisecondsSinceEpoch}.$outputExt',
    ).create();
    await tempFile.writeAsBytes(encoded, flush: true);
    return tempFile;
  }

  /// Upload a menu item image
  /// Returns the public URL of the uploaded image
  /// Throws StorageUploadException if upload fails
  Future<String> uploadMenuItemImage({
    required File imageFile,
    String? existingImageUrl,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw StorageUploadException('File immagine non trovato');
      }
      
      // Delete old image if exists
      if (existingImageUrl != null) {
        await _deleteImageFromUrl(existingImageUrl, _menuImagesBucket);
      }
      
      final processedFile = await _prepareImageForUpload(imageFile);
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      
      // Validate extension
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      if (!allowedExtensions.contains(extension)) {
        throw StorageUploadException(
          'Formato immagine non supportato. Usa: ${allowedExtensions.join(", ")}'
        );
      }
      
      final fileName = 'menu_items/$timestamp.$extension';
      
      // Upload file
      await _client.storage
          .from(_menuImagesBucket)
          .upload(
            fileName,
            processedFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      
      // Get public URL
      final publicUrl = _client.storage
          .from(_menuImagesBucket)
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      // Provide user-friendly error messages
      final msg = e.toString();
      if (msg.contains('Bucket not found')) {
        throw StorageUploadException(
          'Bucket di storage non configurato. '
          'Contatta l\'amministratore per creare il bucket "$_menuImagesBucket" in Supabase.'
        );
      }
      if (e is StorageUploadException) rethrow;
      throw StorageUploadException('Errore caricamento immagine: $msg');
    }
  }
  
  /// Upload a pizzeria logo or cover image
  Future<String> uploadPizzeriaImage({
    required File imageFile,
    required String imageType, // 'logo' or 'cover'
    String? existingImageUrl,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw StorageUploadException('File immagine non trovato');
      }
      
      // Delete old image if exists
      if (existingImageUrl != null) {
        await _deleteImageFromUrl(existingImageUrl, _pizzeriaImagesBucket);
      }
      
      final processedFile = await _prepareImageForUpload(imageFile);
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      
      // Validate extension
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      if (!allowedExtensions.contains(extension)) {
        throw StorageUploadException(
          'Formato immagine non supportato. Usa: ${allowedExtensions.join(", ")}'
        );
      }
      
      final fileName = 'pizzeria/$imageType-$timestamp.$extension';
      
      // Upload file
      await _client.storage
          .from(_pizzeriaImagesBucket)
          .upload(
            fileName,
            processedFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      
      // Get public URL
      final publicUrl = _client.storage
          .from(_pizzeriaImagesBucket)
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      // Provide user-friendly error messages
      final msg = e.toString();
      if (msg.contains('Bucket not found')) {
        throw StorageUploadException(
          'Bucket di storage non configurato. '
          'Contatta l\'amministratore per creare il bucket "$_pizzeriaImagesBucket" in Supabase.'
        );
      }
      if (e is StorageUploadException) rethrow;
      throw StorageUploadException('Errore caricamento immagine: $msg');
    }
  }
  
  /// Delete image from storage using its URL
  Future<void> _deleteImageFromUrl(String imageUrl, String bucketName) async {
    try {
      // Extract file path from public URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name in the path and extract everything after it
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        return; // Invalid URL structure, skip deletion
      }
      
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      if (filePath.isNotEmpty) {
        await _client.storage
            .from(bucketName)
            .remove([filePath]);
      }
    } catch (e) {
      // Log error but don't throw - old image deletion shouldn't block new upload
      Logger.warning('Could not delete old image: $e', tag: 'Storage');
    }
  }
  
  /// Delete a menu item image by its URL
  Future<void> deleteMenuItemImage(String imageUrl) async {
    await _deleteImageFromUrl(imageUrl, _menuImagesBucket);
  }
  
  /// Delete a pizzeria image by its URL
  Future<void> deletePizzeriaImage(String imageUrl) async {
    await _deleteImageFromUrl(imageUrl, _pizzeriaImagesBucket);
  }
  
  /// Upload a promotional banner image
  /// Returns the public URL of the uploaded image
  /// Throws StorageUploadException if upload fails
  Future<String> uploadPromotionalBanner({
    required File imageFile,
    String? existingImageUrl,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw StorageUploadException('File immagine non trovato');
      }
      
      // Delete old image if exists
      if (existingImageUrl != null) {
        await _deleteImageFromUrl(existingImageUrl, _promotionalBannersBucket);
      }
      
      final processedFile = await _prepareImageForUpload(imageFile);
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      
      // Validate extension
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      if (!allowedExtensions.contains(extension)) {
        throw StorageUploadException(
          'Formato immagine non supportato. Usa: ${allowedExtensions.join(", ")}'
        );
      }
      
      final fileName = 'banners/$timestamp.$extension';
      
      // Upload file
      await _client.storage
          .from(_promotionalBannersBucket)
          .upload(
            fileName,
            processedFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      
      // Get public URL
      final publicUrl = _client.storage
          .from(_promotionalBannersBucket)
          .getPublicUrl(fileName);
      
      Logger.info('✓ Banner uploaded: $fileName', tag: 'Storage');
      return publicUrl;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Bucket not found')) {
        throw StorageUploadException(
          'Bucket di storage non configurato. '
          'Contatta l\'amministratore per creare il bucket "$_promotionalBannersBucket" in Supabase.'
        );
      }
      if (e is StorageUploadException) rethrow;
      throw StorageUploadException('Errore caricamento immagine: $msg');
    }
  }
  
  /// Delete a promotional banner image by its URL
  Future<void> deletePromotionalBanner(String imageUrl) async {
    await _deleteImageFromUrl(imageUrl, _promotionalBannersBucket);
  }
  
  /// Upload a category icon image
  /// Returns the public URL of the uploaded image
  /// Throws StorageUploadException if upload fails
  /// Recommended image size: 1024x1024px (will be auto-cropped/resized)
  Future<String> uploadCategoryIcon({
    required File imageFile,
    String? existingImageUrl,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw StorageUploadException('File immagine non trovato');
      }
      
      // Delete old image if exists
      if (existingImageUrl != null) {
        await _deleteImageFromUrl(existingImageUrl, _categoryIconsBucket);
      }
      
      // Prepare image: crop to square and resize to 1024x1024
      final processedFile = await _prepareCategoryIconImage(imageFile);
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalExtension = imageFile.path.split('.').last.toLowerCase();
      
      // Validate extension
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      if (!allowedExtensions.contains(originalExtension)) {
        throw StorageUploadException(
          'Formato immagine non supportato. Usa: ${allowedExtensions.join(", ")}'
        );
      }
      
      // Determine output extension based on processed file (preserves transparency)
      final processedExtension = processedFile.path.split('.').last.toLowerCase();
      final fileName = 'categories/$timestamp.$processedExtension';
      
      // Upload file
      await _client.storage
          .from(_categoryIconsBucket)
          .upload(
            fileName,
            processedFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      
      // Get public URL
      final publicUrl = _client.storage
          .from(_categoryIconsBucket)
          .getPublicUrl(fileName);
      
      Logger.info('✓ Category icon uploaded: $fileName', tag: 'Storage');
      return publicUrl;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Bucket not found')) {
        throw StorageUploadException(
          'Bucket di storage non configurato. '
          'Contatta l\'amministratore per creare il bucket "$_categoryIconsBucket" in Supabase.'
        );
      }
      if (e is StorageUploadException) rethrow;
      throw StorageUploadException('Errore caricamento icona categoria: $msg');
    }
  }
  
  /// Delete a category icon image by its URL
  Future<void> deleteCategoryIcon(String imageUrl) async {
    await _deleteImageFromUrl(imageUrl, _categoryIconsBucket);
  }
}
