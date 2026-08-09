import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_colors.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';

/// Pickup confirmation via manual fallback-code entry (A1's third layer) —
/// the one path every order supports regardless of whether a QR layer would
/// scan. In-browser camera QR scanning is a real future enhancement, not
/// built here; the fallback code alone is a complete, working confirmation
/// flow on its own. Also where a shop records a no-show or cancels a
/// still-reserved order.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.repository,
    required this.order,
    super.key,
  });

  final ShopRepository repository;
  final ShopOrder order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _codeController = TextEditingController();
  String? _error;
  late ShopOrderStatus _status = widget.order.status;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _error = null);
    try {
      await widget.repository.confirmPickupByCode(
        orderId: widget.order.id,
        code: _codeController.text,
      );
      if (mounted) setState(() => _status = ShopOrderStatus.collected);
    } on PickupCodeMismatchException {
      if (mounted) {
        setState(() => _error = "That code doesn't match this order.");
      }
    }
  }

  Future<void> _markNoShow() async {
    await widget.repository.markNoShow(widget.order.id);
    if (mounted) setState(() => _status = ShopOrderStatus.expired);
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          "This marks the order cancelled. The customer's refund still "
          'needs to be handled through your payment provider directly — '
          "this app doesn't process payments.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await widget.repository.cancelOrder(widget.order.id);
    if (mounted) setState(() => _status = ShopOrderStatus.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = widget.order;
    final now = widget.repository.clock.now();
    final isOverdue =
        _status == ShopOrderStatus.reserved &&
        now.isAfter(order.pickupWindow.endAt);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text(order.bagTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: MaxWidthBody(
          maxWidth: Breakpoints.formMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer', style: context.type.label),
              const SizedBox(height: Space.x1),
              Text(order.customerName, style: context.type.bodyLarge),
              const SizedBox(height: Space.x6),
              switch (_status) {
                ShopOrderStatus.collected => _StatusBanner(
                  icon: Icons.check_circle,
                  text: 'Pickup confirmed.',
                  tone: colors.success,
                ),
                ShopOrderStatus.expired => _StatusBanner(
                  icon: Icons.event_busy,
                  text: 'Recorded as a no-show.',
                  tone: colors.attention,
                ),
                ShopOrderStatus.cancelled => _StatusBanner(
                  icon: Icons.cancel_outlined,
                  text: 'Order cancelled.',
                  tone: colors.critical,
                ),
                ShopOrderStatus.reserved => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.x4),
                        child: _StatusBanner(
                          icon: Icons.warning_amber,
                          text:
                              "Pickup window closed. If they didn't come, "
                              'mark it a no-show below.',
                          tone: colors.attention,
                        ),
                      ),
                    Text('Confirm pickup', style: context.type.title),
                    const SizedBox(height: Space.x2),
                    Text(
                      'Ask the customer for their 6-character pickup code.',
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: context.type.codeMono,
                      decoration: InputDecoration(
                        labelText: 'Pickup code',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                    AppButton(label: 'Confirm pickup', onPressed: _confirm),
                    const SizedBox(height: Space.x3),
                    if (isOverdue)
                      AppButton(
                        label: 'Mark as no-show',
                        variant: AppButtonVariant.secondary,
                        onPressed: _markNoShow,
                      ),
                    const SizedBox(height: Space.x3),
                    AppButton(
                      label: 'Cancel order',
                      variant: AppButtonVariant.destructive,
                      onPressed: _cancel,
                    ),
                  ],
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final FeedbackPalette tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.x4),
    decoration: BoxDecoration(
      color: tone.bg,
      borderRadius: BorderRadius.circular(Radii.card),
    ),
    child: Row(
      children: [
        Icon(icon, color: tone.fg),
        const SizedBox(width: Space.x3),
        Expanded(
          child: Text(
            text,
            style: context.type.body.copyWith(
              color: tone.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
