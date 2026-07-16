import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added missing import
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/global_providers.dart';
import 'data/datasources/local_db_service.dart';
import 'core/services/seed_data_service.dart';
import 'core/services/sync_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final dbService = LocalDbService();
    await dbService.init();

    // await SeedDataService.seedIfEmpty(dbService); // Disabled for client delivery

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final syncService = SyncService(dbService);
      
      // Wait a moment for auth state to resolve so we have the user UID to delete Firestore data
      try {
        await FirebaseAuth.instance.authStateChanges().first;
      } catch (_) {}
      
      // One-time wipe for fresh client handover (includes Cloud & Local)
      if (dbService.settingsBox.get('handover_wiped_v6') != 'true') {
        // Wait until we actually have the user UID from FirebaseAuth, with timeout
        try {
          await FirebaseAuth.instance.authStateChanges().firstWhere((user) => user != null).timeout(const Duration(seconds: 3));
        } catch (_) {} // If it times out or errors, it means they might not be logged in yet.
        await syncService.clearAllBusinessData();
        await dbService.settingsBox.put('handover_wiped_v6', 'true');
      } else {
        await syncService.restoreAllFromCloud();
        await syncService.syncDirtyRecords();
      }
    } catch (e) {
      debugPrint('Firebase init error: $e');
      // Initialize with dummy options to prevent [core/no-app] crashes
      // when accessing FirebaseAuth.instance or FirebaseFirestore.instance offline
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'dummy_api_key',
            appId: '1:123456789:android:123456789',
            messagingSenderId: 'dummy_sender_id',
            projectId: 'dummy_project_id',
          ),
        );
      } catch (dummyError) {
        debugPrint('Dummy Firebase init error: $dummyError');
      }
    }

    runApp(
      ProviderScope(
        overrides: [
          localDbServiceProvider.overrideWithValue(dbService),
          syncServiceProvider.overrideWithValue(SyncService(dbService)),
        ],
        child: const MyApp(),
      ),
    );
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
    );
  }
}
