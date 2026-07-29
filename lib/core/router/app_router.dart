import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_store_view.dart';
import '../../features/auth/views/user_management_view.dart';
import '../../features/auth/views/developer_dashboard_view.dart';
import '../../features/dashboard/views/dashboard_view.dart';
import '../../features/pos/views/pos_view.dart';
import '../../features/products/views/products_view.dart';
import '../../features/transactions/views/purchases_view.dart';
import '../../features/accounts/views/accounts_view.dart';
import '../../features/accounts/views/customer_accounts_view.dart';
import '../../features/accounts/views/supplier_accounts_view.dart';
import '../../features/accounts/views/expense_view.dart';
import '../../features/reports/views/reports_view.dart';
import '../../features/sales/views/sales_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../data/datasources/local_db_service.dart';
import '../widgets/main_layout.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

bool _isInitialStart = true;

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final db = LocalDbService();
    if (!db.isInitialized) {
      return null;
    }

    try {
      final path = state.uri.path;
      if (path == '/developer-dashboard') {
        _isInitialStart = false;
        return null;
      }

      final lastUserId = db.settingsBox.get('last_logged_in_user_id');
      final isLoggedIn = lastUserId != null && db.usersBox.get(lastUserId) != null;

      // Force initial launch/refresh to start on /login
      if (_isInitialStart) {
        _isInitialStart = false;
        return '/login';
      }

      if (!isLoggedIn && path != '/login' && path != '/register-store') {
        return '/login';
      }
    } catch (_) {}

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginView()),
    GoRoute(
      path: '/register-store',
      builder: (context, state) => const RegisterStoreView(),
    ),
    GoRoute(
      path: '/developer-dashboard',
      builder: (context, state) => const DeveloperDashboardView(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardView()),
        GoRoute(path: '/pos', builder: (context, state) => const POSView()),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsView(),
        ),
        GoRoute(
          path: '/purchases',
          builder: (context, state) => const PurchasesView(),
        ),
        GoRoute(path: '/sales', builder: (context, state) => const SalesView()),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsView(),
        ),
        GoRoute(
          path: '/expenses',
          builder: (context, state) => const ExpenseView(),
        ),
        GoRoute(
          path: '/customer-accounts',
          builder: (context, state) => const CustomerAccountsView(),
        ),
        GoRoute(
          path: '/supplier-accounts',
          builder: (context, state) => const SupplierAccountsView(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsView(),
        ),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UserManagementView(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsView(),
        ),
      ],
    ),
  ],
);
