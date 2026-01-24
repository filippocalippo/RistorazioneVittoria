import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/menu_item_model.dart';
import '../utils/logger.dart';

/// Utility service responsible for preloading frequently used network images
/// so that key screens render instantly after the loading experience completes.
/// Enhanced to work with CachedNetworkImage for optimal performance.
class ImagePreloadService {
  const ImagePreloadService();

  /// Preloads the pizzeria logo if available using CachedNetworkImage.
  Future<void> preloadLogo({
    required String? logoUrl,
    required BuildContext context,
  }) async {
    if (logoUrl == null || logoUrl.isEmpty) {
      return;
    }

    try {
      // Preload using CachedNetworkImage for optimal caching
      await precacheImage(
        CachedNetworkImageProvider(logoUrl),
        context,
      );
    } catch (error, stackTrace) {
      Logger.warning(
        'Failed to preload pizzeria logo: $error\n$stackTrace',
        tag: 'ImagePreloadService',
      );
    }
  }

  /// Preloads a subset of menu item images to ensure swift rendering when
  /// the menu or manager dashboards open. Uses CachedNetworkImage for optimal caching.
  Future<void> preloadMenuImages({
    required List<MenuItemModel> menuItems,
    required BuildContext context,
    int maxImages = 12,
  }) async {
    if (menuItems.isEmpty) {
      return;
    }

    final imagesToCache = menuItems
        .where(
          (item) => item.immagineUrl != null && item.immagineUrl!.isNotEmpty,
        )
        .take(maxImages)
        .map((item) => item.immagineUrl!)
        .toList();

    if (imagesToCache.isEmpty) {
      return;
    }

    await Future.wait(
      imagesToCache.map((url) async {
        try {
          // Preload using CachedNetworkImage for optimal caching
          await precacheImage(
            CachedNetworkImageProvider(url),
            context,
          );
        } catch (error, stackTrace) {
          Logger.warning(
            'Failed to preload menu image: $url\n$error\n$stackTrace',
            tag: 'ImagePreloadService',
          );
        }
      }),
      eagerError: false,
    );
  }

  /// Preloads a specific list of image URLs with custom cache settings.
  Future<void> preloadImages({
    required List<String> imageUrls,
    int memCacheWidth = 400,
    int memCacheHeight = 300,
  }) async {
    if (imageUrls.isEmpty) {
      return;
    }

    await Future.wait(
      imageUrls.map((url) async {
        if (url.isEmpty) return;
        
        try {
          // Warm up the cache by accessing the image provider
          final imageProvider = CachedNetworkImageProvider(url);
          // Force the image to load by creating a Future that completes when ready
          final completer = Completer<void>();
          final stream = imageProvider.resolve(const ImageConfiguration());
          final listener = ImageStreamListener(
            (info, _) => completer.complete(),
            onError: (error, stackTrace) => completer.completeError(error, stackTrace),
          );
          stream.addListener(listener);
          try {
            await completer.future;
          } finally {
            stream.removeListener(listener);
          }
          
        } catch (error, stackTrace) {
          Logger.warning(
            'Failed to preload image: $url\n$error\n$stackTrace',
            tag: 'ImagePreloadService',
          );
        }
      }),
      eagerError: false,
    );
  }

  /// Clears the image cache for a specific URL.
  Future<void> clearImageCache(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    
    try {
      await CachedNetworkImage.evictFromCache(imageUrl);
      Logger.debug('Cleared cache for image', tag: 'ImagePreloadService');
    } catch (error, stackTrace) {
      Logger.warning(
        'Failed to clear cache for image: $imageUrl\n$error\n$stackTrace',
        tag: 'ImagePreloadService',
      );
    }
  }

  /// Clears all cached images.
  Future<void> clearAllImageCache() async {
    try {
      // Clear Flutter's image cache
      PaintingBinding.instance.imageCache.clear();
      
      Logger.debug('Cleared all image cache', tag: 'ImagePreloadService');
    } catch (error, stackTrace) {
      Logger.warning(
        'Failed to clear all image cache\n$error\n$stackTrace',
        tag: 'ImagePreloadService',
      );
    }
  }

  /// Gets cache information for debugging.
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      return {
        'liveImageCount': imageCache.liveImageCount,
        'currentSizeBytes': imageCache.currentSizeBytes,
        'currentSize': '${(imageCache.currentSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
      };
    } catch (error) {
      Logger.warning('Failed to get cache info: $error', tag: 'ImagePreloadService');
      return {};
    }
  }
}
