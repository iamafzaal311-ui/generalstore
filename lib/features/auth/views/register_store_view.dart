import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/auth_controller.dart';
import '../../../data/models/store_profile_model.dart';

class RegisterStoreView extends ConsumerStatefulWidget {
  const RegisterStoreView({super.key});

  @override
  ConsumerState<RegisterStoreView> createState() => _RegisterStoreViewState();
}

class _RegisterStoreViewState extends ConsumerState<RegisterStoreView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _proprietorCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _storeNameCtrl.dispose();
    _proprietorCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final profile = StoreProfileModel(
        storeName: _storeNameCtrl.text.trim(),
        tagline: _proprietorCtrl.text.trim(), // We use tagline for Proprietor
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );

      final success = await ref.read(authControllerProvider.notifier).registerStore(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        profile,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store registered successfully! You can now log in as Admin.')),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Store (Dev)'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 64, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text('Create Store Profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),

                      if (state.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 16),
                          color: Colors.red.shade100,
                          child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Admin Email', prefixIcon: Icon(Icons.email)),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty || !v.contains('@') ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Admin Password', prefixIcon: Icon(Icons.lock)),
                        obscureText: true,
                        validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const Divider(height: 32),
                      
                      TextFormField(
                        controller: _storeNameCtrl,
                        decoration: const InputDecoration(labelText: 'Store Name', prefixIcon: Icon(Icons.store)),
                        validator: (v) => v!.isEmpty ? 'Enter store name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _proprietorCtrl,
                        decoration: const InputDecoration(labelText: 'Proprietor Name', prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Store Address', prefixIcon: Icon(Icons.location_on)),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: state.isLoading ? null : _submit,
                          child: state.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Register Store', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
