import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/app_colors.dart';
import '../../../DesignSystem/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_orders_provider.dart';
import '../../../providers/addresses_provider.dart';
import '../widgets/personal_info_sheet.dart';
import '../widgets/addresses_screen.dart';
import '../widgets/order_history_sheet.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/welcome_popup_manager.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final ordersAsync = ref.watch(customerOrdersProvider);
    final stats = ref.watch(customerOrderStatsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          100, // Added top padding for mobile top bar
          AppSpacing.lg,
          100, // Added bottom padding for navbar
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header
            _buildProfileHeader(context, user),
            const SizedBox(height: 32),

            // Stats cards
            ordersAsync.when(
              data: (_) => _buildStatsCards(stats),
              loading: () => _buildStatsCardsLoading(),
              error: (_, _) => _buildStatsCards({}),
            ),
            const SizedBox(height: 32),

            // Menu options
            _buildMenuSection(context, 'ACCOUNT', [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Informazioni Personali',
                subtitle: user != null
                    ? '${user.nome ?? ""} ${user.cognome ?? ""}'
                    : 'Gestisci i tuoi dati',
                onTap: () => _showPersonalInfo(context, user),
              ),
              _MenuItem(
                icon: Icons.location_on_outlined,
                title: 'Indirizzi',
                subtitle: ordersAsync.when(
                  data: (orders) {
                    final addressesAsync = ref.watch(userAddressesProvider);
                    return addressesAsync.when(
                      data: (addresses) => addresses.isEmpty
                          ? 'Nessun indirizzo salvato'
                          : '${addresses.length} indirizzo${addresses.length == 1 ? "" : "zi"} salvati',
                      loading: () => 'Caricamento...',
                      error: (_, _) => 'Nessun indirizzo salvato',
                    );
                  },
                  loading: () => 'Caricamento...',
                  error: (_, _) => 'Nessun indirizzo salvato',
                ),
                onTap: () => _showAddresses(context, user),
              ),
            ]),

            const SizedBox(height: 24),

            _buildMenuSection(context, 'ORDINI', [
              _MenuItem(
                icon: Icons.receipt_long_outlined,
                title: 'Storico Ordini',
                subtitle: ordersAsync.when(
                  data: (orders) =>
                      '${orders.where((o) => o.stato.isCompleted).length} ordini completati',
                  loading: () => 'Caricamento...',
                  error: (_, _) => 'Visualizza ordini',
                ),
                onTap: () => _showOrderHistory(context, ref),
              ),
            ]),

            const SizedBox(height: 24),

            _buildMenuSection(context, 'ALTRO', [
              // Show delivery screen button if user is delivery role
              if (user?.ruolo.name == 'delivery')
                _MenuItem(
                  icon: Icons.delivery_dining_outlined,
                  title: 'Schermata Delivery',
                  subtitle: 'Vai alla modalità consegne',
                  onTap: () => context.go(RouteNames.deliveryReady),
                ),
            ]),

            const SizedBox(height: 32),

            // Logout button
            _buildLogoutButton(ref),

            const SizedBox(height: 24),

            // App version
            Center(
              child: Text(
                'Versione 1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
    );
  }

  void _showPersonalInfo(BuildContext context, UserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonalInfoSheet(user: user),
    );
  }

  void _showAddresses(BuildContext context, UserModel? user) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: false,
      builder: (context) => AddressesScreen(user: user),
    );
  }

  void _showOrderHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OrderHistorySheet(),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.orangeGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                duration: 400.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // Name
          Text(
            user?.nomeCompleto ?? 'Utente',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            user?.email ?? '',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),

          // Edit profile button
          TextButton(
            onPressed: () => _showPersonalInfo(context, user),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Modifica Profilo',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    final totalOrders = stats['totalOrders'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.shopping_bag_outlined,
            value: totalOrders.toString(),
            label: 'Ordini',
            color: AppColors.primary,
            delay: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCardsLoading() {
    return Row(
      children: [
        Expanded(child: _buildStatCardSkeleton(0)),
      ],
    );
  }

  Widget _buildStatCardSkeleton(int delay) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: delay.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: delay.ms);
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required int delay,
  }) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: delay.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: delay.ms);
  }

  Widget _buildMenuSection(
    BuildContext context,
    String title,
    List<_MenuItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  _buildMenuItem(item),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 68),
                      child: Container(height: 1, color: AppColors.border),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Conferma Logout',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                content: Text(
                  'Sei sicuro di voler uscire?',
                  style: GoogleFonts.inter(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Annulla', style: GoogleFonts.inter()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Esci',
                      style: GoogleFonts.inter(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              // Reset welcome popup state so it shows on next login
              await WelcomePopupManager.reset();

              await ref.read(authProvider.notifier).signOut();
              // Navigate to menu screen after sign out
              if (context.mounted) {
                context.go(RouteNames.menu);
              }
            }
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Esci',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
