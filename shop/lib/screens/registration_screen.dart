import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: const Text('Register your shop'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: MaxWidthBody(
          maxWidth: Breakpoints.formMaxWidth,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader('Business details'),
                TextFormField(
                  controller: _businessName,
                  decoration: const InputDecoration(labelText: 'Business name'),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _ownerName,
                  decoration: const InputDecoration(labelText: 'Owner name'),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                DropdownButtonFormField<ShopCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ShopCategory.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),

                _SectionHeader('Location'),
                TextFormField(
                  controller: _addressLine,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _locality,
                  decoration: const InputDecoration(
                    labelText: 'Locality / area',
                  ),
                  validator: _required,
                ),

                _SectionHeader('FSSAI licence'),
                Text(
                  'Mandatory for any food business in India — this appears on '
                  'your public profile.',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _fssaiNumber,
                  decoration: const InputDecoration(
                    labelText: 'Licence number',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                InkWell(
                  onTap: _pickFssaiExpiry,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Expiry date'),
                    child: Text(
                      _fssaiExpiry == null
                          ? 'Select date'
                          : '${_fssaiExpiry!.day}/${_fssaiExpiry!.month}/${_fssaiExpiry!.year}',
                    ),
                  ),
                ),

                _SectionHeader('Payout details'),
                TextFormField(
                  controller: _accountHolderName,
                  decoration: const InputDecoration(
                    labelText: 'Account holder name',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _accountNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Account number',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _ifscCode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'IFSC code'),
                  validator: _required,
                ),
                const SizedBox(height: Space.x3),
                TextFormField(
                  controller: _upiId,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID (optional)',
                  ),
                ),

                const SizedBox(height: Space.x8),
                AppButton(
                  label: 'Submit for review',
                  onPressed: _isSubmitting ? null : _submit,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x3),
    child: Text(text, style: context.type.title),
  );
}
