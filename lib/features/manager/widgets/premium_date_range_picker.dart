import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';

class PremiumDateRangePicker extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const PremiumDateRangePicker({super.key, this.initialStart, this.initialEnd});

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => PremiumDateRangePicker(
        initialStart: initialStart,
        initialEnd: initialEnd,
      ),
    );
  }

  @override
  State<PremiumDateRangePicker> createState() => _PremiumDateRangePickerState();
}

class _PremiumDateRangePickerState extends State<PremiumDateRangePicker> {
  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    _focusedDate = _startDate ?? DateTime.now();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
      } else {
        if (date.isBefore(_startDate!)) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      }
    });
  }

  void _applyPreset(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
      _focusedDate = start;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child:
              Container(
                    width: isDesktop ? 600 : 360,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.radiusXXL,
                      boxShadow: AppShadows.xl,
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: AppSpacing.lg),
                        if (isDesktop)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 160, child: _buildSidebar()),
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(child: _buildCalendarSection()),
                              ],
                            ),
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMobileQuickActions(),
                              _buildCalendarSection(),
                            ],
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildFooter(context),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 250.ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    curve: Curves.easeOutBack,
                  ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleziona Periodo',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _RangeText(start: _startDate, end: _endDate),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetButton(
          label: 'Oggi',
          onTap: () => _applyPreset(DateTime.now(), DateTime.now()),
        ),
        _PresetButton(
          label: 'Ieri',
          onTap: () => _applyPreset(
            DateTime.now().subtract(1.days),
            DateTime.now().subtract(1.days),
          ),
        ),
        _PresetButton(
          label: 'Ultimi 7 gg',
          onTap: () =>
              _applyPreset(DateTime.now().subtract(7.days), DateTime.now()),
        ),
        _PresetButton(
          label: 'Questo Mese',
          onTap: () {
            final now = DateTime.now();
            _applyPreset(DateTime(now.year, now.month, 1), now);
          },
        ),
        _PresetButton(
          label: 'Mese Scorso',
          onTap: () {
            final now = DateTime.now();
            _applyPreset(
              DateTime(now.year, now.month - 1, 1),
              DateTime(now.year, now.month, 0),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _QuickChip(
            label: 'Oggi',
            onTap: () => _applyPreset(DateTime.now(), DateTime.now()),
          ),
          _QuickChip(
            label: '7 gg',
            onTap: () =>
                _applyPreset(DateTime.now().subtract(7.days), DateTime.now()),
          ),
          _QuickChip(
            label: 'Mese',
            onTap: () {
              final now = DateTime.now();
              _applyPreset(DateTime(now.year, now.month, 1), now);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat(
                  'MMMM yyyy',
                  'it_IT',
                ).format(_focusedDate).toUpperCase(),
                style: AppTypography.caption.copyWith(
                  fontWeight: AppTypography.bold,
                  letterSpacing: 1,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _focusedDate = DateTime(
                        _focusedDate.year,
                        _focusedDate.month - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _focusedDate = DateTime(
                        _focusedDate.year,
                        _focusedDate.month + 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CalendarGrid(
          focusedDate: _focusedDate,
          startDate: _startDate,
          endDate: _endDate,
          onDateSelected: _onDateSelected,
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          if (_startDate != null)
            TextButton(
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
              child: Text(
                'Reset',
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: (_startDate != null && _endDate != null)
                ? () => Navigator.pop(
                    context,
                    DateTimeRange(start: _startDate!, end: _endDate!),
                  )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }
}

class _RangeText extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;

  const _RangeText({this.start, this.end});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM', 'it_IT');
    if (start == null) {
      return Text(
        'Seleziona una data di inizio',
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      );
    }
    if (end == null) {
      return Text(
        'Seleziona la data di fine dopo il ${df.format(start!)}',
        style: AppTypography.caption.copyWith(color: AppColors.primary),
      );
    }
    return Text(
      '${df.format(start!)} - ${df.format(end!)}',
      style: AppTypography.caption.copyWith(
        color: AppColors.primary,
        fontWeight: AppTypography.bold,
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMD,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label, style: AppTypography.bodySmall),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: AppColors.surfaceLight,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusCircular),
        labelStyle: AppTypography.caption.copyWith(
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime) onDateSelected;

  const _CalendarGrid({
    required this.focusedDate,
    this.startDate,
    this.endDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedDate.year, focusedDate.month, 1);
    final lastDay = DateTime(focusedDate.year, focusedDate.month + 1, 0);
    final offset = firstDay.weekday - 1;

    return Column(
      children: [
        Row(
          children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textDisabled,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayNum = index - offset + 1;
            if (dayNum < 1 || dayNum > lastDay.day) {
              return const SizedBox.shrink();
            }

            final date = DateTime(focusedDate.year, focusedDate.month, dayNum);
            final isStart = startDate != null && _isSameDay(date, startDate!);
            final isEnd = endDate != null && _isSameDay(date, endDate!);
            final isInRange =
                startDate != null &&
                endDate != null &&
                date.isAfter(startDate!) &&
                date.isBefore(endDate!);
            final isToday = _isSameDay(date, DateTime.now());

            Color textColor = AppColors.textPrimary;
            BoxDecoration? decoration;

            if (isStart || isEnd) {
              textColor = Colors.white;
              decoration = BoxDecoration(
                color: AppColors.primary,
                borderRadius: isStart && isEnd
                    ? AppRadius.radiusMD
                    : isStart
                    ? const BorderRadius.horizontal(left: Radius.circular(12))
                    : const BorderRadius.horizontal(right: Radius.circular(12)),
              );
            } else if (isInRange) {
              textColor = AppColors.primaryDark;
              decoration = BoxDecoration(
                color: AppColors.primarySubtle.withValues(alpha: 0.5),
              );
            } else if (isToday) {
              decoration = BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                borderRadius: AppRadius.radiusMD,
              );
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onDateSelected(date),
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  decoration: decoration,
                  child: Center(
                    child: Text(
                      dayNum.toString(),
                      style: AppTypography.caption.copyWith(
                        fontWeight: (isStart || isEnd || isToday)
                            ? AppTypography.bold
                            : AppTypography.medium,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
