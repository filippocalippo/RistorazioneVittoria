import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/enums.dart';

enum SortColumn {
  name,
  email,
  phone,
  role,
  status,
  createdAt;

  String get displayName {
    switch (this) {
      case SortColumn.name:
        return 'Nome';
      case SortColumn.email:
        return 'Email';
      case SortColumn.phone:
        return 'Telefono';
      case SortColumn.role:
        return 'Ruolo';
      case SortColumn.status:
        return 'Stato';
      case SortColumn.createdAt:
        return 'Data Registrazione';
    }
  }
}

class StaffDataTable extends StatefulWidget {
  final List<UserModel> users;
  final bool isStaffView;
  final Function(String userId, UserRole newRole) onRoleChanged;
  final Function(String userId, bool isActive) onStatusToggled;

  const StaffDataTable({
    super.key,
    required this.users,
    required this.isStaffView,
    required this.onRoleChanged,
    required this.onStatusToggled,
  });

  @override
  State<StaffDataTable> createState() => _StaffDataTableState();
}

class _StaffDataTableState extends State<StaffDataTable> {
  SortColumn _sortColumn = SortColumn.createdAt;
  bool _sortAscending = false;

  List<UserModel> get _sortedUsers {
    final users = List<UserModel>.from(widget.users);

    users.sort((a, b) {
      int comparison;
      switch (_sortColumn) {
        case SortColumn.name:
          comparison = a.nomeCompleto.compareTo(b.nomeCompleto);
          break;
        case SortColumn.email:
          comparison = a.email.compareTo(b.email);
          break;
        case SortColumn.phone:
          comparison = (a.telefono ?? '').compareTo(b.telefono ?? '');
          break;
        case SortColumn.role:
          comparison = a.ruolo.displayName.compareTo(b.ruolo.displayName);
          break;
        case SortColumn.status:
          comparison = a.attivo == b.attivo ? 0 : (a.attivo ? -1 : 1);
          break;
        case SortColumn.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return users;
  }

  void _onSort(SortColumn column) {
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
    final sortedUsers = _sortedUsers;

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
              itemCount: sortedUsers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final user = sortedUsers[index];
                return _buildTableRow(user, isDesktop);
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
            SortColumn.name,
            flex: isDesktop ? 3 : 2,
            isDesktop: isDesktop,
          ),
          if (isDesktop) ...[
            _buildHeaderCell(SortColumn.email, flex: 3, isDesktop: isDesktop),
            _buildHeaderCell(SortColumn.phone, flex: 2, isDesktop: isDesktop),
          ],
          _buildHeaderCell(SortColumn.role, flex: 2, isDesktop: isDesktop),
          _buildHeaderCell(SortColumn.status, flex: 1, isDesktop: isDesktop),
          _buildHeaderCell(SortColumn.createdAt, flex: 2, isDesktop: isDesktop),
          SizedBox(
            width: isDesktop ? 120 : 80,
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
    SortColumn column, {
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

  Widget _buildTableRow(UserModel user, bool isDesktop) {
    return InkWell(
      onTap: () => _showUserDetails(user),
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
                    backgroundColor: _getAvatarColor(user.ruolo),
                    child: Text(
                      _getInitials(user),
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
                          user.nomeCompleto,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: AppTypography.semiBold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isDesktop) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            user.email,
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
            // Email (desktop only)
            if (isDesktop)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    user.email,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Phone (desktop only)
            if (isDesktop)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    user.telefono ?? '-',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Role
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: _buildRoleBadge(user.ruolo),
              ),
            ),
            // Status
            Expanded(
              flex: 1,
              child: Center(
                child: _buildStatusIndicator(user.attivo),
              ),
            ),
            // Created date
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(user.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: isDesktop ? 120 : 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    onPressed: () => _showRoleDialog(user),
                    tooltip: 'Modifica ruolo',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      user.attivo
                          ? Icons.toggle_on_rounded
                          : Icons.toggle_off_rounded,
                      size: 24,
                    ),
                    onPressed: () => widget.onStatusToggled(user.id, !user.attivo),
                    tooltip: user.attivo ? 'Disattiva' : 'Attiva',
                    style: IconButton.styleFrom(
                      foregroundColor:
                          user.attivo ? AppColors.success : AppColors.textTertiary,
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

  Widget _buildRoleBadge(UserRole role) {
    Color color;
    switch (role) {
      case UserRole.manager:
        color = AppColors.primary;
        break;
      case UserRole.kitchen:
        color = AppColors.warning;
        break;
      case UserRole.delivery:
        color = AppColors.info;
        break;
      case UserRole.customer:
        color = AppColors.textSecondary;
        break;
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
        role.displayName,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: AppTypography.semiBold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusIndicator(bool isActive) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isActive ? AppColors.success : AppColors.error,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return AppColors.primary;
      case UserRole.kitchen:
        return AppColors.warning;
      case UserRole.delivery:
        return AppColors.info;
      case UserRole.customer:
        return AppColors.textSecondary;
    }
  }

  String _getInitials(UserModel user) {
    if (user.nome != null && user.cognome != null && 
        user.nome!.isNotEmpty && user.cognome!.isNotEmpty) {
      return '${user.nome![0]}${user.cognome![0]}'.toUpperCase();
    }
    if (user.nome != null && user.nome!.isNotEmpty) {
      return user.nome!.substring(0, 1).toUpperCase();
    }
    if (user.email.isNotEmpty) {
      return user.email.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  void _showRoleDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
        title: Text(
          'Modifica Ruolo',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleziona il nuovo ruolo per ${user.nomeCompleto}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ...UserRole.values.map((role) {
              final isSelected = user.ruolo == role;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceLight,
                  borderRadius: AppRadius.radiusLG,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      if (!isSelected) {
                        widget.onRoleChanged(user.id, role);
                      }
                    },
                    borderRadius: AppRadius.radiusLG,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.radiusLG,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  role.displayName,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: AppTypography.semiBold,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _getRoleDescription(role),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getAvatarColor(user.ruolo),
              child: Text(
                _getInitials(user),
                style: AppTypography.titleMedium.copyWith(
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
                    user.nomeCompleto,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  _buildRoleBadge(user.ruolo),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', user.email, Icons.email_rounded),
              _buildDetailRow(
                'Telefono',
                user.telefono ?? 'Non specificato',
                Icons.phone_rounded,
              ),
              _buildDetailRow(
                'Indirizzo',
                user.indirizzo ?? 'Non specificato',
                Icons.location_on_rounded,
              ),
              _buildDetailRow(
                'Città',
                user.citta ?? 'Non specificata',
                Icons.location_city_rounded,
              ),
              _buildDetailRow(
                'CAP',
                user.cap ?? 'Non specificato',
                Icons.pin_drop_rounded,
              ),
              _buildDetailRow(
                'Stato',
                user.attivo ? 'Attivo' : 'Disattivato',
                user.attivo ? Icons.check_circle_rounded : Icons.cancel_rounded,
              ),
              _buildDetailRow(
                'Registrato il',
                DateFormat('dd/MM/yyyy HH:mm').format(user.createdAt),
                Icons.calendar_today_rounded,
              ),
              if (user.ultimoAccesso != null)
                _buildDetailRow(
                  'Ultimo accesso',
                  DateFormat('dd/MM/yyyy HH:mm').format(user.ultimoAccesso!),
                  Icons.access_time_rounded,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Chiudi',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Può effettuare ordini e gestire il proprio profilo';
      case UserRole.manager:
        return 'Accesso completo a tutte le funzionalità';
      case UserRole.kitchen:
        return 'Gestione ordini e preparazione in cucina';
      case UserRole.delivery:
        return 'Gestione consegne e stato ordini';
    }
  }
}
