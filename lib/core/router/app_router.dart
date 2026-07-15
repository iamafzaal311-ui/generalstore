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
import '../../features/reports/views/reports_view.dart';
import '../../features/sales/views/sales_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../widgets/main_layout.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginView(),
    ),
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
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardView(),
        ),
        GoRoute(
          path: '/pos',
          builder: (context, state) => const POSView(),
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsView(),
        ),
        GoRoute(
          path: '/purchases',
          builder: (context, state) => const PurchasesView(),
        ),
        GoRoute(
          path: '/sales',
          builder: (context, state) => const SalesView(),
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsView(),
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
