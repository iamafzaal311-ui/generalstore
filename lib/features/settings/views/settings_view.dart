import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/sync_service.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings & Backups'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(
            'Data Safety & Synchronization',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.cloud_upload_rounded)),
                  title: const Text('Force Cloud Synchronization'),
                  subtitle: const Text('Trigger immediate manual sync of local modifications to Firestore.'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final db = ref.read(localDbServiceProvider);
                      final syncService = SyncService(db);
                      await syncService.syncDirtyRecords();
                      syncService.dispose();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Manual cloud sync completed successfully!')),
                        );
                      }
                    },
                    child: const Text('Sync Now'),
                  ),
                ),
                // Backup & Restore manual tabs have been removed as per request
              ],
            ),
          ),
        ],
      ),
    );
  }
}
