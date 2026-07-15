import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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
    await SeedDataService.seedIfEmpty(dbService);

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final syncService = SyncService(dbService);
      await syncService.restoreAllFromCloud();
      await syncService.syncDirtyRecords();
    } catch (e) {
      debugPrint('Firebase init error: $e');
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
