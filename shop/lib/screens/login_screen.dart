import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/hero_visual.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// Email + password sign-in for a *returning* shop — see
/// `ShopRepository.logIn`'s doc for why this is the one place in the app
/// that uses real Supabase email/password auth instead of anonymous
/// sign-in, and why the account has to be created via the Supabase
/// dashboard rather than a sign-up form here.
///
/// Callback-driven, not self-navigating — see `LoginOrRegisterScreen`'s
/// class doc for why. A successful login that finds an existing shop needs
/// no callback at all: `logIn` sets the repository's profile, and
/// `main.dart`'s reactive builder swaps away from this screen on its own.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.repository,
    required this.onRegisterInstead,
    super.key,
  });

  final ShopRepository repository;
  final VoidCallback onRegisterInstead;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSubmitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final foundShop = await widget.repository.logIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      if (!foundShop) {
        // A real, signed-in account, just nothing registered under it
        // yet — hand off to registration, which attaches the new shop to
        // this same identity rather than starting a fresh anonymous one.
        widget.onRegisterInstead();
      }
      // If a shop *was* found, `logIn` already set the repository's
      // profile — main.dart's reactive builder swaps away from this
      // screen on its own, nothing further to do here.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: colors.textSecondary),
      filled: true,
      fillColor: colors.surfaceSunken,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.actionPrimaryBg, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.critical.fg),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.critical.fg, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop = context.isDesktopWidth;

    final content = Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log in', style: context.type.display),
            const SizedBox(height: Space.x2),
            Text(
              'Sign in to your shop account.',
              style: context.type.bodyLarge.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: Space.x8),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                context,
                'Email',
                Icons.mail_outline,
              ),
              validator: _required,
            ),
            const SizedBox(height: Space.x4),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration:
                  _fieldDecoration(
                    context,
                    'Password',
                    Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
              validator: _required,
            ),
            const SizedBox(height: Space.x8),
            AppButton(
              label: 'Log in',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: Space.x4),
            Center(
              child: TextButton(
                onPressed: _isSubmitting ? null : widget.onRegisterInstead,
                child: const Text("Don't have an account? Register instead"),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: colors.surfaceBase,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 220,
                  child: HeroVisual(
                    icon: Icons.storefront_rounded,
                    title: 'Welcome back',
                    subtitle: 'Sign in to keep managing your shop.',
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Breakpoints.formMaxWidth,
                    ),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: SafeArea(
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.formMaxWidth,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
          const Expanded(
            flex: 9,
            child: HeroVisual(
              icon: Icons.storefront_rounded,
              title: 'Welcome back',
              subtitle: 'Sign in to keep managing your shop.',
            ),
          ),
        ],
      ),
    );
  }
}
