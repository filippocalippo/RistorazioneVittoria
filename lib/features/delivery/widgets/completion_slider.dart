import 'package:flutter/material.dart';
import '../../../DesignSystem/design_tokens.dart';

/// Swipe-to-complete slider widget for completing deliveries
class CompletionSlider extends StatefulWidget {
  final VoidCallback onCompleted;

  const CompletionSlider({
    super.key,
    required this.onCompleted,
  });

  @override
  State<CompletionSlider> createState() => _CompletionSliderState();
}

class _CompletionSliderState extends State<CompletionSlider> {
  double _dragPosition = 0.0;
  bool _isDragging = false;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final maxDrag = MediaQuery.of(context).size.width - 48 - 32; // Account for padding and thumb size
    final progress = (_dragPosition / maxDrag).clamp(0.0, 1.0);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.circular),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background progress
          AnimatedContainer(
            duration: _isDragging
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: _completed
                ? double.infinity
                : 48 + (_dragPosition * 1.0),
            height: 56,
            decoration: BoxDecoration(
              color: _completed ? AppColors.success : AppColors.success.withValues(alpha: progress * 0.2),
              borderRadius: BorderRadius.circular(AppRadius.circular),
            ),
          ),

          // Text
          Center(
            child: AnimatedOpacity(
              opacity: _completed ? 0.0 : 1.0 - (progress * 0.6),
              duration: const Duration(milliseconds: 200),
              child: Text(
                'Scorri per Completare',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: AppTypography.semiBold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Thumb
          AnimatedPositioned(
            duration: _isDragging
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: 4 + (_completed ? maxDrag : _dragPosition),
            top: 4,
            child: GestureDetector(
              onHorizontalDragStart: (_) {
                if (!_completed) {
                  setState(() => _isDragging = true);
                }
              },
              onHorizontalDragUpdate: (details) {
                if (!_completed) {
                  setState(() {
                    _dragPosition = (_dragPosition + details.delta.dx)
                        .clamp(0.0, maxDrag);
                  });

                  // Check if completed
                  if (_dragPosition >= maxDrag * 0.9) {
                    _complete();
                  }
                }
              },
              onHorizontalDragEnd: (_) {
                if (!_completed) {
                  setState(() {
                    _isDragging = false;
                    _dragPosition = 0.0;
                  });
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _completed ? Colors.white : AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _completed ? Icons.check : Icons.chevron_right_rounded,
                  color: _completed ? AppColors.success : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _complete() {
    if (_completed) return;
    
    setState(() {
      _completed = true;
      _dragPosition = MediaQuery.of(context).size.width - 48 - 32;
    });

    // Call the completion callback after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onCompleted();
    });
  }
}

