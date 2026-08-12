import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/elevation.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';

/// Shop signup — business details, FSSAI licence, address, and payout
/// bank details. Submitting moves the shop to [ShopApprovalStatus
/// .pendingReview]; nothing past this screen is reachable until a review
/// clears it (see `PendingApprovalScreen`).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _addressLine = TextEditingController();
  final _locality = TextEditingController();
  final _fssaiNumber = TextEditingController();
  final _accountHolderName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifscCode = TextEditingController();
  final _upiId = TextEditingController();

  ShopCategory _category = ShopCategory.bakery;
  DateTime? _fssaiExpiry;
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final c in [
      _businessName,
      _ownerName,
      _phone,
      _email,
      _addressLine,
      _locality,
      _fssaiNumber,
      _accountHolderName,
      _accountNumber,
      _ifscCode,
      _upiId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFssaiExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _fssaiExpiry = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fssaiExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the FSSAI licence expiry date.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.register(
        ShopProfile(
          businessName: _businessName.text.trim(),
          ownerName: _ownerName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          category: _category,
          addressLine: _addressLine.text.trim(),
          locality: _locality.text.trim(),
          fssai: FssaiLicense(
            licenseNumber: _fssaiNumber.text.trim(),
            expiresAt: _fssaiExpiry!,
          ),
          bankDetails: BankDetails(
            accountHolderName: _accountHolderName.text.trim(),
            accountNumber: _accountNumber.text.trim(),
            ifscCode: _ifscCode.text.trim(),
            upiId: _upiId.text.trim().isEmpty ? null : _upiId.text.trim(),
          ),
        ),
      );
    } catch (e) {
      // A silent failure here reads as "the button did nothing" — the
      // worst possible feedback for a form that just tried to hit a real
      // network backend. Always surface *something*, even a raw message,
      // rather than nothing at all.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop = context.isDesktopWidth;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _formSections(context),
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
                const SizedBox(height: 220, child: _HeroVisual()),
                Padding(
                  padding: const EdgeInsets.all(Space.x4),
                  child: MaxWidthBody(
                    maxWidth: Breakpoints.formMaxWidth,
                    child: form,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop: the same split-screen shape as a typical SaaS sign-up page —
    // a plain scrollable form panel beside a fixed, full-height photo
    // panel, rather than the mobile layout's stacked photo-then-form.
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x8,
                        vertical: Space.x10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                color: colors.actionPrimaryBg,
                                size: 22,
                              ),
                              const SizedBox(width: Space.x2),
                              Text(
                                'TOO GOOD TO LEAVE',
                                style: context.type.label.copyWith(
                                  color: colors.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.x6),
                          Text(
                            'Register your shop',
                            style: context.type.display,
                          ),
                          const SizedBox(height: Space.x2),
                          Text(
                            "Tell us about your business — we'll review your "
                            'details and get you listing surplus bags.',
                            style: context.type.bodyLarge.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: Space.x8),
                          form,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Expanded(flex: 9, child: _HeroVisual()),
        ],
      ),
    );
  }

  List<Widget> _formSections(BuildContext context) => [
    _SectionCard(
      icon: Icons.storefront_outlined,
      title: 'Business details',
      children: [
        TextFormField(
          controller: _businessName,
          decoration: _decoration(
            context,
            'Business name',
            Icons.store_outlined,
          ),
          validator: _required,
        ),
        const SizedBox(height: Space.x4),
        _FieldRow([
          TextFormField(
            controller: _ownerName,
            decoration: _decoration(
              context,
              'Owner name',
              Icons.person_outline,
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: _decoration(
              context,
              'Phone number',
              Icons.call_outlined,
            ),
            validator: _required,
          ),
        ]),
        const SizedBox(height: Space.x4),
        _FieldRow([
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(context, 'Email', Icons.mail_outline),
            validator: _required,
          ),
          DropdownButtonFormField<ShopCategory>(
            initialValue: _category,
            decoration: _decoration(
              context,
              'Category',
              Icons.category_outlined,
            ),
            items: ShopCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
        ]),
      ],
    ),
    const SizedBox(height: Space.x5),
    _SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location',
      children: [
        _FieldRow([
          TextFormField(
            controller: _addressLine,
            decoration: _decoration(context, 'Address', Icons.home_outlined),
            validator: _required,
          ),
          TextFormField(
            controller: _locality,
            decoration: _decoration(
              context,
              'Locality / area',
              Icons.map_outlined,
            ),
            validator: _required,
          ),
        ]),
      ],
    ),
    const SizedBox(height: Space.x5),
    _SectionCard(
      icon: Icons.verified_outlined,
      title: 'FSSAI licence',
      subtitle:
          'Mandatory for any food business in India — '
          'this appears on your public profile.',
      children: [
        _FieldRow([
          TextFormField(
            controller: _fssaiNumber,
            decoration: _decoration(
              context,
              'Licence number',
              Icons.badge_outlined,
            ),
            validator: _required,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: _pickFssaiExpiry,
            child: InputDecorator(
              decoration: _decoration(
                context,
                'Expiry date',
                Icons.event_outlined,
              ),
              child: Text(
                _fssaiExpiry == null
                    ? 'Select date'
                    : '${_fssaiExpiry!.day}/'
                          '${_fssaiExpiry!.month}/'
                          '${_fssaiExpiry!.year}',
                style: context.type.bodyLarge.copyWith(
                  color: _fssaiExpiry == null
                      ? context.colors.textTertiary
                      : context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ]),
      ],
    ),
    const SizedBox(height: Space.x5),
    _SectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payout details',
      subtitle:
          'Where your earnings land after a collected '
          'order — never shown to customers.',
      children: [
        _FieldRow([
          TextFormField(
            controller: _accountHolderName,
            decoration: _decoration(
              context,
              'Account holder name',
              Icons.badge_outlined,
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              context,
              'Account number',
              Icons.account_balance_outlined,
            ),
            validator: _required,
          ),
        ]),
        const SizedBox(height: Space.x4),
        _FieldRow([
          TextFormField(
            controller: _ifscCode,
            textCapitalization: TextCapitalization.characters,
            decoration: _decoration(context, 'IFSC code', Icons.tag),
            validator: _required,
          ),
          TextFormField(
            controller: _upiId,
            decoration: _decoration(
              context,
              'UPI ID (optional)',
              Icons.qr_code_outlined,
            ),
          ),
        ]),
      ],
    ),
    const SizedBox(height: Space.x8),
    AppButton(
      label: 'Submit for review',
      onPressed: _isSubmitting ? null : _submit,
      isLoading: _isSubmitting,
    ),
    const SizedBox(height: Space.x6),
  ];
}

/// Consistent filled, rounded field chrome for every input on this screen —
/// scoped here rather than in the global `InputDecorationTheme` so it
/// doesn't ripple into other screens' already-verified field styling.
InputDecoration _decoration(BuildContext context, String label, IconData icon) {
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

/// The photo panel — a mobile top banner or a desktop side panel (both
/// callers just size it differently via a `SizedBox`/`Expanded`). A bottom
/// scrim guarantees the overlaid title stays legible regardless of what
/// part of the photo lands underneath it.
class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/registration_hero.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, colors.scrim],
            ),
          ),
        ),
        Positioned(
          left: Space.x5,
          right: Space.x5,
          bottom: Space.x5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: Space.x3),
              Text(
                'Register your shop',
                style: context.type.headline.copyWith(color: Colors.white),
              ),
              const SizedBox(height: Space.x1),
              Text(
                "Tell us about your business — we'll review your details "
                'and get you listing surplus bags.',
                style: context.type.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled, boxed group of fields — replaces the old bare
/// `_SectionHeader` + flat field list with visual grouping that actually
/// separates "Business details" from "Payout details" at a glance.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: Elevation.card.shadowsFor(colors.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.actionPrimaryBg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: colors.actionPrimaryBg),
              ),
              const SizedBox(width: Space.x3),
              Expanded(child: Text(title, style: context.type.titleSmall)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Space.x2),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                subtitle!,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.x5),
          ...children,
        ],
      ),
    );
  }
}

/// Lays fields side by side on desktop widths, stacked on mobile — the same
/// `context.isDesktopWidth` breakpoint the rest of the shop app's shell
/// uses.
class _FieldRow extends StatelessWidget {
  const _FieldRow(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktopWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: Space.x4),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: Space.x4),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
