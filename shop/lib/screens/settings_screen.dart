import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/store_hours.dart';

const _dayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

Future<int?> _pickHour(
  BuildContext context, {
  required int initial,
  required String title,
}) => showDialog<int>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      for (var hour = 0; hour < 24; hour++)
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(hour),
          child: Text('${hour.toString().padLeft(2, '0')}:00'),
        ),
    ],
  ),
);

/// Store hours — informational only (§domain/store_hours.dart's own doc:
/// not cross-checked against bag pickup windows, which is where real
/// per-listing timing already lives).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.repository, super.key});

  final ShopRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final hours = repository.storeHours;

        return Scaffold(
          backgroundColor: colors.surfaceBase,
          appBar: AppBar(
            backgroundColor: colors.surfaceBase,
            title: Text('Store hours', style: context.type.title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.x4),
            child: MaxWidthBody(
              maxWidth: Breakpoints.formMaxWidth,
              child: Column(
                children: [
                  for (var index = 0; index < hours.days.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x2),
                      child: _DayRow(
                        index: index,
                        day: hours.days[index],
                        hours: hours,
                        repository: repository,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.index,
    required this.day,
    required this.hours,
    required this.repository,
  });

  final int index;
  final DayHours day;
  final StoreHours hours;
  final ShopRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_dayLabels[index], style: context.type.body)),
          if (day.isOpen) ...[
            TextButton(
              onPressed: () async {
                final hour = await _pickHour(
                  context,
                  initial: day.openHour,
                  title: 'Opens at',
                );
                if (hour != null) {
                  await repository.updateStoreHours(
                    hours.withDay(index, day.copyWith(openHour: hour)),
                  );
                }
              },
              child: Text('${day.openHour.toString().padLeft(2, '0')}:00'),
            ),
            Text('–', style: context.type.body),
            TextButton(
              onPressed: () async {
                final hour = await _pickHour(
                  context,
                  initial: day.closeHour,
                  title: 'Closes at',
                );
                if (hour != null) {
                  await repository.updateStoreHours(
                    hours.withDay(index, day.copyWith(closeHour: hour)),
                  );
                }
              },
              child: Text('${day.closeHour.toString().padLeft(2, '0')}:00'),
            ),
          ] else
            Text(
              'Closed',
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
          Switch(
            value: day.isOpen,
            onChanged: (isOpen) => repository.updateStoreHours(
              hours.withDay(index, day.copyWith(isOpen: isOpen)),
            ),
          ),
        ],
      ),
    );
  }
}
