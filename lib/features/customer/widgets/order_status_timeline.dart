import 'package:flutter/material.dart';

import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/formatters.dart';

class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    required this.confirmedAt,
    this.preparingAt,
    this.deliveringAt,
    this.completedAt,
    this.orderType,
  });

  final OrderStatus currentStatus;
  final DateTime confirmedAt;
  final DateTime? preparingAt;
  final DateTime? deliveringAt;
  final DateTime? completedAt;
  final OrderType? orderType;

  @override
  Widget build(BuildContext context) {
    final stageIndex = _stageIndexForStatus(currentStatus);
    final isDelivery = orderType == OrderType.delivery;
    final progress = _calculateProgress(stageIndex, isDelivery);
    
    final steps = [
      _TimelineStep(
        label: 'Confermato',
        icon: Icons.check_circle_rounded,
        timestamp: confirmedAt,
        isCompleted: stageIndex > 0,
        isActive: stageIndex == 0,
      ),
      _TimelineStep(
        label: 'In preparazione',
        icon: Icons.restaurant_menu_rounded,
        timestamp: preparingAt,
        isCompleted: stageIndex > 1,
        isActive: stageIndex == 1,
      ),
      _TimelineStep(
        label: isDelivery ? 'In consegna' : 'Pronto',
        icon: isDelivery ? Icons.two_wheeler_rounded : Icons.restaurant_rounded,
        timestamp: isDelivery ? deliveringAt : preparingAt,
        isCompleted: isDelivery 
            ? (currentStatus == OrderStatus.delivering || stageIndex > 2)
            : (currentStatus == OrderStatus.ready || stageIndex > 2),
        isActive: isDelivery 
            ? currentStatus == OrderStatus.delivering
            : currentStatus == OrderStatus.ready,
      ),
      _TimelineStep(
        label: 'Completato',
        icon: Icons.flag_rounded,
        timestamp: completedAt,
        isCompleted: stageIndex >= 3,
        isActive: stageIndex >= 3,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLG,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: _buildTimelineStage(
                    steps[i],
                    isFirst: i == 0,
                    isLast: i == steps.length - 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildProgressBar(progress),
          const SizedBox(height: AppSpacing.sm),
          _buildStatusRow(),
        ],
      ),
    );
  }

  Widget _buildTimelineStage(
    _TimelineStep step, {
    required bool isFirst,
    required bool isLast,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: step.isCompleted || step.isActive
            ? AppColors.primary
            : AppColors.border.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(
        step.icon,
        color: step.isCompleted || step.isActive
            ? Colors.white
            : AppColors.textSecondary.withValues(alpha: 0.5),
        size: 22,
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'stato: ',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          currentStatus.displayName,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            AnimatedContainer(
              duration: AppAnimations.medium,
              curve: AppAnimations.easeOut,
              height: 6,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        );
      },
    );
  }

  static int _stageIndexForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return 0;
      case OrderStatus.preparing:
        return 1;
      case OrderStatus.ready:
        return 2;
      case OrderStatus.delivering:
        return 2; // Same stage index as ready, but different UI for delivery
      case OrderStatus.completed:
        return 3;
      case OrderStatus.cancelled:
        return 3;
    }
  }

  double _calculateProgress(int stageIndex, bool isDelivery) {
    // For delivery orders, don't advance to 75% until actually delivering
    // For takeaway orders, advance to 75% when ready
    // Stage 0 (Confirmed): 25% (0.25)
    // Stage 1 (Preparing): 50% (0.50)
    // Stage 2: 
    //   - Delivery: stays at 50% until delivering, then 75%
    //   - Takeaway: 75% when ready
    // Stage 3 (Completed): 100% (1.0)
    
    if (isDelivery) {
      // Delivery order logic
      switch (currentStatus) {
        case OrderStatus.pending:
        case OrderStatus.confirmed:
          return 0.25;
        case OrderStatus.preparing:
          return 0.50;
        case OrderStatus.ready:
          return 0.50; // Stay at 50% for delivery when just ready
        case OrderStatus.delivering:
          return 0.75;
        case OrderStatus.completed:
          return 1.0;
        case OrderStatus.cancelled:
          return 1.0;
      }
    } else {
      // Takeaway order logic
      switch (stageIndex) {
        case 0:
          return 0.25;
        case 1:
          return 0.50;
        case 2:
          return 0.75;
        case 3:
          return 1.0;
        default:
          return 0.0;
      }
    }
  }
}

class _TimelineStep {
  _TimelineStep({
    required this.label,
    required this.icon,
    required this.timestamp,
    required this.isCompleted,
    required this.isActive,
  });

  final String label;
  final IconData icon;
  final DateTime? timestamp;
  final bool isCompleted;
  final bool isActive;

  String? get subtitle =>
      timestamp != null ? Formatters.time(timestamp!) : null;
}


