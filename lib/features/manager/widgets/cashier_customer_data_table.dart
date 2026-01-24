import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/cashier_customer_model.dart';
import 'cashier_customer_detail_modal.dart';

enum CashierCustomerSortColumn {
  name,
  phone,
  address,
  orders,
  totalSpent,
  lastOrder;

  String get displayName {
    switch (this) {
      case CashierCustomerSortColumn.name:
        return 'Nome';
      case CashierCustomerSortColumn.phone:
        return 'Telefono';
      case CashierCustomerSortColumn.address:
        return 'Indirizzo';
      case CashierCustomerSortColumn.orders:
        return 'Ordini';
      case CashierCustomerSortColumn.totalSpent:
        return 'Totale Speso';
      case CashierCustomerSortColumn.lastOrder:
        return 'Ultimo Ordine';
    }
  }
}

class CashierCustomerDataTable extends StatefulWidget {
  final List<CashierCustomerModel> customers;
  final VoidCallback onCustomerUpdated;

  const CashierCustomerDataTable({
    super.key,
    required this.customers,
    required this.onCustomerUpdated,
  });

  @override
  State<CashierCustomerDataTable> createState() => _CashierCustomerDataTableState();
}

class _CashierCustomerDataTableState extends State<CashierCustomerDataTable> {
  CashierCustomerSortColumn _sortColumn = CashierCustomerSortColumn.orders;
  bool _sortAscending = false;

  List<CashierCustomerModel> get _sortedCustomers {
    final customers = List<CashierCustomerModel>.from(widget.customers);

    customers.sort((a, b) {
      int comparison;
      switch (_sortColumn) {
        case CashierCustomerSortColumn.name:
          comparison = a.nome.compareTo(b.nome);
          break;
        case CashierCustomerSortColumn.phone:
          comparison = (a.telefono ?? '').compareTo(b.telefono ?? '');
          break;
        case CashierCustomerSortColumn.address:
          comparison = (a.indirizzo ?? '').compareTo(b.indirizzo ?? '');
          break;
        case CashierCustomerSortColumn.orders:
          comparison = a.ordiniCount.compareTo(b.ordiniCount);
          break;
        case CashierCustomerSortColumn.totalSpent:
          comparison = a.totaleSpeso.compareTo(b.totaleSpeso);
          break;
        case CashierCustomerSortColumn.lastOrder:
          final aDate = a.ultimoOrdineAt ?? DateTime(1970);
          final bDate = b.ultimoOrdineAt ?? DateTime(1970);
          comparison = aDate.compareTo(bDate);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return customers;
  }

  void _onSort(CashierCustomerSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final sortedCustomers = _sortedCustomers;

    return Container(
      margin: EdgeInsets.all(
        AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xl,
          desktop: AppSpacing.xxxl,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Table header
          _buildTableHeader(isDesktop),
          const Divider(height: 1, color: AppColors.border),
          // Table rows
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: sortedCustomers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final customer = sortedCustomers[index];
                return _buildTableRow(customer, isDesktop);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.lg : AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.xl),
          topRight: Radius.circular(AppSpacing.xl),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell(
            CashierCustomerSortColumn.name,
            flex: isDesktop ? 3 : 2,
            isDesktop: isDesktop,
          ),
          if (isDesktop) ...[
            _buildHeaderCell(CashierCustomerSortColumn.phone, flex: 2, isDesktop: isDesktop),
            _buildHeaderCell(CashierCustomerSortColumn.address, flex: 3, isDesktop: isDesktop),
          ],
          _buildHeaderCell(CashierCustomerSortColumn.orders, flex: 1, isDesktop: isDesktop),
          _buildHeaderCell(CashierCustomerSortColumn.totalSpent, flex: 2, isDesktop: isDesktop),
          _buildHeaderCell(CashierCustomerSortColumn.lastOrder, flex: 2, isDesktop: isDesktop),
          SizedBox(
            width: isDesktop ? 80 : 60,
            child: Center(
              child: Text(
                'Azioni',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    CashierCustomerSortColumn column, {
    required int flex,
    required bool isDesktop,
  }) {
    final isActive = _sortColumn == column;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onSort(column),
        borderRadius: AppRadius.radiusMD,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  column.displayName,
                  style: AppTypography.labelMedium.copyWith(
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: AppTypography.semiBold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                isActive
                    ? (_sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 16,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(CashierCustomerModel customer, bool isDesktop) {
    return InkWell(
      onTap: () => _showCustomerDetails(customer),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? AppSpacing.lg : AppSpacing.md),
        child: Row(
          children: [
            // Name with avatar
            Expanded(
              flex: isDesktop ? 3 : 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isDesktop ? 20 : 16,
                    backgroundColor: _getAvatarColor(customer.ordiniCount),
                    child: Text(
                      _getInitials(customer),
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.nome,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: AppTypography.semiBold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isDesktop && customer.telefono != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            customer.telefono!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Phone (desktop only)
            if (isDesktop)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    customer.telefono ?? '-',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Address (desktop only)
            if (isDesktop)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    children: [
                      if (customer.hasGeocodedAddress)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          customer.indirizzo ?? '-',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Orders count
            Expanded(
              flex: 1,
              child: Center(
                child: _buildOrdersBadge(customer.ordiniCount),
              ),
            ),
            // Total spent
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  '€${customer.totaleSpeso.toStringAsFixed(2)}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.semiBold,
                    color: customer.totaleSpeso > 0 ? AppColors.success : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Last order date
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  customer.ultimoOrdineAt != null
                      ? DateFormat('dd/MM/yyyy').format(customer.ultimoOrdineAt!)
                      : '-',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: isDesktop ? 80 : 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    onPressed: () => _showCustomerDetails(customer),
                    tooltip: 'Visualizza dettagli',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersBadge(int count) {
    Color color;
    if (count >= 10) {
      color = AppColors.success;
    } else if (count >= 5) {
      color = AppColors.info;
    } else if (count > 0) {
      color = AppColors.warning;
    } else {
      color = AppColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        count.toString(),
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: AppTypography.semiBold,
        ),
      ),
    );
  }

  Color _getAvatarColor(int ordiniCount) {
    if (ordiniCount >= 10) {
      return AppColors.success;
    } else if (ordiniCount >= 5) {
      return AppColors.info;
    } else if (ordiniCount > 0) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }

  String _getInitials(CashierCustomerModel customer) {
    final parts = customer.nome.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (customer.nome.isNotEmpty) {
      return customer.nome.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  void _showCustomerDetails(CashierCustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => CashierCustomerDetailModal(
        customer: customer,
        onCustomerUpdated: widget.onCustomerUpdated,
      ),
    );
  }
}
