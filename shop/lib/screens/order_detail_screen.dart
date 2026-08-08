import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/design_system/components/app_button.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';

/// Pickup confirmation via manual fallback-code entry (A1's third layer) —
/// the one path every order supports regardless of whether a QR layer would
/// scan. In-browser camera QR scanning is a real future enhancement, not
/// built here; the fallback code alone is a complete, working confirmation
/// flow on its own.
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = widget.order;
    final isCollected = _status == ShopOrderStatus.collected;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text(order.bagTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer', style: context.type.label),
            const SizedBox(height: Space.x1),
            Text(order.customerName, style: context.type.bodyLarge),
            const SizedBox(height: Space.x6),
            if (isCollected)
              Container(
                padding: const EdgeInsets.all(Space.x4),
                decoration: BoxDecoration(
                  color: colors.success.bg,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colors.success.fg),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Text(
                        'Pickup confirmed.',
                        style: context.type.body.copyWith(
                          color: colors.success.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
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
            ],
          ],
        ),
      ),
    );
  }
}
