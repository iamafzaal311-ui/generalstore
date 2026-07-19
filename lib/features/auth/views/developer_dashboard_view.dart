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
    extends ConsumerState<DeveloperDashboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingStores = true;
  bool _isLoadingUsers = true;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _allUsers = [];

  // Pre-defined deactivation reasons
  static const List<String> _deactivationReasons = [
    'Payment Overdue / Subscription Expired',
    'Trial Period Ended',
    'Policy Violation',
    'System Maintenance',
    'Developer Request',
    'Unauthorized Usage Detected',
    'Account Suspended',
    'Custom Reason...',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadStores();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoadingStores = true);
    final stores =
        await ref.read(authControllerProvider.notifier).fetchAllStores();
    setState(() {
      _stores = stores;
      _isLoadingStores = false;
    });
  }

  Future<void> _loadAllUsers() async {
    setState(() => _isLoadingUsers = true);
    final users =
        await ref.read(authControllerProvider.notifier).fetchAllStoreUsers();
    setState(() {
      _allUsers = users;
      _isLoadingUsers = false;
    });
  }

  void _showCreateUserDialog() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'Admin';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Generate User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(labelText: 'Username'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Initial Password'),
                        validator: (val) => val == null || val.length < 4 ? 'Min 4 characters' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: ['Staff', 'Cashier', 'Stock Manager', 'Admin']
                            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => selectedRole = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await ref.read(authControllerProvider.notifier).createUser(
                          username: usernameCtrl.text.trim(),
                          fullName: fullNameCtrl.text.trim(),
                          password: passwordCtrl.text,
                          role: selectedRole,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User created successfully')),
                          );
                          _loadAllUsers();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a reason picker dialog. Returns the selected/entered reason or null if cancelled.
  Future<String?> _showReasonDialog({required bool isDeactivating}) async {
    if (!isDeactivating) return ''; // Reactivating doesn't need a reason

    String selectedReason = _deactivationReasons[0];
    final customCtrl = TextEditingController();
    bool isCustom = false;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Select Deactivation Reason', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a reason for deactivation:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...(_deactivationReasons.map((reason) {
                  final isCustomOption = reason == 'Custom Reason...';
                  return RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          selectedReason = val;
                          isCustom = isCustomOption;
                        });
                      }
                    },
                  );
                })),
                if (isCustom) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCtrl,
                    maxLines: 2,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Enter custom reason',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final reason = isCustom ? customCtrl.text.trim() : selectedReason;
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, reason);
              },
              child: const Text('Confirm Deactivation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStoreStatus(String uid, bool currentStatus) async {
    final reason = await _showReasonDialog(isDeactivating: currentStatus);
    if (reason == null) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .toggleStoreStatus(uid, currentStatus, reason: reason);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (currentStatus ? '🔴 Store deactivated successfully' : '✅ Store activated successfully')
              : '❌ Failed to update store status',
        ),
        backgroundColor: success ? (currentStatus ? Colors.red : Colors.green) : Colors.red,
      ),
    );
    if (success) _loadStores();
  }

  Future<void> _toggleUserFromDashboard(String storeUid, String userUid, bool isAdmin, bool currentStatus) async {
    if (isAdmin) {
      // Deactivating an admin implies deactivating their entire store
      await _toggleStoreStatus(storeUid, currentStatus);
      await _loadAllUsers();
    } else {
      // Deactivating a staff user
      final reason = await _showReasonDialog(isDeactivating: currentStatus);
      if (reason == null) return;

      await ref.read(authControllerProvider.notifier).toggleUserStatus(userUid, currentStatus, reason: reason);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus ? '🔴 User deactivated successfully' : '✅ User activated successfully',
          ),
          backgroundColor: currentStatus ? Colors.red : Colors.green,
        ),
      );
      await _loadAllUsers();
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
          'This will permanently DELETE all products, categories, brands, '
          'suppliers, customers, sales, purchases and expenses from BOTH '
          'local storage and Firebase.\n\nThis action CANNOT be undone!\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, DELETE EVERYTHING'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.clearAllBusinessData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ All business data wiped successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error wiping data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteStore(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Store?'),
          ],
        ),
        content: const Text('Are you sure you want to permanently delete this store and all its users? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(authControllerProvider.notifier).deleteStore(uid);
      if (success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store deleted successfully.')));
        _loadStores();
        _loadAllUsers();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete store.')));
      }
    }
  }

  Future<void> _editStore(Map<String, dynamic> storeData) async {
    final uid = storeData['uid'] as String;
    final nameCtrl = TextEditingController(text: storeData['storeName'] ?? '');
    final phoneCtrl = TextEditingController(text: storeData['phone'] ?? '');
    final taglineCtrl = TextEditingController(text: storeData['tagline'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Store'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Store Name')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Proprietor/Tagline')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final updates = {
        'storeName': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'tagline': taglineCtrl.text.trim(),
      };
      final success = await ref.read(authControllerProvider.notifier).updateStore(uid, updates);
      if (success) {
        _loadStores();
        _loadAllUsers();
      }
    }
  }

  Future<void> _deleteUser(String storeUid, String userUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User?'),
          ],
        ),
        content: const Text('Are you sure you want to permanently delete this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(authControllerProvider.notifier).deleteStoreUser(storeUid, userUid);
      if (success) {
        _loadAllUsers();
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> userData) async {
    final storeUid = userData['storeUid'] as String;
    final userUid = userData['uid'] as String;
    final nameCtrl = TextEditingController(text: userData['fullName'] ?? '');
    final usernameCtrl = TextEditingController(text: userData['username'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 8),
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final updates = {
        'fullName': nameCtrl.text.trim(),
        'username': usernameCtrl.text.trim(),
      };
      final success = await ref.read(authControllerProvider.notifier).updateStoreUser(storeUid, userUid, updates);
      if (success) {
        _loadAllUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.developer_mode_rounded, size: 22),
            SizedBox(width: 8),
            Text('Developer Control Panel'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: 'All Stores'),
            Tab(icon: Icon(Icons.people_rounded), text: 'All Users'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              _loadStores();
              _loadAllUsers();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            tooltip: 'Wipe All Data (Danger)',
            onPressed: _wipeAllData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StoresTab(
            isLoading: _isLoadingStores,
            stores: _stores,
            onToggle: _toggleStoreStatus,
            onEdit: _editStore,
            onDelete: _deleteStore,
            theme: theme,
          ),
          _UsersTab(
            isLoading: _isLoadingUsers,
            users: _allUsers,
            theme: theme,
            onRefresh: _loadAllUsers,
            onToggle: _toggleUserFromDashboard,
            onEdit: _editUser,
            onDelete: _deleteUser,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateUserDialog,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Generate User'),
            )
          : FloatingActionButton.extended(
              onPressed: () => context.push('/register-store'),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Register New Store'),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Stores Tab
// ─────────────────────────────────────────────────────────
class _StoresTab extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> stores;
  final Future<void> Function(String uid, bool currentStatus) onToggle;
  final void Function(Map<String, dynamic> storeData) onEdit;
  final void Function(String uid) onDelete;
  final ThemeData theme;

  const _StoresTab({
    required this.isLoading,
    required this.stores,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stores.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No stores registered yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final storeData = stores[index];
        final profile = StoreProfileModel.fromMap(storeData);
        final uid = storeData['uid'] as String? ?? '';
        final email = storeData['email'] as String? ?? 'Unknown Email';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: profile.isActive ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: profile.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: profile.isActive ? Colors.green : Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.storeName.isNotEmpty ? profile.storeName : '(No Store Name)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          if (profile.phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('📞 ${profile.phone}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                          if (profile.tagline.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('👤 ${profile.tagline}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    // Status + Toggle
                    Column(
                      children: [
                        Switch(
                          value: profile.isActive,
                          onChanged: (val) => onToggle(uid, profile.isActive),
                          activeTrackColor: Colors.green.withValues(alpha: 0.4),
                          activeThumbColor: Colors.green,
                          inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.red,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: profile.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              color: profile.isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                              onPressed: () => onEdit(storeData),
                              tooltip: 'Edit Store',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                              onPressed: () => onDelete(uid),
                              tooltip: 'Delete Store',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                // Deactivation reason (if inactive)
                if (!profile.isActive && profile.deactivationReason != null && profile.deactivationReason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deactivation Reason:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red),
                              ),
                              Text(profile.deactivationReason!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Text('UID: $uid', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontFamily: 'monospace')),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Users Tab — Shows ALL users: store admins + staff
// ─────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> users;
  final ThemeData theme;
  final VoidCallback onRefresh;
  final Future<void> Function(String storeUid, String userUid, bool isAdmin, bool currentStatus) onToggle;
  final void Function(Map<String, dynamic> userData) onEdit;
  final void Function(String storeUid, String userUid) onDelete;

  const _UsersTab({
    required this.isLoading,
    required this.users,
    required this.theme,
    required this.onRefresh,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No users found across any store.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final totalAdmins = users.where((u) => u['isAdmin'] == true).length;
    final totalStaff = users.where((u) => u['isAdmin'] != true).length;
    final totalInactive = users.where((u) => !(u['isActive'] as bool? ?? true)).length;

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatChip(icon: Icons.people_rounded, label: '${users.length} Total', color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.shield_rounded, label: '$totalAdmins Admins', color: Colors.purple),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.person_rounded, label: '$totalStaff Staff', color: Colors.blue),
                if (totalInactive > 0) ...[
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.block_rounded, label: '$totalInactive Blocked', color: Colors.red),
                ],
              ],
            ),
          ),
        ),

        // Users list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final u = users[index];
              final fullName = (u['fullName'] as String?) ?? '-';
              final username = (u['username'] as String?) ?? '-';
              final role = (u['role'] as String?) ?? '-';
              final isActive = (u['isActive'] as bool?) ?? true;
              final storeName = (u['storeName'] as String?) ?? 'Unknown Store';
              final reason = (u['deactivationReason'] as String?) ?? '';
              final isAdmin = (u['isAdmin'] as bool?) ?? false;
              final storeUid = (u['storeUid'] as String?) ?? '';
              final uid = (u['uid'] as String?) ?? '';

              final initials = fullName.trim().isNotEmpty
                  ? fullName.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
                  : '?';

              final roleColor = isAdmin ? Colors.purple : Colors.blue.shade700;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: isActive ? 2 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isActive
                        ? (isAdmin ? Colors.purple.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.2))
                        : Colors.red.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with admin badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isActive
                                ? (isAdmin ? Colors.purple.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.1))
                                : Colors.red.withValues(alpha: 0.08),
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: isActive ? (isAdmin ? Colors.purple : Colors.blue.shade700) : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            Positioned(
                              bottom: -2,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.shield_rounded, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isAdmin ? '📧 $username' : '👤 @$username',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.storefront_rounded, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    storeName,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (!isActive && reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  '🚫 $reason',
                                  style: const TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Status pill & Toggle
                      Column(
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (val) => onToggle(storeUid, uid, isAdmin, isActive),
                            activeTrackColor: Colors.green.withValues(alpha: 0.4),
                            activeThumbColor: Colors.green,
                            inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                            inactiveThumbColor: Colors.red,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive ? Colors.green.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'BLOCKED',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                onPressed: () => onEdit(u),
                                tooltip: 'Edit User',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                onPressed: () => onDelete(storeUid, uid),
                                tooltip: 'Delete User',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Stat Chip helper
// ─────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
