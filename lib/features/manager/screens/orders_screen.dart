import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_reminder_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../providers/manager_orders_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/cashier_order_provider.dart';
import '../../../providers/reminders_provider.dart';
import '../../../core/services/database_service.dart';
import '../widgets/order_detail_panel.dart';

/// Clean, focused orders management screen
/// Shows active orders with quick actions and modify capability
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String? _selectedOrderId;

  // Tab definitions
  static const _tabs = [
    _TabConfig('Attivi', null, true), // Active orders (not completed/cancelled)
    _TabConfig('In Attesa', OrderStatus.pending, false),
    _TabConfig('Confermati', OrderStatus.confirmed, false),
    _TabConfig('In Preparazione', OrderStatus.preparing, false),
    _TabConfig('Pronti', OrderStatus.ready, false),
    _TabConfig('Completati', OrderStatus.completed, false),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(managerOrdersProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(context, isDesktop),

          // Tab bar
          _buildTabBar(),

          // Orders list
          Expanded(
            child: ordersAsync.when(
              data: (orders) => isDesktop
                  ? _buildDesktopLayout(orders)
                  : _buildOrdersList(orders),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => _buildErrorState(e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.sm,
      ),
      child: isDesktop
          ? Row(
              children: [
                _buildTitle(),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _buildSubtitle()),
                _buildRefreshButton(ref),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchField(isDesktop)),
                const SizedBox(width: AppSpacing.sm),
                _buildRefreshButton(ref),
              ],
            ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.orangeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.receipt_long_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestione Ordini',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: AppTypography.bold,
          ),
        ),
        Text(
          'Visualizza, modifica e gestisci gli ordini',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isDesktop) {
    return SizedBox(
      width: isDesktop ? 300 : null,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Cerca ordine...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton(WidgetRef ref) {
    return IconButton(
      onPressed: () => ref.refresh(managerOrdersProvider),
      icon: const Icon(Icons.refresh_rounded),
      tooltip: 'Aggiorna',
      style: IconButton.styleFrom(backgroundColor: AppColors.surfaceLight),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: AppTypography.bold,
        ),
        unselectedLabelStyle: AppTypography.labelLarge,
        tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
      ),
    );
  }

  // Desktop master-detail layout
  Widget _buildDesktopLayout(List<OrderModel> allOrders) {
    final selectedOrder = _selectedOrderId != null
        ? allOrders.where((o) => o.id == _selectedOrderId).firstOrNull
        : null;

    return Row(
      children: [
        // Orders list (left panel)
        SizedBox(
          width: 480,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildSearchField(false),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      final filtered = _filterOrders(allOrders, tab);
                      if (filtered.isEmpty) {
                        return _buildEmptyState(tab.label);
                      }
                      return _buildCompactOrdersList(filtered);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Order detail (right panel)
        Expanded(
          child: selectedOrder != null
              ? OrderDetailPanel(
                  order: selectedOrder,
                  onModify: () => _modifyOrder(selectedOrder),
                  onStatusChange: (status) =>
                      _updateStatus(selectedOrder.id, status),
                  onCancel: () => _cancelOrder(selectedOrder),
                  onPrint: () => _printOrder(selectedOrder),
                  onTogglePagato: () => _togglePagato(selectedOrder),
                  onClose: () => setState(() => _selectedOrderId = null),
                  onCreateReminder: () =>
                      _showCreateReminderDialog(selectedOrder),
                )
              : _buildSelectOrderPrompt(),
        ),
      ],
    );
  }

  Widget _buildSelectOrderPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Seleziona un ordine',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Clicca su un ordine dalla lista per vedere i dettagli',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOrdersList(List<OrderModel> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isSelected = order.id == _selectedOrderId;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _CompactOrderCard(
            order: order,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedOrderId = order.id),
          ),
        );
      },
    );
  }

  Widget _buildOrdersList(List<OrderModel> allOrders) {
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((tab) {
        final filtered = _filterOrders(allOrders, tab);
        if (filtered.isEmpty) {
          return _buildEmptyState(tab.label);
        }
        return _buildOrdersListView(filtered);
      }).toList(),
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders, _TabConfig tab) {
    var filtered = orders;

    // Filter by tab
    if (tab.isActiveTab) {
      // Active = not completed and not cancelled
      filtered = filtered
          .where(
            (o) =>
                o.stato != OrderStatus.completed &&
                o.stato != OrderStatus.cancelled,
          )
          .toList();
    } else if (tab.status != null) {
      filtered = filtered.where((o) => o.stato == tab.status).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.numeroOrdine.toLowerCase().contains(query) ||
            o.nomeCliente.toLowerCase().contains(query) ||
            o.telefonoCliente.contains(query);
      }).toList();
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Widget _buildOrdersListView(List<OrderModel> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _OrderCard(
            order: order,
            onModify: () => _modifyOrder(order),
            onStatusChange: (status) => _updateStatus(order.id, status),
            onCancel: () => _cancelOrder(order),
            onPrint: () => _printOrder(order),
            onTap: () => _showOrderDetailSheet(order),
          ),
        );
      },
    );
  }

  void _showOrderDetailSheet(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: OrderDetailPanel(
                  order: order,
                  scrollController: controller,
                  onModify: () {
                    Navigator.pop(ctx);
                    _modifyOrder(order);
                  },
                  onStatusChange: (status) {
                    _updateStatus(order.id, status);
                  },
                  onCancel: () {
                    Navigator.pop(ctx);
                    _cancelOrder(order);
                  },
                  onPrint: () => _printOrder(order),
                  onTogglePagato: () {
                    _togglePagato(order);
                  },
                  onClose: () => Navigator.pop(ctx),
                  onCreateReminder: () {
                    Navigator.pop(ctx);
                    _showCreateReminderDialog(order);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String tabLabel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nessun ordine $tabLabel',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Gli ordini appariranno qui',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
          const SizedBox(height: AppSpacing.lg),
          Text('Errore nel caricamento', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: () => ref.refresh(managerOrdersProvider),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Future<void> _modifyOrder(OrderModel order) async {
    // Check if order can be modified
    if (order.stato == OrderStatus.completed ||
        order.stato == OrderStatus.cancelled) {
      _showSnackBar(
        'Non puoi modificare un ordine ${order.stato.displayName}',
        isError: true,
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifica Ordine'),
        content: Text(
          'Vuoi modificare l\'ordine #${order.numeroOrdine}?\n\n'
          'L\'ordine verrà caricato nel pannello cassa per la modifica. '
          'Il numero ordine rimarrà invariato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifica'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Load menu items for reconstruction
    List<MenuItemModel> menuItems;
    try {
      menuItems = await ref.read(menuProvider.future);
    } catch (e) {
      menuItems = [];
    }

    // Load order into cashier
    CashierOrderLoader.loadFromOrder(order, menuItems, ref);

    // Navigate to cashier screen
    if (mounted) {
      context.go('/manager/cashier-order');
    }
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      await ref
          .read(managerOrdersProvider.notifier)
          .updateStatus(orderId, newStatus);
      _showSnackBar('Stato aggiornato');
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annulla Ordine'),
        content: Text(
          'Sei sicuro di voler annullare l\'ordine #${order.numeroOrdine}?\n\n'
          'Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Annulla Ordine'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(managerOrdersProvider.notifier)
          .updateStatus(order.id, OrderStatus.cancelled);
      _showSnackBar('Ordine annullato');
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }

  Future<void> _printOrder(OrderModel order) async {
    try {
      final db = DatabaseService();
      await db.markOrderAsNotPrinted(order.id);
      _showSnackBar('Inviato alla stampante');
    } catch (e) {
      _showSnackBar('Errore invio stampa: $e', isError: true);
    }
  }

  Future<void> _togglePagato(OrderModel order) async {
    try {
      final db = DatabaseService();
      final newPagatoStatus = !order.pagato;
      await db.toggleOrderPagato(order.id, newPagatoStatus);
      ref.invalidate(managerOrdersProvider);
      _showSnackBar(
        newPagatoStatus
            ? 'Ordine segnato come pagato'
            : 'Ordine segnato come non pagato',
      );
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showCreateReminderDialog(OrderModel order) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    ReminderPriority selectedPriority = ReminderPriority.normal;
    DateTime? selectedDueDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notification_add_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nuovo Promemoria'),
                    Text(
                      'Ordine #${order.displayNumeroOrdine}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Titolo *',
                    hintText: 'Es: Chiamare cliente, Verificare indirizzo...',
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Description field
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Descrizione (opzionale)',
                    hintText: 'Aggiungi dettagli...',
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Priority selector
                Text(
                  'Priorità',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: ReminderPriority.values.map((priority) {
                    final isSelected = priority == selectedPriority;
                    return FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            priority.icon,
                            size: 16,
                            color: isSelected ? Colors.white : priority.color,
                          ),
                          const SizedBox(width: 4),
                          Text(priority.displayName),
                        ],
                      ),
                      selectedColor: priority.color,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      backgroundColor: priority.backgroundColor,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedPriority = priority);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Due date selector
                Text(
                  'Scadenza (opzionale)',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          selectedDueDate ?? DateTime.now(),
                        ),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: selectedDueDate != null
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            selectedDueDate != null
                                ? Formatters.dateTime(selectedDueDate!)
                                : 'Nessuna scadenza',
                            style: AppTypography.bodyMedium.copyWith(
                              color: selectedDueDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                        if (selectedDueDate != null)
                          IconButton(
                            onPressed: () {
                              setDialogState(() => selectedDueDate = null);
                            },
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inserisci un titolo'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crea Promemoria'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      await ref
          .read(activeRemindersProvider.notifier)
          .create(
            ordineId: order.id,
            titolo: titleController.text.trim(),
            descrizione: descriptionController.text.trim().isNotEmpty
                ? descriptionController.text.trim()
                : null,
            priorita: selectedPriority,
            scadenza: selectedDueDate,
          );
      _showSnackBar('Promemoria creato');
    } catch (e) {
      _showSnackBar('Errore: $e', isError: true);
    }
  }
}

// Tab configuration
class _TabConfig {
  final String label;
  final OrderStatus? status;
  final bool isActiveTab;

  const _TabConfig(this.label, this.status, this.isActiveTab);
}

/// Compact order card with essential info and actions
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onModify;
  final Function(OrderStatus) onStatusChange;
  final VoidCallback onCancel;
  final VoidCallback onPrint;
  final VoidCallback? onTap;

  const _OrderCard({
    required this.order,
    required this.onModify,
    required this.onStatusChange,
    required this.onCancel,
    required this.onPrint,
    this.onTap,
  });

  Color get _statusColor {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivering:
        return AppColors.accent;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData get _statusIcon {
    switch (order.stato) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing:
        return Icons.restaurant_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_rounded;
      case OrderStatus.delivering:
        return Icons.delivery_dining_rounded;
      case OrderStatus.completed:
        return Icons.done_all_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canModify =
        order.stato != OrderStatus.completed &&
        order.stato != OrderStatus.cancelled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Order number and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          children: [
                            Text(
                              '#${order.numeroOrdine}',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.stato.displayName,
                                style: AppTypography.captionSmall.copyWith(
                                  color: _statusColor,
                                  fontWeight: AppTypography.bold,
                                ),
                              ),
                            ),
                            // Pagato badge
                            if (order.pagato)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PAGATO',
                                      style: AppTypography.captionSmall
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: AppTypography.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.tipo.displayName} • ${Formatters.timeAgo(order.createdAt)}',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(order.totale),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: AppTypography.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${order.totalItems} articoli',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Customer info
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      order.nomeCliente,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: AppTypography.medium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      order.telefonoCliente,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Items preview
            if (order.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.items
                                .take(3)
                                .map((i) => '${i.quantita}x ${i.nomeProdotto}')
                                .join(', ') +
                            (order.items.length > 3
                                ? ' +${order.items.length - 3} altri'
                                : ''),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Actions
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Modify button
                  if (canModify)
                    OutlinedButton.icon(
                      onPressed: onModify,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Modifica'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                  // Next status button
                  if (_getNextStatus() != null)
                    ElevatedButton.icon(
                      onPressed: () => onStatusChange(_getNextStatus()!),
                      icon: Icon(_getNextStatusIcon(), size: 18),
                      label: Text(_getNextStatusLabel()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getNextStatusColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                  // Print button
                  IconButton(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_rounded),
                    tooltip: 'Stampa comanda',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceLight,
                    ),
                  ),

                  // Cancel button for active orders
                  if (canModify)
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Annulla ordine',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
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

  OrderStatus? _getNextStatus() {
    switch (order.stato) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? OrderStatus.delivering
            : OrderStatus.completed;
      case OrderStatus.delivering:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  String _getNextStatusLabel() {
    switch (order.stato) {
      case OrderStatus.pending:
        return 'Conferma';
      case OrderStatus.confirmed:
        return 'Inizia Preparazione';
      case OrderStatus.preparing:
        return 'Pronto';
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery ? 'In Consegna' : 'Completa';
      case OrderStatus.delivering:
        return 'Consegnato';
      default:
        return '';
    }
  }

  IconData _getNextStatusIcon() {
    switch (order.stato) {
      case OrderStatus.pending:
        return Icons.check_rounded;
      case OrderStatus.confirmed:
        return Icons.restaurant_rounded;
      case OrderStatus.preparing:
        return Icons.check_circle_rounded;
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? Icons.delivery_dining_rounded
            : Icons.done_all_rounded;
      case OrderStatus.delivering:
        return Icons.done_all_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  Color _getNextStatusColor() {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.info;
      case OrderStatus.confirmed:
        return AppColors.primary;
      case OrderStatus.preparing:
        return AppColors.success;
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? AppColors.accent
            : AppColors.success;
      case OrderStatus.delivering:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }
}

/// Compact order card for desktop list view
class _CompactOrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactOrderCard({
    required this.order,
    required this.isSelected,
    required this.onTap,
  });

  Color get _statusColor {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivering:
        return AppColors.accent;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '#${order.numeroOrdine}',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: AppTypography.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.stato.displayName,
                            style: AppTypography.captionSmall.copyWith(
                              color: _statusColor,
                              fontWeight: AppTypography.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        // Pagato badge
                        if (order.pagato) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'PAGATO',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: AppTypography.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          order.tipo == OrderType.delivery
                              ? Icons.delivery_dining_rounded
                              : Icons.shopping_bag_rounded,
                          size: 14,
                          color: order.tipo == OrderType.delivery
                              ? AppColors.accent
                              : AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.nomeCliente,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Total and time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(order.totale),
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: AppTypography.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (order.slotPrenotatoStart != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          Formatters.time(order.slotPrenotatoStart!),
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      Formatters.timeAgo(order.createdAt),
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),

              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
