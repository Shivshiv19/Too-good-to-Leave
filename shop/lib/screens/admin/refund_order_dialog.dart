import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// Prompts for a reason before refunding an order — same "required reason"
/// shape as [showRejectShopDialog]. Returns the trimmed reason, or `null`
/// if the admin backed out.
Future<String?> showRefundOrderDialog(
  BuildContext context, {
  required String orderCode,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Refund order $orderCode?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This records that the customer should get their money back. "
            "There's no live payment gateway yet, so it doesn't move real "
            'money — it marks the order refunded and logs why.',
          ),
          const SizedBox(height: Space.x4),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason for the refund',
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
          label: 'Refund',
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
