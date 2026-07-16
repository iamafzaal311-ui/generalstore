import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/auth_controller.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/custom_urdu_header.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController(); // For Sign Up
  bool _obscurePassword = true;
  int _selectedTabIndex = 0; // 0 = Admin, 1 = Staff

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      bool success = false;
      if (_selectedTabIndex == 0) {
        success = await ref
            .read(authControllerProvider.notifier)
            .adminLogin(
              _usernameController.text.trim(),
              _passwordController.text,
            );
      } else {
        success = await ref
            .read(authControllerProvider.notifier)
            .login(_usernameController.text.trim(), _passwordController.text);
      }

      if (success && mounted) {
        context.go('/');
      }
    }
  }

  void _showDeveloperPinDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Developer Access'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter Secret PIN'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.trim() == 'vivid123') {
                Navigator.pop(ctx);
                context.push('/developer-dashboard');
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN. Access Denied.')),
                );
              }
            },
            child: const Text('Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    // Auto-redirect if already logged in
    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      if (next != null) {
        context.go('/');
      }
    });

    // Handle initial state if already logged in
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.secondary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 600
                              ? 24.0
                              : 16.0,
                          vertical: MediaQuery.of(context).size.height > 700
                              ? 24.0
                              : 12.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Custom Urdu Header at the top
                            const CustomUrduHeader(),
                            SizedBox(
                              height: MediaQuery.of(context).size.height > 700
                                  ? 24
                                  : 12,
                            ),

                            // Login Form Card
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 420),
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width > 600
                                    ? 32.0
                                    : 20.0,
                                vertical:
                                    MediaQuery.of(context).size.height > 700
                                    ? 40.0
                                    : 24.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 32,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // App Icon / Logo Placeholder
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height >
                                              700
                                          ? 80
                                          : 60,
                                      width:
                                          MediaQuery.of(context).size.height >
                                              700
                                          ? 80
                                          : 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.08),
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.15),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.storefront_rounded,
                                          color: theme.colorScheme.primary,
                                          size:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.height >
                                                  700
                                              ? 40
                                              : 30,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height >
                                              700
                                          ? 24
                                          : 12,
                                    ),
                                    Text(
                                      'Welcome Back',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Enter your credentials to access your account.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                    const SizedBox(height: 32),

                                    if (authState.errorMessage != null)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          authState.errorMessage!,
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),

                                    SegmentedButton<int>(
                                      segments: const [
                                        ButtonSegment(
                                          value: 0,
                                          label: Text('Admin'),
                                          icon: Icon(Icons.shield),
                                        ),
                                        ButtonSegment(
                                          value: 1,
                                          label: Text('Staff'),
                                          icon: Icon(Icons.person),
                                        ),
                                      ],
                                      selected: {_selectedTabIndex},
                                      onSelectionChanged:
                                          (Set<int> newSelection) {
                                            setState(() {
                                              _selectedTabIndex =
                                                  newSelection.first;
                                              _usernameController.clear();
                                              _passwordController.clear();
                                            });
                                          },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        labelText: _selectedTabIndex == 0
                                            ? 'Admin Email'
                                            : 'Username',
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Username is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.6),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      onFieldSubmitted: (_) => _submit(),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Password is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: authState.isLoading
                                          ? null
                                          : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 4,
                                        shadowColor: theme.colorScheme.primary
                                            .withValues(alpha: 0.4),
                                      ),
                                      child: authState.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onLongPress: () {
                  _showDeveloperPinDialog(context);
                },
                child: const Opacity(
                  opacity: 0.1,
                  child: Icon(Icons.security, size: 32),
                ),
              ),
            ),
          ], // ends Stack children
        ), // ends Stack
      ), // ends Container
    ); // ends Scaffold
  }
}
