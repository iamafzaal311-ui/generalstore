import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../auth/viewmodels/auth_controller.dart';
import '../../../data/models/store_profile_model.dart';
import '../../products/viewmodels/inventory_controller.dart';
import '../../accounts/viewmodels/accounts_controller.dart';
import '../../transactions/viewmodels/transactions_controller.dart';

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
      appBar: AppBar(title: const Text('System Settings & Backups')),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildUserProfileSection(context, theme),
          _buildStoreProfileSection(context, theme),
          const SizedBox(height: 32),
          Text(
            'Data Safety & Synchronization',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.cloud_upload_rounded),
                  ),
                  title: const Text('Force Cloud Synchronization'),
                  subtitle: const Text(
                    'Trigger immediate manual sync of local modifications to Firestore.',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.syncDirtyRecords();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Manual cloud sync completed successfully!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Sync Now'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.cloud_download_rounded, color: Colors.white),
                  ),
                  title: const Text('Restore Cloud Backup'),
                  subtitle: const Text(
                    'Pull all products, ledgers, and transactions fresh from your Cloud Firestore backup.',
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final syncService = ref.read(syncServiceProvider);
                      await syncService.restoreAllFromCloud();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '☁️ Store backup successfully restored from Cloud Firestore!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text('Restore Backup'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildDangerZoneSection(context, theme),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Local Storage & Cloud Backup',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.shade50,
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade800,
                    child: const Icon(Icons.cleaning_services_rounded, color: Colors.white),
                  ),
                  title: Text(
                    'Clear Local Device Memory',
                    style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Removes all local cached data from this device ONLY. Cloud Firestore data is 100% PRESERVED.'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _confirmWipeData(context),
                    child: const Text('Clear Memory'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: const Icon(Icons.cloud_download_rounded, color: Colors.white),
                  ),
                  title: Text(
                    'Restore Data from Cloud',
                    style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Downloads all store records, products, sales, and accounts from Cloud Firestore.'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _restoreFromCloud(context),
                    child: const Text('Restore Cloud'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipeData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text('Clear Local Device Memory?'),
          ],
        ),
        content: const Text(
          'This will remove all local data from this device ONLY.\n\n'
          '🔒 Your Cloud Firestore data is 100% SAFE and will NOT be deleted or touched!\n\n'
          'You can tap "Restore Cloud" anytime to download your data back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Local Memory'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.clearLocalMemorySafely();

      // Refresh local UI states
      try {
        await ref.read(inventoryControllerProvider.notifier).refreshAll();
        await ref.read(accountsControllerProvider.notifier).refreshAccounts();
        await ref.read(transactionsControllerProvider.notifier).refreshPurchases();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Local device memory cleared! Cloud Firestore remains 100% safe.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing memory: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreFromCloud(BuildContext context) async {
    try {
      final syncService = ref.read(syncServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Restoring all store data from Cloud Firestore...'),
          duration: Duration(seconds: 3),
        ),
      );
      await syncService.restoreAllFromCloud();

      // Refresh local UI states
      try {
        await ref.read(inventoryControllerProvider.notifier).refreshAll();
        await ref.read(accountsControllerProvider.notifier).refreshAccounts();
        await ref.read(transactionsControllerProvider.notifier).refreshPurchases();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Store data restored successfully from Cloud Firestore!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildUserProfileSection(BuildContext context, ThemeData theme) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Profile & Account',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                title: const Text('Full Name / Display Name'),
                subtitle: Text(currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Not set'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editUserProfileName(context, currentUser.fullName),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_circle_rounded)),
                title: const Text('Username'),
                subtitle: Text(currentUser.username),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.badge_rounded)),
                title: const Text('Role'),
                subtitle: Text(currentUser.role),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _editUserProfileName(BuildContext context, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Full Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && ctrl.text.trim().isNotEmpty && ctrl.text.trim() != currentName) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        await ref.read(authControllerProvider.notifier).updateUser(currentUser.userId, {
          'fullName': ctrl.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name updated successfully!')),
          );
        }
      }
    }
  }

  Widget _buildStoreProfileSection(BuildContext context, ThemeData theme) {
    final profile = ref.watch(storeProfileProvider) ?? StoreProfileModel(storeName: 'General Store');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Profile & Theme',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.storefront_rounded)),
                title: const Text('Store Name'),
                subtitle: Text(profile.storeName),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStoreProfileField('storeName', profile.storeName),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.tag_faces_rounded)),
                title: const Text('Proprietor / Tagline'),
                subtitle: Text(profile.tagline.isNotEmpty ? profile.tagline : 'Not set'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStoreProfileField('tagline', profile.tagline),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.phone_rounded)),
                title: const Text('Phone Number'),
                subtitle: Text(profile.phone.isNotEmpty ? profile.phone : 'Not set'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStoreProfileField('phone', profile.phone),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.location_on_rounded)),
                title: const Text('Address (Bottom Bar)'),
                subtitle: Text(profile.address.isNotEmpty ? profile.address : 'Not set'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStoreProfileField('address', profile.address),
                ),
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _hexToColor(profile.headerColor) ?? Colors.blue.shade800,
                  child: const Icon(Icons.format_paint_rounded, color: Colors.white),
                ),
                title: const Text('Header Background Color'),
                subtitle: const Text('Select the main color for the store header.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showColorPicker('headerColor', profile.headerColor),
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _hexToColor(profile.headerTextColor) ?? Colors.red.shade700,
                  child: const Icon(Icons.text_format_rounded, color: Colors.white),
                ),
                title: const Text('Header Text Color'),
                subtitle: const Text('Select the color for the store name text.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showColorPicker('headerTextColor', profile.headerTextColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editStoreProfileField(String field, String currentValue) async {
    final ctrl = TextEditingController(text: currentValue);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${field.toUpperCase()}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && ctrl.text != currentValue) {
      await ref.read(authControllerProvider.notifier).updateCurrentStoreProfile({field: ctrl.text.trim()});
    }
  }

  Future<void> _showColorPicker(String field, String? currentHex) async {
    final List<Color> colors = [
      Colors.blue.shade800,
      Colors.red.shade700,
      Colors.green.shade800,
      Colors.orange.shade800,
      Colors.purple.shade800,
      Colors.teal.shade800,
      Colors.brown.shade800,
      Colors.grey.shade900,
      Colors.black,
      Colors.white,
    ];

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((c) {
            return InkWell(
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (result != null) {
      final hex = '#${result.toARGB32().toRadixString(16).padLeft(8, '0')}';
      await ref.read(authControllerProvider.notifier).updateCurrentStoreProfile({field: hex});
    }
  }

  Color? _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final hex = hexString.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }
}
