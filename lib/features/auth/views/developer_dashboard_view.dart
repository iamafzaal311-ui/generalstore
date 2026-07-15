import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/auth_controller.dart';
import '../../../data/models/store_profile_model.dart';

class DeveloperDashboardView extends ConsumerStatefulWidget {
  const DeveloperDashboardView({super.key});

  @override
  ConsumerState<DeveloperDashboardView> createState() => _DeveloperDashboardViewState();
}

class _DeveloperDashboardViewState extends ConsumerState<DeveloperDashboardView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final stores = await ref.read(authControllerProvider.notifier).fetchAllStores();
    setState(() {
      _stores = stores;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus(String uid, bool currentStatus) async {
    final success = await ref.read(authControllerProvider.notifier).toggleStoreStatus(uid, currentStatus);
    if (success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store status updated successfully')));
      _loadStores();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update store status')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStores,
          )
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(profile.storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Email: $email', style: const TextStyle(color: Colors.grey)),
                            if (profile.phone.isNotEmpty) Text('Phone: ${profile.phone}', style: const TextStyle(color: Colors.grey)),
                            if (profile.tagline.isNotEmpty) Text('Proprietor: ${profile.tagline}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: profile.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                profile.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  color: profile.isActive ? Colors.green : Colors.red,
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
                          activeColor: Colors.green,
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
