import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/promotional_banners_provider.dart';
import '../../../core/models/promotional_banner_model.dart';
import '../../../core/widgets/banner_shimmer_loader.dart';
import '../../../core/models/banner_text_overlay.dart';
import '../../../core/widgets/cached_network_image.dart';
import 'banner_action_handler.dart';

/// Auto-rotating carousel for promotional banners - Design Concept Style
/// Features: 380px height, rounded bottom corners, indicators inside banner
class BannerCarousel extends ConsumerStatefulWidget {
  final bool isMobile;
  final double? height;
  final Duration autoRotateDuration;

  const BannerCarousel({
    super.key,
    required this.isMobile,
    this.height,
    this.autoRotateDuration = const Duration(seconds: 4),
  });

  @override
  ConsumerState<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<BannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoRotateTimer;
  bool _userInteracting = false;
  bool _isInitialLoad = true;
  bool _imagesPreloaded = false;

  // Fixed height matching design concept
  double get _bannerHeight {
    if (widget.height != null) return widget.height!;
    return 380.0; // Design concept height
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoRotate();
    // Mark initial load as complete after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
        // Preload banner images after first frame
        _preloadBannerImages();
      }
    });
  }

  /// Preload all banner images into cache for instant display
  void _preloadBannerImages() {
    if (_imagesPreloaded) return;

    final banners = _getBannersForDevice();
    if (banners.isEmpty) return;

    _imagesPreloaded = true;

    // Preload all banner images in parallel (non-blocking)
    for (final banner in banners) {
      if (banner.immagineUrl.isNotEmpty) {
        // Use CachedNetworkImageProvider to warm up the cache
        precacheImage(
          CachedNetworkImageProvider(banner.immagineUrl),
          context,
        ).catchError((_) {}); // Silently ignore errors
      }
    }
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(widget.autoRotateDuration, (timer) {
      if (!_userInteracting && _pageController.hasClients && mounted) {
        final banners = _getBannersForDevice();
        if (banners.isNotEmpty) {
          final nextPage = (_currentPage + 1) % banners.length;
          _pageController.animateToPage(
            nextPage,
            duration: AppAnimations.medium,
            curve: AppAnimations.easeInOut,
          );
        }
      }
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    // Track view
    final banners = _getBannersForDevice();
    if (page < banners.length) {
      ref
          .read(promotionalBannersProvider.notifier)
          .incrementView(banners[page].id);
    }
  }

  List<PromotionalBannerModel> _getBannersForDevice() {
    return widget.isMobile
        ? ref.watch(mobileBannersProvider)
        : ref.watch(desktopBannersProvider);
  }

  /// Determine if a banner at given index should be rendered
  /// Only renders current banner and adjacent ones for performance
  bool _shouldRenderBanner(int index, int totalBanners) {
    if (totalBanners <= 3) return true; // Always render all if 3 or fewer

    // Current banner always renders
    if (index == _currentPage) return true;

    // Previous banner (with wrap-around)
    final prevIndex = (_currentPage - 1 + totalBanners) % totalBanners;
    if (index == prevIndex) return true;

    // Next banner (with wrap-around)
    final nextIndex = (_currentPage + 1) % totalBanners;
    if (index == nextIndex) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(promotionalBannersProvider);
    final banners = _getBannersForDevice();

    return bannersAsync.when(
      data: (_) {
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: _bannerHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            child: Stack(
              children: [
                // Crossfade banner images - only render current and adjacent for performance
                ...List.generate(banners.length, (index) {
                  // Only render current banner and its neighbors (for smooth crossfade)
                  if (!_shouldRenderBanner(index, banners.length)) {
                    return const SizedBox.shrink();
                  }
                  return AnimatedOpacity(
                    opacity: _currentPage == index ? 1.0 : 0.0,
                    duration: _isInitialLoad
                        ? Duration.zero
                        : const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    child: _buildBannerContent(context, banners[index]),
                  );
                }),

                // Dot Indicators - positioned below text
                if (banners.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          banners.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Gesture detector for manual swiping
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      setState(() {
                        _userInteracting = true;
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _userInteracting = false;
                      });
                      _startAutoRotate();

                      // Swipe detection
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! < 0) {
                          // Swipe left - next
                          final nextPage = (_currentPage + 1) % banners.length;
                          setState(() {
                            _currentPage = nextPage;
                          });
                          _onPageChanged(nextPage);
                        } else if (details.primaryVelocity! > 0) {
                          // Swipe right - previous
                          final prevPage =
                              (_currentPage - 1 + banners.length) %
                              banners.length;
                          setState(() {
                            _currentPage = prevPage;
                          });
                          _onPageChanged(prevPage);
                        }
                      }
                    },
                    onTap: () {
                      // Handle banner tap
                      ref
                          .read(promotionalBannersProvider.notifier)
                          .incrementClick(banners[_currentPage].id);
                      BannerActionHandler.handle(
                        context,
                        banners[_currentPage],
                        ref: ref,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () {
        return BannerShimmerLoader(
          height: _bannerHeight,
          padding: EdgeInsets.zero,
        );
      },
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildBannerContent(
    BuildContext context,
    PromotionalBannerModel banner,
  ) {
    final textOverlay = BannerTextOverlay.fromJson(banner.textOverlay);
    final showDefaultOverlay =
        !textOverlay.hasContent &&
        (banner.titolo.isNotEmpty || banner.descrizione != null);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        CachedNetworkImageWidget(
          imageUrl: banner.immagineUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            color: AppColors.surfaceLight,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary.withValues(alpha: 0.5),
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: Container(
            color: AppColors.surfaceLight,
            child: Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: AppColors.textDisabled,
                size: 48,
              ),
            ),
          ),
        ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.0, 0.4, 0.7],
            ),
          ),
        ),

        // Text content
        if (textOverlay.hasContent)
          _buildTextOverlay(textOverlay)
        else if (showDefaultOverlay)
          _buildDefaultOverlay(banner),

        // Sponsor badge
        if (banner.isSponsorizzato) _buildSponsorBadge(banner),
      ],
    );
  }

  Widget _buildTextOverlay(BannerTextOverlay overlay) {
    return Positioned(
      left: 32,
      right: 32,
      bottom: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overlay.subtitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                overlay.subtitle!.toUpperCase(),
                style: AppTypography.captionSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          if (overlay.subtitle != null) const SizedBox(height: 8),
          if (overlay.title != null)
            Text(
              overlay.title!,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.2,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 8,
                    color: Colors.black38,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultOverlay(PromotionalBannerModel banner) {
    return Positioned(
      left: 32,
      right: 32,
      bottom: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (banner.descrizione != null && banner.descrizione!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                banner.descrizione!.toUpperCase(),
                style: AppTypography.captionSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (banner.descrizione != null && banner.descrizione!.isNotEmpty)
            const SizedBox(height: 8),
          Text(
            banner.titolo,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.2,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black38,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorBadge(PromotionalBannerModel banner) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              banner.sponsorNome ?? 'Sponsorizzato',
              style: AppTypography.captionSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
