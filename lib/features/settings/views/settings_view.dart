import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../auth/viewmodels/auth_controller.dart';
import '../../../data/models/store_profile_model.dart';

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
                      final db = ref.read(localDbServiceProvider);
                      final syncService = SyncService(db);
                      await syncService.syncDirtyRecords();
                      syncService.dispose();
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
                // Backup & Restore manual tabs have been removed as per request
              ],
            ),
          ),
        ],
      ),
    );
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
