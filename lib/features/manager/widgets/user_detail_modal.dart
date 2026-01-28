import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/cashier_customer_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/user_orders_provider.dart';
import '../../../providers/user_performance_provider.dart';

/// Unified detail modal for both staff users and cashier customers
class UserDetailModal extends ConsumerStatefulWidget {
  /// Staff user (optional - either user or cashierCustomer must be provided)
  final UserModel? user;

  /// Cashier customer (optional - either user or cashierCustomer must be provided)
  final CashierCustomerModel? cashierCustomer;

  final Function(String userId, UserRole newRole)? onRoleChanged;
  final Function(String userId, bool isActive)? onStatusToggled;
  final VoidCallback? onCustomerUpdated;

  const UserDetailModal({
    super.key,
    this.user,
    this.cashierCustomer,
    this.onRoleChanged,
    this.onStatusToggled,
    this.onCustomerUpdated,
  }) : assert(
         user != null || cashierCustomer != null,
         'Either user or cashierCustomer must be provided',
       );

  /// Constructor for staff users
  const UserDetailModal.forUser({
    super.key,
    required UserModel this.user,
    required Function(String userId, UserRole newRole) this.onRoleChanged,
    required Function(String userId, bool isActive) this.onStatusToggled,
  }) : cashierCustomer = null,
       onCustomerUpdated = null;

  /// Constructor for cashier customers
  const UserDetailModal.forCashierCustomer({
    super.key,
    required CashierCustomerModel this.cashierCustomer,
    this.onCustomerUpdated,
  }) : user = null,
       onRoleChanged = null,
       onStatusToggled = null;

  @override
  ConsumerState<UserDetailModal> createState() => _UserDetailModalState();
}

class _UserDetailModalState extends ConsumerState<UserDetailModal> {
  bool _showDeliveryData = false;
  String _orderFilter = 'all';
  bool _isUpdating = false;
  int _currentOrderPage = 0;
  static const int _ordersPerPage = 10;

  // Editing state for cashier customers
  // Reserved for future editing functionality
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _notesController;

  /// Returns true if showing a staff user, false if showing a cashier customer
  bool get _isStaffUser => widget.user != null;

  /// Returns true if showing a cashier customer
  bool get _isCashierCustomer => widget.cashierCustomer != null;

  bool get _canShowDeliveryToggle =>
      _isStaffUser &&
      (widget.user!.ruolo == UserRole.manager ||
          widget.user!.ruolo == UserRole.delivery);

