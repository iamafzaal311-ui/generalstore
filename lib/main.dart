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

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize local Hive database first (always works offline)
    final dbService = LocalDbService();
    await dbService.init();

    // 2. Try to initialize Firebase
    SyncService? syncService;
    bool firebaseReady = false;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;

      // Custom Firestore settings removed due to Web SDK long polling timeout bug

      syncService = SyncService(dbService);
    } catch (e) {
      debugPrint('Firebase init error: $e');
      // Try dummy init so FirebaseAuth/Firestore references don't crash offline
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

    final finalSyncService = syncService;

    // 3. Launch UI immediately — user sees app at once, no network waiting
    runApp(
      ProviderScope(
        overrides: [
          localDbServiceProvider.overrideWithValue(dbService),
          syncServiceProvider.overrideWithValue(finalSyncService),
        ],
        child: const MyApp(),
      ),
    );

    // 4. Sync with cloud in background AFTER UI is visible
    //    When a new device logs in with the same account, this restores all data
    if (firebaseReady) {
      Future.microtask(() async {
        try {
          // Wait for auth state (up to 5s), then sync
          await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 5));

          // Pull latest data from Firebase → local Hive
          await finalSyncService.restoreAllFromCloud();
          // Push any locally-changed records → Firebase
          await finalSyncService.syncDirtyRecords();
        } catch (e) {
          debugPrint('Background sync skipped: $e');
        }
      });
    }
  } catch (e, stackTrace) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Startup Error:\n$e\n\n$stackTrace',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
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
        final data = MediaQuery.of(context);
        // Globally scale down text and text-dependent widget sizes by 15%
        return MediaQuery(
          data: data.copyWith(
            textScaler: const TextScaler.linear(0.85),
          ),
          child: child!,
        );
      },
    );
  }
}
