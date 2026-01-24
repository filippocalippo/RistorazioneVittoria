import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../DesignSystem/design_tokens.dart';

/// Shimmer loading placeholder for banner carousel
class BannerShimmerLoader extends StatelessWidget {
  final double height;
  final EdgeInsets padding;

  const BannerShimmerLoader({
    super.key,
    required this.height,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceLight,
        highlightColor: AppColors.surface,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}
