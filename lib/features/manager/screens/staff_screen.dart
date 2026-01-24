import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/user_model.dart';

import '../../../providers/users_provider.dart';
import '../../../providers/cashier_customer_provider.dart';
import '../widgets/staff_data_table.dart';
import '../widgets/cashier_customer_data_table.dart';

enum StaffView {
  staff,
  customers,
  cashierCustomers;

  String get displayName {
    switch (this) {
      case StaffView.staff:
        return 'Staff';
      case StaffView.customers:
        return 'Clienti App';
      case StaffView.cashierCustomers:
        return 'Clienti Cassa';
    }
  }

  IconData get icon {
    switch (this) {
      case StaffView.staff:
        return Icons.badge_rounded;
      case StaffView.customers:
        return Icons.people_rounded;
      case StaffView.cashierCustomers:
        return Icons.point_of_sale_rounded;
    }
  }
}

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  StaffView _currentView = StaffView.staff;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(pizzeriaUsersProvider);
    final cashierCustomersAsync = ref.watch(cashierCustomersNotifierProvider);

    return Column(
      children: [
        _buildHeader(context),
        _buildViewToggle(),
        _buildSearchBar(),
        Expanded(
          child: _currentView == StaffView.cashierCustomers
              ? cashierCustomersAsync.when(
                  data: (state) => _buildCashierCustomersTable(state),
                  loading: () => _buildLoadingState(),
                  error: (error, stack) => _buildErrorState(context, error),
                )
              : usersAsync.when(
                  data: (users) => _buildDataTable(users),
                  loading: () => _buildLoadingState(),
                  error: (error, stack) => _buildErrorState(context, error),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final usersAsync = ref.watch(pizzeriaUsersProvider);
    final totalUsers = usersAsync.value?.length ?? 0;

    return Container(
      padding: EdgeInsets.all(
        AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xl,
          desktop: AppSpacing.xxxl,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: AppRadius.radiusLG,
            ),
            child: Icon(
              Icons.groups_rounded,
              color: AppColors.info,
              size: isDesktop ? 32 : 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione Utenti',
                  style: isDesktop
                      ? AppTypography.headlineMedium
                      : AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$totalUsers utenti totali',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: () {
        if (_currentView == StaffView.cashierCustomers) {
          ref.read(cashierCustomersNotifierProvider.notifier).refresh();
        } else {
          ref.invalidate(pizzeriaUsersProvider);
        }
      },
      icon: const Icon(Icons.refresh_rounded),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
      ),
      tooltip: 'Aggiorna',
    );
  }

  Widget _buildViewToggle() {
    return Container(
      margin: EdgeInsets.all(
        AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xl,
          desktop: AppSpacing.xxxl,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: StaffView.values.map((view) {
          final isSelected = _currentView == view;
          final staffCount = ref.watch(staffUsersProvider).length;
          final customerCount = ref.watch(customerUsersProvider).length;
          final cashierCustomerState = ref
              .watch(cashierCustomersNotifierProvider)
              .valueOrNull;
          final cashierCustomerCount = cashierCustomerState?.items.length ?? 0;
          final count = view == StaffView.staff
              ? staffCount
              : view == StaffView.customers
              ? customerCount
              : cashierCustomerCount;

          return Expanded(
            child: Material(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: AppRadius.radiusLG,
              child: InkWell(
                onTap: () => setState(() => _currentView = view),
                borderRadius: AppRadius.radiusLG,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        view.icon,
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        view.displayName,
                        style: AppTypography.labelLarge.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? AppTypography.semiBold
                              : AppTypography.regular,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.surfaceLight,
                          borderRadius: AppRadius.radiusMD,
                        ),
                        child: Text(
                          count.toString(),
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: AppTypography.semiBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ... (skip search bar) ...

  Widget _buildCashierCustomersTable(CashierCustomersState state) {
    // If state has search query, use items directly as they are already filtered by server
    // However, if local search is active in THIS widget (StaffScreen has its own search bar?),
    // we should trigger server search or filter locally?
    // StaffScreen seems to have local search behavior.
    // Ideally we should bind _searchController to provider search like in UsersScreen.
    // For now, let's just show items.

    final searchedCustomers = state.items;

    if (searchedCustomers.isEmpty) {
      return _buildEmptyState();
    }

    return CashierCustomerDataTable(
      customers: searchedCustomers,
      onCustomerUpdated: () {
        ref.read(cashierCustomersNotifierProvider.notifier).refresh();
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xl,
          desktop: AppSpacing.xxxl,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Cerca per nome, email o telefono...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textTertiary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusXL,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusXL,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusXL,
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(List<UserModel> allUsers) {
    // Filter users based on current view
    final filteredUsers = _currentView == StaffView.staff
        ? allUsers.where((user) => user.isStaff).toList()
        : allUsers.where((user) => user.isCustomer).toList();

    // Apply search filter
    final searchedUsers = _searchQuery.isEmpty
        ? filteredUsers
        : filteredUsers.where((user) {
            final query = _searchQuery.toLowerCase();
            return user.email.toLowerCase().contains(query) ||
                (user.nome?.toLowerCase().contains(query) ?? false) ||
                (user.cognome?.toLowerCase().contains(query) ?? false) ||
                (user.telefono?.toLowerCase().contains(query) ?? false);
          }).toList();

    if (searchedUsers.isEmpty) {
      return _buildEmptyState();
    }

    return StaffDataTable(
      users: searchedUsers,
      isStaffView: _currentView == StaffView.staff,
      onRoleChanged: (userId, newRole) async {
        try {
          await ref
              .read(pizzeriaUsersProvider.notifier)
              .updateUserRole(userId, newRole);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ruolo aggiornato con successo'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Errore nell\'aggiornamento del ruolo'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      onStatusToggled: (userId, isActive) async {
        try {
          await ref
              .read(pizzeriaUsersProvider.notifier)
              .toggleUserStatus(userId, isActive);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isActive ? 'Utente attivato' : 'Utente disattivato',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Errore nell\'aggiornamento dello stato'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildEmptyState() {
    final message = _searchQuery.isNotEmpty
        ? 'Nessun risultato per "$_searchQuery"'
        : _currentView == StaffView.staff
        ? 'Nessun membro dello staff'
        : _currentView == StaffView.customers
        ? 'Nessun cliente registrato'
        : 'Nessun cliente cassa registrato';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            message,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Caricamento utenti...', style: AppTypography.titleMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Errore nel caricamento', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Non siamo riusciti a caricare gli utenti',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            ElevatedButton(
              onPressed: () => ref.refresh(pizzeriaUsersProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.lg,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
              ),
              child: Text(
                'Riprova',
                style: AppTypography.buttonMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
