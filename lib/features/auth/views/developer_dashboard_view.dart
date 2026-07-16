import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/auth_controller.dart';
import '../../../data/models/store_profile_model.dart';
import '../../../core/providers/global_providers.dart';

class DeveloperDashboardView extends ConsumerStatefulWidget {
  const DeveloperDashboardView({super.key});

  @override
  ConsumerState<DeveloperDashboardView> createState() =>
      _DeveloperDashboardViewState();
}

class _DeveloperDashboardViewState
    extends ConsumerState<DeveloperDashboardView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final stores = await ref
        .read(authControllerProvider.notifier)
        .fetchAllStores();
    setState(() {
      _stores = stores;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus(String uid, bool currentStatus) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .toggleStoreStatus(uid, currentStatus);
    if (success) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store status updated successfully')),
        );
      _loadStores();
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update store status')),
        );
    }
  }

  Future<void> _wipeAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Wipe All Data?', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'This will permanently DELETE all products, categories, brands, suppliers, customers, sales, purchases and expenses from BOTH local storage and Firebase.\n\nThis action CANNOT be undone!\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, DELETE EVERYTHING'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.clearAllBusinessData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All business data wiped successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error wiping data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStores),
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            tooltip: 'Wipe All Data (Danger)',
            onPressed: _wipeAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
          ? const Center(child: Text('No stores registered yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stores.length,
              itemBuilder: (context, index) {
                final storeData = _stores[index];
                final profile = StoreProfileModel.fromMap(storeData);
                final uid = storeData['uid'] as String? ?? '';
                final email = storeData['email'] as String? ?? 'Unknown Email';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      profile.storeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Email: $email',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (profile.phone.isNotEmpty)
                          Text(
                            'Phone: ${profile.phone}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        if (profile.tagline.isNotEmpty)
                          Text(
                            'Proprietor: ${profile.tagline}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: profile.isActive
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            profile.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              color: profile.isActive
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Switch(
                      value: profile.isActive,
                      onChanged: (val) => _toggleStatus(uid, profile.isActive),
                      activeTrackColor: Colors.green.withValues(alpha: 0.5),
                      activeThumbColor: Colors.green,
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/register-store'),
        icon: const Icon(Icons.add),
        label: const Text('New Store'),
      ),
    );
  }
}
