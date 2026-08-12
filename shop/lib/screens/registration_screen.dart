import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/platform/geocoding_service.dart';
import 'package:too_good_to_leave_shop/core/platform/map_tile_config.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/hero_visual.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/components/tile_map_view.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';

/// Bengaluru city centre — the starting point for the map picker when
/// device geolocation isn't available/granted. Matches the customer app's
/// own launch-city fallback and `ShopRepository`'s silent-geolocation one.
const _fallbackCenter = LatLng(12.9716, 77.5946);

/// Shop signup — business details, FSSAI licence, address, and payout
/// bank details. Submitting moves the shop to [ShopApprovalStatus
/// .pendingReview]; nothing past this screen is reachable until a review
/// clears it (see `PendingApprovalScreen`).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    required this.repository,
    required this.onLoginInstead,
    required this.mapTilerApiKey,
    super.key,
  });

  final ShopRepository repository;

  /// Mirrors `LoginScreen`'s own "Register instead" link — someone who
  /// landed here but already has an account shouldn't have to fill out
  /// the whole form to discover that.
  final VoidCallback onLoginInstead;

  /// Empty when unconfigured — the map picker section just doesn't render
  /// rather than crashing; registration still works via
  /// `ShopRepository.register`'s own silent-geolocation fallback.
  final String mapTilerApiKey;

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
  LatLng? _pickedLocation;
  bool _isLocatingForPicker = false;

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

  /// Best-effort starting point for the map picker — the shop's real
  /// current location if permission is already granted, Bengaluru
  /// otherwise. Never blocks on a permission *prompt* here; the picker
  /// itself opens either way and the owner can pan to the right spot.
  Future<LatLng> _bestStartingCenter() async {
    if (_pickedLocation != null) return _pickedLocation!;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallbackCenter;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _fallbackCenter;
    }
  }

  Future<void> _openMapPicker() async {
    setState(() => _isLocatingForPicker = true);
    final startingCenter = await _bestStartingCenter();
    if (!mounted) return;
    setState(() => _isLocatingForPicker = false);

    final picked = await showModalBottomSheet<GeocodingResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MapPickerSheet(
        tileConfig: MapTilerTileConfig(apiKey: widget.mapTilerApiKey),
        geocoding: MapTilerGeocodingService(apiKey: widget.mapTilerApiKey),
        initialCenter: startingCenter,
      ),
    );
    if (picked == null) return;
    setState(() => _pickedLocation = picked.position);
    // The whole point of picking on a map is to skip typing this by hand —
    // always overwrite rather than only-fill-if-empty.
    if (picked.addressLine != null && picked.addressLine!.isNotEmpty) {
      _addressLine.text = picked.addressLine!;
    }
    if (picked.locality != null && picked.locality!.isNotEmpty) {
      _locality.text = picked.locality!;
    }
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
        lat: _pickedLocation?.latitude,
        lng: _pickedLocation?.longitude,
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

  String? _validatePhone(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final digits = value!.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static final _emailPattern = RegExp(r'^[\w.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');

  String? _validateEmail(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateFssai(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^\d{14}$').hasMatch(value!.trim())) {
      return 'FSSAI licence number must be 14 digits';
    }
    return null;
  }

  String? _validateAccountNumber(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^\d{9,18}$').hasMatch(value!.trim())) {
      return 'Enter a valid account number (9–18 digits)';
    }
    return null;
  }

  static final _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  String? _validateIfsc(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!_ifscPattern.hasMatch(value!.trim().toUpperCase())) {
      return 'Enter a valid IFSC code (e.g. SBIN0001234)';
    }
    return null;
  }

  static final _upiPattern = RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');

  /// Optional field — only validated when the shop actually enters one.
  String? _validateUpi(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_upiPattern.hasMatch(value.trim())) {
      return 'Enter a valid UPI ID (e.g. name@bank)';
    }
    return null;
  }

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
                const SizedBox(
                  height: 220,
                  child: HeroVisual(
                    title: 'Register your shop',
                    subtitle:
                        "Tell us about your business — we'll review your "
                        'details and get you listing surplus bags.',
                  ),
                ),
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
          const Expanded(
            flex: 9,
            child: HeroVisual(
              title: 'Register your shop',
              subtitle:
                  "Tell us about your business — we'll review your "
                  'details and get you listing surplus bags.',
            ),
          ),
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: _decoration(
              context,
              'Phone number',
              Icons.call_outlined,
            ),
            validator: _validatePhone,
          ),
        ]),
        const SizedBox(height: Space.x4),
        _FieldRow([
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(context, 'Email', Icons.mail_outline),
            validator: _validateEmail,
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
        if (widget.mapTilerApiKey.isNotEmpty) ...[
          const SizedBox(height: Space.x4),
          _LocationPickerField(
            picked: _pickedLocation,
            isLocating: _isLocatingForPicker,
            tileConfig: MapTilerTileConfig(apiKey: widget.mapTilerApiKey),
            onTap: _isLocatingForPicker ? null : _openMapPicker,
          ),
        ],
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
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
            decoration: _decoration(
              context,
              'Licence number',
              Icons.badge_outlined,
            ),
            validator: _validateFssai,
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(18),
            ],
            decoration: _decoration(
              context,
              'Account number',
              Icons.account_balance_outlined,
            ),
            validator: _validateAccountNumber,
          ),
        ]),
        const SizedBox(height: Space.x4),
        _FieldRow([
          TextFormField(
            controller: _ifscCode,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: _decoration(context, 'IFSC code', Icons.tag),
            validator: _validateIfsc,
          ),
          TextFormField(
            controller: _upiId,
            decoration: _decoration(
              context,
              'UPI ID (optional)',
              Icons.qr_code_outlined,
            ),
            validator: _validateUpi,
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
    const SizedBox(height: Space.x4),
    Center(
      child: TextButton(
        onPressed: _isSubmitting ? null : widget.onLoginInstead,
        child: const Text('Already have an account? Log in instead'),
      ),
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
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const SizedBox(width: Space.x2),
              Expanded(child: Text(title, style: context.type.titleSmall)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Space.x2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
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

/// The Location card's map affordance — a static thumbnail once a spot is
/// picked (tap to change), or a plain prompt button before that. Never
/// required: skipping it just means `ShopRepository.register` falls back
/// to silent device geolocation instead of this explicit pin.
class _LocationPickerField extends StatelessWidget {
  const _LocationPickerField({
    required this.picked,
    required this.isLocating,
    required this.tileConfig,
    required this.onTap,
  });

  final LatLng? picked;
  final bool isLocating;
  final MapTileConfig tileConfig;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final location = picked;

    if (location == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x4,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Row(
            children: [
              if (isLocating)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary,
                  ),
                )
              else
                Icon(
                  Icons.pin_drop_outlined,
                  size: 20,
                  color: colors.textSecondary,
                ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text(
                  'Set your shop\'s exact location on a map',
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: IgnorePointer(
                child: TileMapView(
                  tileConfig: tileConfig,
                  center: location,
                  zoom: 15,
                  interactive: false,
                  pins: [
                    MapPin(
                      position: location,
                      child: Icon(
                        Icons.location_pin,
                        size: 32,
                        color: colors.actionPrimaryBg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x4,
                vertical: Space.x3,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: colors.success.fg),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: Text(
                      'Location pinned — tap to change',
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A real centred-pin picker: the map pans underneath a fixed centre icon
/// (the standard "pin follows the map, not your finger" pattern),
/// confirmed explicitly rather than resolving on the first frame — mirrors
/// the customer app's own `_PinDropSheet` in `location_setup_screen.dart`.
///
/// Two ways to land on a spot: type into the search box (jumps the map to
/// the picked result), or drag the map by hand. Either way, confirming
/// reverse-geocodes the final centre so the registration form's Address /
/// Locality fields get filled in without the owner typing them.
class _MapPickerSheet extends StatefulWidget {
  const _MapPickerSheet({
    required this.tileConfig,
    required this.geocoding,
    required this.initialCenter,
  });

  final MapTileConfig tileConfig;
  final MapTilerGeocodingService geocoding;
  final LatLng initialCenter;

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  final _mapController = fm.MapController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  late LatLng _center = widget.initialCenter;
  List<GeocodingResult> _results = [];
  bool _isSearching = false;
  bool _isConfirming = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await widget.geocoding.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }

  void _selectResult(GeocodingResult result) {
    setState(() {
      _center = result.position;
      _results = [];
      _searchController.text = result.label;
    });
    _searchFocusNode.unfocus();
    _mapController.move(result.position, 16);
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    final resolved = await widget.geocoding.reverseGeocode(_center);
    if (!mounted) return;
    Navigator.of(context).pop(
      resolved ?? GeocodingResult(position: _center, label: 'Pinned location'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x4,
              Space.x4,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Drop a pin on your shop',
                    style: context.type.title,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x4,
              Space.x3,
              Space.x4,
              0,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search for your shop, street or area',
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: colors.textSecondary,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null),
                filled: true,
                fillColor: colors.surfaceSunken,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x3,
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                TileMapView(
                  tileConfig: widget.tileConfig,
                  center: widget.initialCenter,
                  zoom: 16,
                  mapController: _mapController,
                  onCenterChanged: (center) => setState(() {
                    _center = center;
                    _results = [];
                  }),
                ),
                // Fixed at the visual centre — the map moves under it, not
                // the other way round.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_pin,
                      size: 44,
                      color: colors.actionPrimaryBg,
                    ),
                  ),
                ),
                // Search suggestions float over the map so the sheet
                // doesn't grow/shrink as results appear/disappear.
                if (_results.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: Space.x4,
                    right: Space.x4,
                    child: _SearchResultsList(
                      results: _results,
                      onSelected: _selectResult,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: AppButton(
              label: 'Confirm this location',
              onPressed: _isConfirming ? null : _confirm,
              isLoading: _isConfirming,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dropdown of search matches shown under the map picker's search box.
class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.onSelected});

  final List<GeocodingResult> results;
  final ValueChanged<GeocodingResult> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: results.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: colors.borderSubtle.withValues(alpha: 0.6)),
        itemBuilder: (context, index) {
          final result = results[index];
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.place_outlined,
              size: 20,
              color: colors.textSecondary,
            ),
            title: Text(result.label, style: context.type.body),
            onTap: () => onSelected(result),
          );
        },
      ),
    );
  }
}