  @override
  void initState() {
    super.initState();
    if (_isCashierCustomer) {
      final customer = widget.cashierCustomer!;
      _nameController = TextEditingController(text: customer.nome);
      _phoneController = TextEditingController(text: customer.telefono ?? '');
      _addressController = TextEditingController(
        text: customer.indirizzo ?? '',
      );
      _cityController = TextEditingController(text: customer.citta ?? '');
      _notesController = TextEditingController(text: customer.note ?? '');
    } else {
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _addressController = TextEditingController();
      _cityController = TextEditingController();
      _notesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = isDesktop ? screenWidth * 0.8 : screenWidth * 0.95;
    final maxModalWidth = 1200.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 16,
        vertical: 24,
      ),
      child: Container(
        width: modalWidth.clamp(0, maxModalWidth),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXXXL,
          boxShadow: AppShadows.xl,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
                ),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildLeftColumn()),
                          const SizedBox(width: AppSpacing.xxl),
                          Expanded(flex: 8, child: _buildRightColumn()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildLeftColumn(),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildRightColumn(),
                        ],
                      ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dettagli Utente',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Visualizza e modifica le informazioni dello staff',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        _buildProfileCard(),
        const SizedBox(height: AppSpacing.xl),
        _buildPerformanceCard(),
      ],
    );
  }

  Widget _buildProfileCard() {
    // For cashier customers
    if (_isCashierCustomer) {
      final customer = widget.cashierCustomer!;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXXL,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 56,
              backgroundColor: _getCashierAvatarColor(customer.ordiniCount),
              child: Text(
                _getCashierInitials(customer),
                style: AppTypography.headlineLarge.copyWith(
                  color: Colors.white,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Name
            Text(
              customer.nome,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: AppTypography.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            // Customer badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: AppRadius.radiusCircular,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${customer.ordiniCount} ordini',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.gold,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Contact info
            if (customer.telefono != null)
              _buildContactItem(
                icon: Icons.phone_outlined,
                label: 'Telefono',
                value: customer.telefono!,
              ),
            if (customer.telefono != null)
              const SizedBox(height: AppSpacing.md),
            if (customer.indirizzo != null)
              _buildContactItem(
                icon: Icons.location_on_outlined,
                label: 'Indirizzo',
                value: customer.indirizzo!,
              ),
            if (customer.indirizzo != null)
              const SizedBox(height: AppSpacing.md),
            if (customer.citta != null)
              _buildContactItem(
                icon: Icons.location_city_outlined,
                label: 'Città',
                value: customer.citta!,
              ),
            // Total spent
            const SizedBox(height: AppSpacing.md),
            _buildContactItem(
              icon: Icons.euro_outlined,
              label: 'Totale Speso',
              value: '€${customer.totaleSpeso.toStringAsFixed(2)}',
            ),
          ],
        ),
      );
    }

    // For staff users
    final user = widget.user!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Avatar with status indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: _getAvatarColor(user.ruolo),
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        _getInitials(user),
                        style: AppTypography.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: AppTypography.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: user.attivo
                        ? AppColors.success
                        : AppColors.textTertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Name
          Text(
            user.nomeCompleto,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: AppTypography.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          // ID
          Text(
            'ID: ${user.id.substring(0, 8)}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Role badge
          _buildRoleBadge(user.ruolo),
          const SizedBox(height: AppSpacing.xxl),
          // Contact info
          _buildContactItem(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildContactItem(
            icon: Icons.phone_outlined,
            label: 'Telefono',
            value: user.telefono ?? 'Non specificato',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildContactItem(
            icon: Icons.location_on_outlined,
            label: 'Località',
            value: user.citta ?? 'Non specificata',
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
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
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    // For cashier customers, show their stats inline
    if (_isCashierCustomer) {
      final customer = widget.cashierCustomer!;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusXXL,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiche',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetric(
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.primary,
                    value: customer.ordiniCount.toString(),
                    label: 'Ordini',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildPerformanceMetric(
                    icon: Icons.euro_rounded,
                    iconColor: AppColors.success,
                    value: customer.ordiniCount > 0
                        ? '€${(customer.totaleSpeso / customer.ordiniCount).toStringAsFixed(0)}'
                        : '€0',
                    label: 'Media',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildPerformanceMetric(
              icon: Icons.payments_rounded,
              iconColor: AppColors.info,
              value: '€${customer.totaleSpeso.toStringAsFixed(2)}',
              label: 'Totale Speso',
              fullWidth: true,
            ),
          ],
        ),
      );
    }

    // For staff users
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_showDeliveryData && _canShowDeliveryToggle)
            _buildDeliveryPerformance()
          else
            _buildCustomerPerformance(),
        ],
      ),
    );
  }

  Widget _buildCustomerPerformance() {
    final performanceAsync = ref.watch(
      userPerformanceProvider(widget.user!.id),
    );

    return performanceAsync.when(
      data: (performance) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppColors.primary,
                  value: performance.totalOrders.toString(),
                  label: 'Ordini',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildPerformanceMetric(
                  icon: Icons.euro_rounded,
                  iconColor: AppColors.success,
                  value: '€${performance.averageOrderValue.toStringAsFixed(0)}',
                  label: 'Media',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPerformanceMetric(
            icon: Icons.payments_rounded,
            iconColor: AppColors.info,
            value: '€${performance.totalSpent.toStringAsFixed(2)}',
            label: 'Totale Speso',
            fullWidth: true,
          ),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          'Errore nel caricamento',
          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildDeliveryPerformance() {
    final performanceAsync = ref.watch(
      deliveryPerformanceProvider(widget.user!.id),
    );

    return performanceAsync.when(
      data: (performance) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                  icon: Icons.delivery_dining_rounded,
                  iconColor: AppColors.primary,
                  value: performance.totalDeliveries.toString(),
                  label: 'Consegne',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildPerformanceMetric(
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.info,
                  value:
                      '${performance.averageDeliveryTimeMinutes.toStringAsFixed(0)} min',
                  label: 'Tempo Medio',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPerformanceMetric(
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            value: '${performance.onTimePercentage.toStringAsFixed(0)}%',
            label: 'Consegne Puntuali',
            fullWidth: true,
          ),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          'Errore nel caricamento',
          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle for delivery/customer data (only for managers and delivery)
        if (_canShowDeliveryToggle) ...[
          _buildDataModeToggle(),
          const SizedBox(height: AppSpacing.xl),
        ],
        _buildOrderHistorySection(),
      ],
    );
  }

  Widget _buildDataModeToggle() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            label: 'Dati Cliente',
            icon: Icons.shopping_bag_outlined,
            isSelected: !_showDeliveryData,
            onTap: () => setState(() => _showDeliveryData = false),
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildToggleButton(
            label: 'Dati Consegne',
            icon: Icons.delivery_dining_rounded,
            isSelected: _showDeliveryData,
            onTap: () => setState(() => _showDeliveryData = true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.radiusMD,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected
                    ? AppTypography.semiBold
                    : AppTypography.regular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistorySection() {
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showDeliveryData ? 'Storico Consegne' : 'Storico Ordini',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                _buildOrderFilterTabs(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Order list
          _buildOrderList(),
        ],
      ),
    );
  }

  Widget _buildOrderFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterTab('Tutti', 'all'),
          _buildFilterTab('Completati', 'completed'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _orderFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _orderFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.radiusSM,
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected
                ? AppTypography.semiBold
                : AppTypography.regular,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    // Get user ID based on type
    final userId = _isStaffUser ? widget.user!.id : widget.cashierCustomer!.id;
    final ordersParams = UserOrdersParams(
      userId: userId,
      deliveryMode: _showDeliveryData && _canShowDeliveryToggle,
    );
    final ordersAsync = ref.watch(userOrdersProvider(ordersParams));

    return ordersAsync.when(
      data: (orders) {
        // Apply filter
        var filteredOrders = orders;
        if (_orderFilter == 'completed') {
          filteredOrders = orders
              .where((o) => o.stato == OrderStatus.completed)
              .toList();
        }

        if (filteredOrders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Nessun ordine trovato',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Ordine',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Prodotti',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Data',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Stato',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Totale',
                      textAlign: TextAlign.right,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Orders - with pagination
            Builder(
              builder: (context) {
                final startIndex = _currentOrderPage * _ordersPerPage;
                final endIndex = (startIndex + _ordersPerPage).clamp(
                  0,
                  filteredOrders.length,
                );
                final pageOrders = filteredOrders.sublist(startIndex, endIndex);

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pageOrders.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) =>
                      _buildOrderRow(pageOrders[index]),
                );
              },
            ),
            // Footer with pagination controls
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Builder(
                builder: (context) {
                  final totalPages = (filteredOrders.length / _ordersPerPage)
                      .ceil();
                  final startIndex = _currentOrderPage * _ordersPerPage;
                  final endIndex = (startIndex + _ordersPerPage).clamp(
                    0,
                    filteredOrders.length,
                  );

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mostrando ${startIndex + 1}-$endIndex di ${filteredOrders.length} ordini',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (totalPages > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              onPressed: _currentOrderPage > 0
                                  ? () => setState(() => _currentOrderPage--)
                                  : null,
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                disabledForegroundColor: AppColors.textTertiary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: AppRadius.radiusSM,
                              ),
                              child: Text(
                                '${_currentOrderPage + 1} / $totalPages',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: AppTypography.semiBold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              onPressed: _currentOrderPage < totalPages - 1
                                  ? () => setState(() => _currentOrderPage++)
                                  : null,
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                disabledForegroundColor: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Errore nel caricamento degli ordini',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(OrderModel order) {
    final itemsText = order.items.isNotEmpty
        ? order.items.first.nomeProdotto
        : 'Ordine';
    final extraItems = order.items.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '#${order.displayNumeroOrdine}',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemsText,
                  style: AppTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (extraItems > 0)
                  Text(
                    '+ $extraItems altri prodotti',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatOrderDate(order.slotPrenotatoStart ?? order.createdAt),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(flex: 2, child: _buildStatusBadge(order.stato)),
          Expanded(
            flex: 1,
            child: Text(
              '€${order.totale.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    Color bgColor;
    String text;

    switch (status) {
      case OrderStatus.pending:
        color = AppColors.warning;
        bgColor = const Color(0xFFFEF3C7);
        text = 'In Attesa';
        break;
      case OrderStatus.confirmed:
        color = AppColors.info;
        bgColor = const Color(0xFFDBEAFE);
        text = 'Confermato';
        break;
      case OrderStatus.preparing:
        color = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        text = 'In Preparazione';
        break;
      case OrderStatus.ready:
        color = AppColors.primary;
        bgColor = AppColors.primarySubtle;
        text = 'Pronto';
        break;
      case OrderStatus.delivering:
        color = const Color(0xFF2563EB);
        bgColor = const Color(0xFFDBEAFE);
        text = 'In Consegna';
        break;
      case OrderStatus.completed:
        color = AppColors.success;
        bgColor = AppColors.successLight;
        text = 'Completato';
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        bgColor = const Color(0xFFFEE2E2);
        text = 'Annullato';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusCircular,
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: AppTypography.semiBold,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    // Cashier customer footer - simple close button
    if (_isCashierCustomer) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
              ),
              child: Text(
                'Chiudi',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Staff user footer
    final user = widget.user!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status toggle
          Row(
            children: [
              Text(
                'Stato:',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Switch(
                value: user.attivo,
                onChanged: _isUpdating
                    ? null
                    : (value) async {
                        setState(() => _isUpdating = true);
                        try {
                          await widget.onStatusToggled!(user.id, value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? 'Utente attivato'
                                      : 'Utente disattivato',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Errore nell\'aggiornamento',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                activeTrackColor: AppColors.success,
                activeThumbColor: Colors.white,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                user.attivo ? 'Attivo' : 'Inattivo',
                style: AppTypography.bodyMedium.copyWith(
                  color: user.attivo
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: AppTypography.medium,
                ),
              ),
            ],
          ),
          // Action buttons
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusLG,
                  ),
                ),
                child: Text(
                  'Chiudi',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton(
                onPressed: () => _showRoleChangeDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusLG,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Modifica Ruolo',
                  style: AppTypography.labelLarge.copyWith(color: Colors.white),
                ),
              ),
            ],
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
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusCircular,
      ),
      child: Text(
        role.displayName.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: AppTypography.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  String _formatOrderDate(DateTime dateTime) {
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
      return 'Oggi, ${DateFormat('HH:mm').format(localDateTime)}';
    }
    if (dateOnly == yesterday) return 'Ieri';

    final daysAgo = today.difference(dateOnly).inDays;
    if (daysAgo < 7) return '$daysAgo giorni fa';

    return DateFormat('dd MMM yyyy', 'it_IT').format(localDateTime);
  }

  void _showRoleChangeDialog() {
    final user = widget.user!;
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
                    onTap: () async {
                      Navigator.pop(context);
                      if (!isSelected) {
                        setState(() => _isUpdating = true);
                        try {
                          await widget.onRoleChanged!(user.id, role);
                          if (!mounted) return;

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ruolo aggiornato a ${role.displayName}',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Errore nell\'aggiornamento del ruolo',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
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
                          Text(
                            role.displayName,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: AppTypography.semiBold,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
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

  Color _getCashierAvatarColor(int ordiniCount) {
    if (ordiniCount >= 20) return AppColors.gold;
    if (ordiniCount >= 10) return AppColors.success;
    if (ordiniCount >= 5) return AppColors.info;
    return AppColors.textSecondary;
  }

  String _getCashierInitials(CashierCustomerModel customer) {
    final parts = customer.nome.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return customer.nome.isNotEmpty ? customer.nome[0].toUpperCase() : '?';
  }
}
