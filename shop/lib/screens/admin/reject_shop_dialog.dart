import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// Prompts for a reason before rejecting/deactivating a shop — required,
/// since [ShopProfile.rejectionReason]'s own contract is that a declined
/// shop always knows why, never just "no." Returns the trimmed reason, or
/// `null` if the admin backed out.
Future<String?> showRejectShopDialog(
  BuildContext context, {
  required String businessName,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reject $businessName?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This shop won't be able to list until you approve it again. "
            'The reason below is shown to the shop owner.',
          ),
          const SizedBox(height: Space.x4),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason (shown to the shop owner)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        AppButton(
          label: 'Reject',
          variant: AppButtonVariant.destructive,
          expand: false,
          onPressed: () {
            final reason = controller.text.trim();
            Navigator.of(
              context,
            ).pop(reason.isEmpty ? 'No reason given.' : reason);
          },
        ),
      ],
    ),
  );
}
