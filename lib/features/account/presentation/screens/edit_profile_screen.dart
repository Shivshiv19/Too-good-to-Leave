import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/avatar_image.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';

final _nameInvalidPattern = RegExp(r'[^\d\s]');
final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

/// §4.2 `/account/profile`, §5f.2. Phone is **read-only in V1** — changing
/// it is an identity change needing OTP verification on both numbers plus
/// account-takeover protection, deliberately deferred to Contact us.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  Customer? _customer;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _avatarUrl;
  bool _dirty = false;
  bool _submitting = false;
  bool _uploadingAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _nameController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    final customer = await ref.read(authRepositoryProvider).restoreSession();
    if (!mounted || customer == null) return;
    setState(() {
      _customer = customer;
      _nameController.text = customer.name ?? '';
      _emailController.text = customer.email ?? '';
      _avatarUrl = customer.avatarUrl;
      _dirty = false;
    });
  }

  bool get _nameValid {
    final name = _nameController.text.trim();
    return name.length >= 2 &&
        name.length <= 50 &&
        _nameInvalidPattern.hasMatch(name) &&
        !name.contains('://');
  }

  bool get _emailValid {
    final email = _emailController.text.trim();
    return email.isEmpty ||
        (email.length <= 254 && _emailPattern.hasMatch(email));
  }

  Future<void> _pickAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) {
        setState(() => _uploadingAvatar = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      // No real EXIF-stripping/upload pipeline exists in this fake — see
      // the implementation log's "Not delivered" note. The data: URI is a
      // real, working round-trip for display purposes.
      setState(() {
        _avatarUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _uploadingAvatar = false;
        _dirty = true;
      });
    } on Object {
      // §5f.2 — an avatar failure must not discard a name/email edit.
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _removeAvatar() => setState(() {
    _avatarUrl = null;
    _dirty = true;
  });

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateAccountDetails(
            name: _nameController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            avatarUrl: _avatarUrl,
            clearAvatar: _avatarUrl == null,
          );
      if (!mounted) return;
      setState(() {
        _customer = updated;
        _submitting = false;
        _dirty = false;
      });
      Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = AppLocalizations.of(context).errorServerBody;
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editProfileUnsavedTitle),
        content: Text(l10n.editProfileUnsavedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.editProfileKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.editProfileDiscard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final customer = _customer;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: colors.surfaceBase,
        appBar: AppBar(
          backgroundColor: colors.surfaceBase,
          elevation: 0,
          title: Text(l10n.accountEditProfile),
        ),
        body: SafeArea(
          child: customer == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(Space.x4),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Semantics(
                            label: l10n.editProfileAvatarLabel,
                            child: AvatarImage(
                              avatarUrl: _avatarUrl,
                              name: _nameController.text,
                              size: 96,
                            ),
                          ),
                          const SizedBox(height: Space.x3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                label: l10n.editProfileUploadAvatar,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.small,
                                expand: false,
                                isLoading: _uploadingAvatar,
                                onPressed: _pickAvatar,
                              ),
                              if (_avatarUrl != null) ...[
                                const SizedBox(width: Space.x2),
                                Semantics(
                                  button: true,
                                  label: l10n.editProfileRemoveAvatar,
                                  excludeSemantics: true,
                                  child: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: _removeAvatar,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x6),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.editProfileNameLabel,
                        border: const OutlineInputBorder(),
                        errorText:
                            _nameController.text.isNotEmpty && !_nameValid
                            ? l10n.editProfileNameInvalid
                            : null,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.editProfileEmailLabelOptional,
                        border: const OutlineInputBorder(),
                        errorText: !_emailValid
                            ? l10n.editProfileEmailInvalid
                            : null,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: customer.phoneE164,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.editProfilePhoneLabelReadOnly,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.x3),
                      Text(
                        _error!,
                        style: TextStyle(color: colors.critical.fg),
                      ),
                    ],
                    const SizedBox(height: Space.x6),
                    AppButton(
                      label: l10n.editProfileSaveCta,
                      isLoading: _submitting,
                      onPressed:
                          _dirty && _nameValid && _emailValid && !_submitting
                          ? _save
                          : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
