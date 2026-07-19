import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/global_providers.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/viewmodels/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentRoute = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final currentUser = ref.watch(currentUserProvider);

    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      if (next == null) {
        context.go('/login');
      }
    });

    // If not logged in, we shouldn't show main layout
    if (currentUser == null) {
      return Scaffold(body: child);
    }

    // Direct role-based path protection
    final role = currentUser.role;
    if (role == 'Cashier') {
      if (currentRoute != '/pos') {
        final router = GoRouter.of(context);
        Future.microtask(() => router.go('/pos'));
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    } else if (role == 'Stock Manager') {
      if (currentRoute != '/products' && currentRoute != '/purchases') {
        final router = GoRouter.of(context);
        Future.microtask(() => router.go('/products'));
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    } else if (role == 'Staff') {
      final allowed = ['/', '/pos', '/sales', '/products', '/purchases'];
      if (!allowed.contains(currentRoute)) {
        final router = GoRouter.of(context);
        Future.microtask(() => router.go('/pos'));
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    return Scaffold(
      appBar: !isDesktop
          ? AppBar(
              title: Text(
                ref.watch(storeProfileProvider)?.storeName.isNotEmpty == true
                    ? ref.watch(storeProfileProvider)!.storeName
                    : 'General Store',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
            )
          : null,
      drawer: !isDesktop
          ? Drawer(child: _SidebarContent(currentRoute: currentRoute))
          : null,
      body: Column(
        children: [
          // Offline connectivity banner
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              // Do not show the error banner while waiting for the first stream event
              if (!snapshot.hasData) return const SizedBox.shrink();

              final results = snapshot.data!;
              final isOffline = results.every(
                (r) => r == ConnectivityResult.none,
              );

              if (!isOffline) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: const Color(0xFFF59E0B), // amber
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '⚠️  No internet — Working in offline mode. Data will sync when connected.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  SizedBox(
                    width: 260,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: _SidebarContent(currentRoute: currentRoute),
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  final String currentRoute;

  const _SidebarContent({required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final storeProfile = ref.watch(storeProfileProvider);
    final role = currentUser?.role ?? 'Cashier';
    final name =
        (currentUser?.fullName != null && currentUser!.fullName.isNotEmpty)
        ? currentUser.fullName
        : currentUser?.username ?? 'User';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : 'U';

    // Store name from authenticated profile only
    final storeName = storeProfile?.storeName.isNotEmpty == true
        ? storeProfile!.storeName
        : 'My Store';

    return Column(
      children: [
        // App Logo & Store Name Header
        Container(
          padding: const EdgeInsets.all(24),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'General Store ERP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 12),
        // Menu Navigation List (Role-Based)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (role == 'Super Admin' || role == 'Admin') ...[
                _SidebarMenuItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/',
                  isSelected: currentRoute == '/',
                ),
                _SidebarMenuItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Cashier',
                  route: '/pos',
                  isSelected: currentRoute == '/pos',
                ),
                _SidebarMenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  route: '/sales',
                  isSelected: currentRoute == '/sales',
                ),
                _SidebarMenuItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products & Stock',
                  route: '/products',
                  isSelected: currentRoute == '/products',
                ),
                _SidebarMenuItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchases',
                  route: '/purchases',
                  isSelected: currentRoute == '/purchases',
                ),
                _SidebarMenuItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Accounts & Ledgers',
                  route: '/accounts',
                  isSelected: currentRoute == '/accounts',
                ),
                _SidebarMenuItem(
                  icon: Icons.people_rounded,
                  label: 'Customer Khata',
                  route: '/customer-accounts',
                  isSelected: currentRoute == '/customer-accounts',
                ),
                _SidebarMenuItem(
                  icon: Icons.local_shipping_rounded,
                  label: 'Supplier Khata',
                  route: '/supplier-accounts',
                  isSelected: currentRoute == '/supplier-accounts',
                ),
                _SidebarMenuItem(
                  icon: Icons.analytics_rounded,
                  label: 'Reports',
                  route: '/reports',
                  isSelected: currentRoute == '/reports',
                ),
                _SidebarMenuItem(
                  icon: Icons.people_alt_rounded,
                  label: 'User Management',
                  route: '/users',
                  isSelected: currentRoute == '/users',
                ),
                _SidebarMenuItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings & Backups',
                  route: '/settings',
                  isSelected: currentRoute == '/settings',
                ),
              ] else if (role == 'Stock Manager') ...[
                _SidebarMenuItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products & Stock',
                  route: '/products',
                  isSelected: currentRoute == '/products',
                ),
                _SidebarMenuItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchases',
                  route: '/purchases',
                  isSelected: currentRoute == '/purchases',
                ),
              ] else if (role == 'Staff') ...[
                _SidebarMenuItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/',
                  isSelected: currentRoute == '/',
                ),
                _SidebarMenuItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Cashier',
                  route: '/pos',
                  isSelected: currentRoute == '/pos',
                ),
                _SidebarMenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  route: '/sales',
                  isSelected: currentRoute == '/sales',
                ),
                _SidebarMenuItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products & Stock',
                  route: '/products',
                  isSelected: currentRoute == '/products',
                ),
                _SidebarMenuItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchases',
                  route: '/purchases',
                  isSelected: currentRoute == '/purchases',
                ),
              ] else ...[
                // Default Cashier Mode
                _SidebarMenuItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Cashier',
                  route: '/pos',
                  isSelected: currentRoute == '/pos',
                ),
                _SidebarMenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  route: '/sales',
                  isSelected: currentRoute == '/sales',
                ),
              ],
            ],
          ),
        ),
        // User Profile section
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await ref.read(authControllerProvider.notifier).logout();
                  router.go('/login');
                },
                tooltip: 'Logout',
              ),
            ],
          ),
        ),
        // Developer Footer
        const Divider(height: 1),
        InkWell(
          onTap: () async {
            final uri = Uri.parse('https://wa.me/923285753463');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            width: double.infinity,
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Developed by Vivid Digital Nexus',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'WhatsApp: +92 328 5753463',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;

  const _SidebarMenuItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 0.0,
      ), // Removed vertical margin
      child: InkWell(
        onTap: () {
          if (Scaffold.of(context).isDrawerOpen) {
            Navigator.pop(context);
          }
          context.go(route);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ), // Reduced vertical padding from 12 to 8
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color?.withValues(alpha: 0.7),
                size: 20, // Reduced from 22
              ),
              const SizedBox(width: 12), // Reduced from 16
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13, // Explicitly smaller font size
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.8,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
