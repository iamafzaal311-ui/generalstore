import 'dart:convert';
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
    final db = ref.watch(localDbServiceProvider);
    
    // Resolve current user, falling back to local DB session if initializing
    UserModel? currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      final lastUserId = db.settingsBox.get('last_logged_in_user_id');
      if (lastUserId != null) {
        currentUser = db.usersBox.get(lastUserId);
      }
    }

    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      if (next == null) {
        final lastUserId = db.settingsBox.get('last_logged_in_user_id');
        if (lastUserId == null) {
          context.go('/login');
        }
      }
    });

    // If no session exists at all, redirect to login
    if (currentUser == null) {
      final lastUserId = db.settingsBox.get('last_logged_in_user_id');
      if (lastUserId == null) {
        final router = GoRouter.of(context);
        Future.microtask(() => router.go('/login'));
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    final role = currentUser?.role ?? 'Cashier';
    
    // Direct role-based path protection
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

    final storeTitle = ref.watch(storeProfileProvider)?.storeName.isNotEmpty == true
        ? ref.watch(storeProfileProvider)!.storeName
        : 'VDN POS';

    final isDashboard = currentRoute == '/' || (role == 'Cashier' && currentRoute == '/pos');

    return Title(
      title: storeTitle,
      color: Theme.of(context).primaryColor,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.5,
          titleSpacing: 12,
          title: Row(
            children: [
              if (!isDashboard) ...[
                ElevatedButton.icon(
                  onPressed: () => context.go(role == 'Cashier' ? '/pos' : '/'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                storeTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          actions: [
            if (currentUser != null)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      currentUser.fullName.isNotEmpty ? currentUser.fullName : currentUser.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        drawer: !isDesktop
            ? Drawer(
                child: _SidebarContent(
                  currentRoute: currentRoute,
                  isExpanded: true,
                  isPinned: true,
                  onTogglePin: () {},
                ),
              )
            : null,
        body: Column(
          children: [
            // Offline connectivity banner
            StreamBuilder<List<ConnectivityResult>>(
              stream: Connectivity().onConnectivityChanged,
              builder: (context, snapshot) {
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
                  color: const Color(0xFFF59E0B),
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
                    _HoverExpandableSidebar(currentRoute: currentRoute),
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
      ),
    );
  }
}

class _HoverExpandableSidebar extends ConsumerStatefulWidget {
  final String currentRoute;
  const _HoverExpandableSidebar({required this.currentRoute});

  @override
  ConsumerState<_HoverExpandableSidebar> createState() => _HoverExpandableSidebarState();
}

class _HoverExpandableSidebarState extends ConsumerState<_HoverExpandableSidebar> {
  bool _isHovered = false;
  bool _isPinned = true;

  @override
  Widget build(BuildContext context) {
    final isExpanded = _isPinned || _isHovered;
    final width = isExpanded ? 250.0 : 70.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: _SidebarContent(
          currentRoute: widget.currentRoute,
          isExpanded: isExpanded,
          isPinned: _isPinned,
          onTogglePin: () {
            setState(() {
              _isPinned = !_isPinned;
            });
          },
        ),
      ),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  final String currentRoute;
  final bool isExpanded;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const _SidebarContent({
    required this.currentRoute,
    required this.isExpanded,
    required this.isPinned,
    required this.onTogglePin,
  });

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

    final db = ref.read(localDbServiceProvider);
    String storeName = 'VDN POS';
    if (storeProfile?.storeName.isNotEmpty == true) {
      storeName = storeProfile!.storeName;
    } else {
      final cachedProfileStr = db.settingsBox.get('cached_store_profile');
      if (cachedProfileStr != null && cachedProfileStr.isNotEmpty) {
        try {
          final map = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
          if (map['storeName'] != null && map['storeName'].toString().isNotEmpty) {
            storeName = map['storeName'];
          }
        } catch (_) {}
      }
    }

    return Column(
      children: [
        // App Logo & Store Name Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                  size: 24,
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'VDN POS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 18,
                    color: isPinned ? theme.colorScheme.primary : Colors.grey,
                  ),
                  tooltip: isPinned ? 'Unpin Sidebar (Auto-collapse)' : 'Pin Sidebar Open',
                  onPressed: onTogglePin,
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Menu Navigation List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              if (role == 'Super Admin' || role == 'Admin') ...[
                _SidebarMenuItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/',
                  isSelected: currentRoute == '/',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Cashier',
                  route: '/pos',
                  isSelected: currentRoute == '/pos',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  route: '/sales',
                  isSelected: currentRoute == '/sales',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products & Stock',
                  route: '/products',
                  isSelected: currentRoute == '/products',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchases',
                  route: '/purchases',
                  isSelected: currentRoute == '/purchases',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Accounts & Ledgers',
                  route: '/accounts',
                  isSelected: currentRoute == '/accounts',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.people_rounded,
                  label: 'Salesman Khata',
                  route: '/customer-accounts',
                  isSelected: currentRoute == '/customer-accounts',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.local_shipping_rounded,
                  label: 'Company Khata',
                  route: '/supplier-accounts',
                  isSelected: currentRoute == '/supplier-accounts',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.analytics_rounded,
                  label: 'Reports',
                  route: '/reports',
                  isSelected: currentRoute == '/reports',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.people_alt_rounded,
                  label: 'User Management',
                  route: '/users',
                  isSelected: currentRoute == '/users',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings & Backups',
                  route: '/settings',
                  isSelected: currentRoute == '/settings',
                  isExpanded: isExpanded,
                ),
              ] else if (role == 'Stock Manager') ...[
                _SidebarMenuItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products & Stock',
                  route: '/products',
                  isSelected: currentRoute == '/products',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchases',
                  route: '/purchases',
                  isSelected: currentRoute == '/purchases',
                  isExpanded: isExpanded,
                ),
              ] else if (role == 'Staff') ...[
                _SidebarMenuItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/',
                  isSelected: currentRoute == '/',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Cashier',
                  route: '/pos',
                  isSelected: currentRoute == '/pos',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  route: '/sales',
                  isSelected: currentRoute == '/sales',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products & Stock',
                  route: '/products',
                  isSelected: currentRoute == '/products',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchases',
                  route: '/purchases',
                  isSelected: currentRoute == '/purchases',
                  isExpanded: isExpanded,
                ),
              ] else ...[
                _SidebarMenuItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Cashier',
                  route: '/pos',
                  isSelected: currentRoute == '/pos',
                  isExpanded: isExpanded,
                ),
                _SidebarMenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  route: '/sales',
                  isSelected: currentRoute == '/sales',
                  isExpanded: isExpanded,
                ),
              ],
            ],
          ),
        ),
        // User Profile section
        const Divider(height: 1),
        Container(
          padding: EdgeInsets.all(isExpanded ? 12 : 8),
          child: Row(
            mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        role,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    await ref.read(authControllerProvider.notifier).logout();
                    router.go('/login');
                  },
                  tooltip: 'Logout',
                ),
              ],
            ],
          ),
        ),
        // Developer Footer
        if (isExpanded) ...[
          const Divider(height: 1),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('https://wa.me/923285753463');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              width: double.infinity,
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Developed by Vivid Digital Nexus',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'WhatsApp: +92 328 5753463',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
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
      ],
    );
  }
}

class _SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;
  final bool isExpanded;

  const _SidebarMenuItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final itemWidget = Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.iconTheme.color?.withValues(alpha: 0.7),
            size: 20,
          ),
          if (isExpanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.8,
                        ),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: isExpanded ? '' : label,
        child: InkWell(
          onTap: () {
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.pop(context);
            }
            context.go(route);
          },
          borderRadius: BorderRadius.circular(8),
          child: itemWidget,
        ),
      ),
    );
  }
}
