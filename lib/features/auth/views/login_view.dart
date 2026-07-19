import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../viewmodels/auth_controller.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/deactivation_popup.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int _selectedTabIndex = 0; // 0 = Admin, 1 = Staff

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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

    if (!mounted) return;

    if (success) {
      context.go('/');
      return;
    }

    final authState = ref.read(authControllerProvider);
    if (authState.isDeactivated) {
      await showDeactivationPopup(
        context,
        reason: authState.deactivationReason,
        target: authState.deactivationTarget,
      );
      if (mounted) {
        ref.read(authControllerProvider.notifier).clearDeactivation();
      }
    }
  }

  void _showDeveloperPinDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE8ECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Developer Access',
              style: TextStyle(color: Color(0xFF2D3748), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          style: const TextStyle(color: Color(0xFF4A5568)),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter Secret PIN',
            hintStyle: const TextStyle(color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.amber, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.black38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (pinCtrl.text.trim() == 'vivid123') {
                Navigator.pop(ctx);
                context.push('/developer-dashboard');
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Invalid PIN. Access Denied.'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('ACCESS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final isLarge = size.height > 700;

    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      if (next != null && mounted) {
        context.go('/');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.isDeactivated && mounted) {
        showDeactivationPopup(
          context,
          reason: authState.deactivationReason,
          target: authState.deactivationTarget,
        ).then((_) {
          if (mounted) {
            ref.read(authControllerProvider.notifier).clearDeactivation();
          }
        });
      }
    });

    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false, // Ensures completely clean, non-scrollable layout
      backgroundColor: const Color(0xFFE8ECEF), // Light Claymorphism base color
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24.0 : 16.0,
                  vertical: isLarge ? 32.0 : 16.0,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: isWide ? 420 : size.width - 32,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAppTitle(isLarge),
                            SizedBox(height: isLarge ? 36 : 20),
                            _buildLoginCard(authState, isWide, isLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onLongPress: () => _showDeveloperPinDialog(context),
              child: Opacity(
                opacity: 0.15,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.settings, size: 28, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTitle(bool isLarge) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8ECEF),
            boxShadow: [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: Color(0xFFB0BACC),
                offset: Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Color(0xFF2D3748),
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'General Store',
          style: GoogleFonts.playfairDisplay(
            fontSize: isLarge ? 40 : 32,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2D3748),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'General Store POS',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: isLarge ? 26 : 20,
            fontWeight: FontWeight.w900,
            color: Colors.amber.shade700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Point of Sale Management System',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF718096),
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(AuthState authState, bool isWide, bool isLarge) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 32.0 : 22.0,
        vertical: isLarge ? 36.0 : 24.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-8, -8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Color(0xFFB0BACC),
            offset: Offset(8, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D3748),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to continue',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 28),

            if (authState.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authState.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECEF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Color(0xFFB0BACC),
                    offset: Offset(4, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildTab(0, 'Admin', Icons.shield_rounded),
                  _buildTab(1, 'Staff', Icons.person_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildClayField(
              controller: _usernameController,
              label: _selectedTabIndex == 0 ? 'Admin Email' : 'Username',
              icon: Icons.person_outline_rounded,
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'This field is required'
                  : null,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            _buildClayField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              validator: (val) => (val == null || val.isEmpty)
                  ? 'Password is required'
                  : null,
              action: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF718096),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade400,
                  disabledBackgroundColor: Colors.amber.withOpacity(0.4),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ).copyWith(
                  overlayColor: WidgetStateProperty.all(Colors.white30),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Powered by Vivid Digital Nexus',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFFA0AEC0),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _usernameController.clear();
            _passwordController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amber.shade400 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : const Color(0xFF718096),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : const Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClayField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
    TextInputAction? action,
    ValueChanged<String>? onFieldSubmitted,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Color(0xFFB0BACC),
            offset: Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        textInputAction: action,
        onFieldSubmitted: onFieldSubmitted,
        style: const TextStyle(color: Color(0xFF2D3748), fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF718096), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF718096), size: 20),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
        ),
      ),
    );
  }
}
