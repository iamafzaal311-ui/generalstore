import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/global_providers.dart';
import 'data/datasources/local_db_service.dart';
import 'core/services/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrapper());
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _isReady = false;
  String? _initError;
  LocalDbService? _dbService;
  SyncService? _syncService;

  @override
  void initState() {
    super.initState();
    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    try {
      // 1. Initialize local Hive DB
      final dbService = LocalDbService();
      await dbService.init();
      _dbService = dbService;

      // 2. Initialize Firebase
      SyncService? syncService;
      bool firebaseReady = false;

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;
        syncService = SyncService(dbService);
      } catch (e) {
        debugPrint('Firebase init error: $e');
        try {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'dummy_api_key',
              appId: '1:123456789:android:123456789',
              messagingSenderId: 'dummy_sender_id',
              projectId: 'dummy_project_id',
            ),
          );
        } catch (_) {}
        syncService = SyncService(dbService);
      }

      _syncService = syncService;

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }

      // Background cloud sync
      if (firebaseReady) {
        final activeSyncService = syncService;
        Future.microtask(() async {
          try {
            await FirebaseAuth.instance
                .authStateChanges()
                .first
                .timeout(const Duration(seconds: 5));
            await activeSyncService.restoreAllFromCloud();
            await activeSyncService.syncDirtyRecords();
          } catch (e) {
            debugPrint('Background sync skipped: $e');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Initialization Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_initError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                        _bootstrapApp();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isReady || _dbService == null || _syncService == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vivid Digital Nexus',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Inventory & POS System',
                  style: TextStyle(color: Color(0xFF93C5FD), fontSize: 13),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        localDbServiceProvider.overrideWithValue(_dbService!),
        syncServiceProvider.overrideWithValue(_syncService!),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Application View Error',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => goRouter.go('/'),
                      icon: const Icon(Icons.dashboard_rounded),
                      label: const Text('Go to Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: const TextScaler.linear(0.85),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
