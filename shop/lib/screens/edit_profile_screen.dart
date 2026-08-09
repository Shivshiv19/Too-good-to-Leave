import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ShopProfile _original = widget.repository.profile!;

  late final _businessName = TextEditingController(
    text: _original.businessName,
  );
  late final _ownerName = TextEditingController(text: _original.ownerName);
  late final _phone = TextEditingController(text: _original.phone);
  late final _email = TextEditingController(text: _original.email);
  late final _addressLine = TextEditingController(text: _original.addressLine);
  late final _locality = TextEditingController(text: _original.locality);
  late ShopCategory _category = _original.category;

  @override
  void dispose() {
    for (final c in [
      _businessName,
      _ownerName,
      _phone,
      _email,
      _addressLine,
      _locality,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.repository.updateProfile(
      _original.copyWith(
        businessName: _businessName.text.trim(),
        ownerName: _ownerName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        category: _category,
        addressLine: _addressLine.text.trim(),
        locality: _locality.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: const Text('Edit business details'),
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
                const SizedBox(height: Space.x3),
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
                const SizedBox(height: Space.x3),
                Text(
                  'FSSAI licence and payout details can\'t be changed here — '
                  'contact support to update those.',
                  style: context.type.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x8),
                AppButton(label: 'Save changes', onPressed: _save),
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
