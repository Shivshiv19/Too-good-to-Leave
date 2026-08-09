import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/domain/dietary_envelope.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';

/// Create or edit a bag. `existing == null` means create.
class BagEditScreen extends StatefulWidget {
  const BagEditScreen({required this.repository, this.existing, super.key});

  final ShopRepository repository;
  final ShopBag? existing;

  @override
  State<BagEditScreen> createState() => _BagEditScreenState();
}

class _BagEditScreenState extends State<BagEditScreen> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _priceController = TextEditingController(
    text: widget.existing?.price.wholeUnits.toString(),
  );
  late final _quantityController = TextEditingController(
    text: widget.existing?.quantityAvailable.toString(),
  );

  late DietaryEnvelope _envelope =
      widget.existing?.envelope ?? DietaryEnvelope.pureVeg;
  late BagStatus _status = widget.existing?.status ?? BagStatus.draft;
  late TimeOfDay _startTime = widget.existing != null
      ? TimeOfDay.fromDateTime(widget.existing!.pickupWindow.startAt)
      : const TimeOfDay(hour: 18, minute: 0);
  late TimeOfDay _endTime = widget.existing != null
      ? TimeOfDay.fromDateTime(widget.existing!.pickupWindow.endAt)
      : const TimeOfDay(hour: 20, minute: 0);
  late Uint8List? _photoBytes = widget.existing?.photoBytes;
  late bool _repeatsDaily = widget.existing?.repeatsDaily ?? false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  DateTime _todayAt(TimeOfDay time) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final start = _todayAt(_startTime);
    final end = _todayAt(_endTime);

    if (title.isEmpty || !start.isBefore(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a title, and make sure pickup start is before end.',
          ),
        ),
      );
      return;
    }

    final pickupWindow = PickupWindow(startAt: start, endAt: end);
    final existing = widget.existing;
    if (existing == null) {
      await widget.repository.createBag(
        title: title,
        description: _descriptionController.text.trim(),
        envelope: _envelope,
        price: Money.rupees(price),
        quantityAvailable: quantity,
        pickupWindow: pickupWindow,
        photoBytes: _photoBytes,
        repeatsDaily: _repeatsDaily,
      );
    } else {
      await widget.repository.updateBag(
        existing.copyWith(
          title: title,
          description: _descriptionController.text.trim(),
          envelope: _envelope,
          price: Money.rupees(price),
          quantityAvailable: quantity,
          pickupWindow: pickupWindow,
          status: _status,
          photoBytes: _photoBytes,
          repeatsDaily: _repeatsDaily,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await widget.repository.deleteBag(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEditing = widget.existing != null;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text(isEditing ? 'Edit bag' : 'New bag'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline, color: colors.critical.fg),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: MaxWidthBody(
          maxWidth: Breakpoints.formMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PhotoPicker(photoBytes: _photoBytes, onPick: _pickPhoto),
              const SizedBox(height: Space.x4),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: Space.x4),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: Space.x4),
              DropdownButtonFormField<DietaryEnvelope>(
                initialValue: _envelope,
                decoration: const InputDecoration(labelText: 'Contains'),
                items: DietaryEnvelope.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.wireValue.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _envelope = v ?? _envelope),
              ),
              const SizedBox(height: Space.x4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (₹)'),
                    ),
                  ),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Pickup starts',
                      time: _startTime,
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: _TimeField(
                      label: 'Pickup ends',
                      time: _endTime,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeats daily'),
                subtitle: const Text(
                  'Reminds you to duplicate this bag for tomorrow — not '
                  'automatic, this build has no scheduler.',
                ),
                value: _repeatsDaily,
                onChanged: (v) => setState(() => _repeatsDaily = v),
              ),
              if (isEditing) ...[
                const SizedBox(height: Space.x4),
                SegmentedButton<BagStatus>(
                  segments: const [
                    ButtonSegment(value: BagStatus.draft, label: Text('Draft')),
                    ButtonSegment(value: BagStatus.live, label: Text('Live')),
                    ButtonSegment(
                      value: BagStatus.paused,
                      label: Text('Paused'),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
              ],
              const SizedBox(height: Space.x8),
              AppButton(label: 'Save bag', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photoBytes, required this.onPick});

  final Uint8List? photoBytes;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(Radii.card),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: photoBytes != null
              ? Image.memory(photoBytes!, fit: BoxFit.cover)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(height: Space.x1),
                        Text(
                          'bag photo, top-down, natural light',
                          style: context.type.caption.copyWith(
                            color: colors.textTertiary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(time.format(context)),
    ),
  );
}
