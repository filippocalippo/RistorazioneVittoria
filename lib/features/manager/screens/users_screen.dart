import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/cashier_customer_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/users_provider.dart';
import '../../../providers/cashier_customer_provider.dart';
import '../widgets/user_detail_modal.dart';

/// View modes for the users screen
enum UsersViewMode {
  staff,
  cashierUsers;

  String get displayName {
    switch (this) {
      case UsersViewMode.staff:
        return 'Staff';
      case UsersViewMode.cashierUsers:
        return 'Clienti Cassa';
    }
  }

  IconData get icon {
    switch (this) {
      case UsersViewMode.staff:
        return Icons.badge_rounded;
      case UsersViewMode.cashierUsers:
        return Icons.point_of_sale_rounded;
    }
  }
}

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  UsersViewMode _currentView = UsersViewMode.staff;
  String _searchQuery = '';
  UserRole? _selectedRole;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Sorting state for staff table
  int _staffSortColumnIndex = 0;
  bool _staffSortAscending = true;

  // Debounce timer
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_currentView == UsersViewMode.cashierUsers) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final state = ref.read(cashierCustomersNotifierProvider).value;
        if (state != null && state.hasMore && !state.isLoadingMore) {
          ref.read(cashierCustomersNotifierProvider.notifier).loadMore();
        }
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);

    if (_currentView == UsersViewMode.cashierUsers) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        ref.read(cashierCustomersNotifierProvider.notifier).search(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(pizzeriaUsersProvider);
    final cashierCustomersAsync = ref.watch(cashierCustomersNotifierProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _buildHeader(context, usersAsync),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatsCards(usersAsync, cashierCustomersAsync),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildSearchAndFilters(),
                  const SizedBox(height: AppSpacing.xxl),
                  _currentView == UsersViewMode.cashierUsers
                      ? cashierCustomersAsync.when(
                          data: (state) => _buildCashierCustomersTable(state),
                          loading: () => _buildLoadingState(),
                          error: (error, stack) =>
                              _buildErrorState(context, error),
                        )
                      : usersAsync.when(
                          data: (users) => _buildUsersTable(users),
                          loading: () => _buildLoadingState(),
                          error: (error, stack) =>
                              _buildErrorState(context, error),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<List<UserModel>> usersAsync,
  ) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xxxl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione Utenti',
                  style: isDesktop
                      ? AppTypography.headlineLarge.copyWith(
                          fontWeight: AppTypography.bold,
                        )
                      : AppTypography.headlineMedium.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Gestisci permessi, ruoli e stato degli account del tuo staff.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        onPressed: () {
          if (_currentView == UsersViewMode.cashierUsers) {
            ref.read(cashierCustomersNotifierProvider.notifier).refresh();
          } else {
            ref.invalidate(pizzeriaUsersProvider);
          }
        },
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Aggiorna',
      ),
    );
  }

  Widget _buildStatsCards(
    AsyncValue<List<UserModel>> usersAsync,
    AsyncValue<CashierCustomersState> cashierAsync,
  ) {
    final staffCount = ref.watch(staffUsersProvider).length;
    final activeCount = usersAsync.value?.where((u) => u.attivo).length ?? 0;
    final activePercentage = (usersAsync.value?.length ?? 0) > 0
        ? ((activeCount / (usersAsync.value?.length ?? 1)) * 100).round()
        : 0;

    // We can't know total count easily with pagination unless we add a count query or field
    // For now, use the length of currently loaded items + indicate if there are more
    final loadedCount = cashierAsync.value?.items.length ?? 0;
    final hasMore = cashierAsync.value?.hasMore ?? false;
    final cashierDisplay = hasMore ? '$loadedCount+' : loadedCount.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.badge_rounded,
                  title: 'Staff Totale',
                  value: staffCount.toString(),
                  subtitle: 'membri dello staff',
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Utenti Attivi',
                  value: activeCount.toString(),
                  subtitle: '$activePercentage% operativi',
                  iconColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Clienti Cassa',
                  value: cashierDisplay,
                  subtitle: 'clienti caricati',
                  iconColor: AppColors.info,
                ),
              ),
            ],
          );
        } else {
          // ... mobile layout
          return Column(
            children: [
              _buildStatCard(
                icon: Icons.badge_rounded,
                title: 'Staff Totale',
                value: staffCount.toString(),
                subtitle: 'membri dello staff',
                iconColor: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildStatCard(
                icon: Icons.person_outline_rounded,
                title: 'Utenti Attivi',
                value: activeCount.toString(),
                subtitle: '$activePercentage% operativi',
                iconColor: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildStatCard(
                icon: Icons.point_of_sale_rounded,
                title: 'Clienti Cassa',
                value: cashierDisplay,
                subtitle: 'clienti caricati',
                iconColor: AppColors.info,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: AppTypography.medium,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusMD,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(flex: 3, child: _buildSearchField()),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 1, child: _buildRoleFilter()),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: _buildViewToggle()),
              ],
            )
          : Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: AppSpacing.md),
                Row(children: [Expanded(child: _buildRoleFilter())]),
                const SizedBox(height: AppSpacing.md),
                _buildViewToggle(),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: _currentView == UsersViewMode.cashierUsers
              ? 'Cerca cliente (nome, telefono, indirizzo)...'
              : 'Cerca staff (nome, email)...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textTertiary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilter() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole?>(
          value: _selectedRole,
          isExpanded: true,
          hint: Text(
            'Tutti i Ruoli',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          icon: const Icon(
            Icons.expand_more_rounded,
            color: AppColors.textSecondary,
          ),
          items: [
            DropdownMenuItem<UserRole?>(
              value: null,
              child: Text('Tutti i Ruoli', style: AppTypography.bodyMedium),
            ),
            ...UserRole.values.map(
              (role) => DropdownMenuItem<UserRole>(
                value: role,
                child: Text(role.displayName, style: AppTypography.bodyMedium),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _selectedRole = value),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
      ),
      child: Row(
        children: UsersViewMode.values.map((view) {
          final isSelected = _currentView == view;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentView = view),
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: AppRadius.radiusMD,
                  boxShadow: isSelected ? AppShadows.sm : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        view.icon,
                        size: 18,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        view.displayName,
                        style: AppTypography.labelMedium.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? AppTypography.semiBold
                              : AppTypography.regular,
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

  Widget _buildUsersTable(List<UserModel> allUsers) {
    // Filter by role (staff only in staff view)
    var filteredUsers = allUsers.where((user) => user.isStaff).toList();

    // Apply role filter
    if (_selectedRole != null) {
      filteredUsers = filteredUsers
          .where((user) => user.ruolo == _selectedRole)
          .toList();
    }

    // Apply search filter (Client-side for staff - dataset is small)
    if (_searchQuery.isNotEmpty && _currentView == UsersViewMode.staff) {
      final query = _searchQuery.toLowerCase();
      filteredUsers = filteredUsers.where((user) {
        return user.email.toLowerCase().contains(query) ||
            (user.nome?.toLowerCase().contains(query) ?? false) ||
            (user.cognome?.toLowerCase().contains(query) ?? false) ||
            (user.telefono?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    // Apply sorting
    filteredUsers = _sortUsers(filteredUsers);

    return _buildDataTable(filteredUsers);
  }

  List<UserModel> _sortUsers(List<UserModel> users) {
    final sorted = List<UserModel>.from(users);
    sorted.sort((a, b) {
      int result;
      switch (_staffSortColumnIndex) {
        case 0: // Name
          result = a.nomeCompleto.toLowerCase().compareTo(
            b.nomeCompleto.toLowerCase(),
          );
        case 1: // Role
          result = a.ruolo.displayName.compareTo(b.ruolo.displayName);
        case 2: // Status
          result = (a.attivo ? 1 : 0).compareTo(b.attivo ? 1 : 0);
        case 3: // Last Active
          final aDate = a.ultimoAccesso ?? DateTime(1970);
          final bDate = b.ultimoAccesso ?? DateTime(1970);
          result = aDate.compareTo(bDate);
        default:
          result = 0;
      }
      return _staffSortAscending ? result : -result;
    });
    return sorted;
  }

  void _onStaffSort(int columnIndex) {
    setState(() {
      if (_staffSortColumnIndex == columnIndex) {
        _staffSortAscending = !_staffSortAscending;
      } else {
        _staffSortColumnIndex = columnIndex;
        _staffSortAscending = true;
      }
    });
  }

  Widget _buildCashierCustomersTable(CashierCustomersState state) {
    final customers = state.items;

    if (customers.isEmpty && !state.isLoadingMore) {
      return _buildEmptyState();
    }

    // No client side sorting for cashier customers, utilize server side via provider

    return Column(
      children: [
        _buildCashierDataTable(state),
        if (state.isLoadingMore)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  // Helper method removed as sorting is now server-side

  void _onCashierSort(String column) {
    ref.read(cashierCustomersNotifierProvider.notifier).sort(column);
  }

  Widget _buildDataTable(List<UserModel> users) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.xxl),
                topRight: Radius.circular(AppSpacing.xxl),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _SortableColumnHeader(
                    label: 'Utente',
                    isActive: _staffSortColumnIndex == 0,
                    ascending: _staffSortAscending,
                    onTap: () => _onStaffSort(0),
                  ),
                ),
                if (isDesktop) ...[
                  Expanded(
                    flex: 2,
                    child: _SortableColumnHeader(
                      label: 'Ruolo',
                      isActive: _staffSortColumnIndex == 1,
                      ascending: _staffSortAscending,
                      onTap: () => _onStaffSort(1),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _SortableColumnHeader(
                      label: 'Stato',
                      isActive: _staffSortColumnIndex == 2,
                      ascending: _staffSortAscending,
                      onTap: () => _onStaffSort(2),
                    ),
                  ),
                ],
                SizedBox(
                  width: isDesktop ? 100 : 60,
                  child: Text(
                    'Azioni',
                    textAlign: TextAlign.right,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserRow(user, isDesktop);
            },
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppSpacing.xxl),
                bottomRight: Radius.circular(AppSpacing.xxl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Mostrando ${users.length} utenti',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserModel user, bool isDesktop) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showUserDetailModal(user),
        child: Container(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
          child: Row(
            children: [
              // User info
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isDesktop ? 22 : 18,
                      backgroundColor: _getAvatarColor(user.ruolo),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              _getInitials(user),
                              style: AppTypography.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: AppTypography.semiBold,
                              ),
                            )
                          : null,
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
                          Text(
                            user.email,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                // Role
                Expanded(flex: 2, child: _buildRoleBadge(user.ruolo)),
                // Status
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: user.attivo
                              ? AppColors.success
                              : AppColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        user.attivo ? 'Attivo' : 'Inattivo',
                        style: AppTypography.bodySmall.copyWith(
                          color: user.attivo
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Actions
              SizedBox(
                width: isDesktop ? 100 : 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showUserDetailModal(user),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      tooltip: 'Modifica',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashierDataTable(CashierCustomersState state) {
    final customers = state.items;
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.xxl),
                topRight: Radius.circular(AppSpacing.xxl),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _SortableColumnHeader(
                    label: 'Cliente',
                    isActive: state.sortColumn == 'nome',
                    ascending: state.sortAscending,
                    onTap: () => _onCashierSort('nome'),
                  ),
                ),
                if (isDesktop) ...[
                  Expanded(
                    flex: 2,
                    child: _SortableColumnHeader(
                      label: 'Ordini',
                      isActive: state.sortColumn == 'ordini_count',
                      ascending: state.sortAscending,
                      onTap: () => _onCashierSort('ordini_count'),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SortableColumnHeader(
                      label: 'Totale Speso',
                      isActive: state.sortColumn == 'totale_speso',
                      ascending: state.sortAscending,
                      onTap: () => _onCashierSort('totale_speso'),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SortableColumnHeader(
                      label: 'Ultimo Ordine',
                      isActive: state.sortColumn == 'ultimo_ordine_at',
                      ascending: state.sortAscending,
                      onTap: () => _onCashierSort('ultimo_ordine_at'),
                    ),
                  ),
                ],
                SizedBox(
                  width: isDesktop ? 100 : 60,
                  child: Text(
                    'Azioni',
                    textAlign: TextAlign.right,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customers.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _buildCashierCustomerRow(customer, isDesktop);
            },
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppSpacing.xxl),
                bottomRight: Radius.circular(AppSpacing.xxl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Mostrando ${customers.length} clienti',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashierCustomerRow(
    CashierCustomerModel customer,
    bool isDesktop,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCashierCustomerDetailModal(customer),
        child: Container(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
          child: Row(
            children: [
              // Customer info
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isDesktop ? 22 : 18,
                      backgroundColor: _getCashierAvatarColor(
                        customer.ordiniCount,
                      ),
                      child: Text(
                        _getCashierInitials(customer),
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
                          if (customer.telefono != null)
                            Text(
                              customer.telefono!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                // Orders count
                Expanded(
                  flex: 2,
                  child: _buildOrdersBadge(customer.ordiniCount),
                ),
                // Total spent
                Expanded(
                  flex: 2,
                  child: Text(
                    '€${customer.totaleSpeso.toStringAsFixed(2)}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.success,
                    ),
                  ),
                ),
                // Last order
                Expanded(
                  flex: 2,
                  child: Text(
                    customer.ultimoOrdineAt != null
                        ? _formatLastActive(customer.ultimoOrdineAt!)
                        : 'Mai',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              // Actions
              SizedBox(
                width: isDesktop ? 100 : 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () =>
                          _showCashierCustomerDetailModal(customer),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      tooltip: 'Dettagli',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color color;
    Color bgColor;
    switch (role) {
      case UserRole.manager:
        color = const Color(0xFF7C3AED);
        bgColor = const Color(0xFFF3E8FF);
        break;
      case UserRole.kitchen:
        color = const Color(0xFF2563EB);
        bgColor = const Color(0xFFDBEAFE);
        break;
      case UserRole.delivery:
        color = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        break;
      case UserRole.customer:
        color = const Color(0xFF059669);
        bgColor = const Color(0xFFD1FAE5);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusCircular,
      ),
      child: Text(
        role.displayName,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: AppTypography.semiBold,
        ),
      ),
    );
  }

  Widget _buildOrdersBadge(int count) {
    Color color;
    Color bgColor;
    if (count >= 20) {
      color = AppColors.gold;
      bgColor = AppColors.goldLight;
    } else if (count >= 10) {
      color = AppColors.success;
      bgColor = AppColors.successLight;
    } else if (count >= 5) {
      color = AppColors.info;
      bgColor = AppColors.primarySubtle;
    } else {
      color = AppColors.textSecondary;
      bgColor = AppColors.surfaceLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            count.toString(),
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: AppTypography.semiBold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _searchQuery.isNotEmpty
        ? 'Nessun risultato per "$_searchQuery"'
        : _currentView == UsersViewMode.staff
        ? 'Nessun membro dello staff'
        : 'Nessun cliente cassa registrato';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            message,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Caricamento utenti...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Errore nel caricamento', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Non siamo riusciti a caricare gli utenti.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: () => ref.refresh(pizzeriaUsersProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
            ),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getAvatarColor(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return const Color(0xFF7C3AED);
      case UserRole.kitchen:
        return const Color(0xFF2563EB);
      case UserRole.delivery:
        return const Color(0xFFD97706);
      case UserRole.customer:
        return const Color(0xFF059669);
    }
  }

  Color _getCashierAvatarColor(int ordiniCount) {
    if (ordiniCount >= 20) return AppColors.gold;
    if (ordiniCount >= 10) return AppColors.success;
    if (ordiniCount >= 5) return AppColors.info;
    return AppColors.textSecondary;
  }

  String _getInitials(UserModel user) {
    if (user.nome != null &&
        user.cognome != null &&
        user.nome!.isNotEmpty &&
        user.cognome!.isNotEmpty) {
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

  String _getCashierInitials(CashierCustomerModel customer) {
    if (customer.nome.isEmpty) return '?';

    final parts = customer.nome.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0];
      final second = parts[1];
      if (first.isNotEmpty && second.isNotEmpty) {
        return '${first[0]}${second[0]}'.toUpperCase();
      }
    }

    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }

    return '?';
  }

  String _formatLastActive(DateTime dateTime) {
    // Convert UTC to local time
    final localDateTime = dateTime.toLocal();
    final now = DateTime.now();

    // Compare calendar days, not 24-hour periods
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );
    final yesterday = today.subtract(const Duration(days: 1));

    if (dateOnly == today) {
      final diff = now.difference(localDateTime);
      if (diff.inMinutes < 1) return 'Ora';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
      return '${diff.inHours} ore fa';
    }
    if (dateOnly == yesterday) return 'Ieri';

    final daysAgo = today.difference(dateOnly).inDays;
    if (daysAgo < 7) return '$daysAgo giorni fa';

    return DateFormat('dd MMM yyyy', 'it_IT').format(localDateTime);
  }

  void _showUserDetailModal(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => UserDetailModal(
        user: user,
        onRoleChanged: (userId, newRole) async {
          await ref
              .read(pizzeriaUsersProvider.notifier)
              .updateUserRole(userId, newRole);
        },
        onStatusToggled: (userId, isActive) async {
          await ref
              .read(pizzeriaUsersProvider.notifier)
              .toggleUserStatus(userId, isActive);
        },
      ),
    );
  }

  void _showCashierCustomerDetailModal(CashierCustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => UserDetailModal.forCashierCustomer(
        cashierCustomer: customer,
        onCustomerUpdated: () {
          ref.read(cashierCustomersNotifierProvider.notifier).refresh();
        },
      ),
    );
  }
}

/// Sortable column header widget
class _SortableColumnHeader extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const _SortableColumnHeader({
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
