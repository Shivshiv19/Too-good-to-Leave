import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/pickup_token.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/monospace_code_display.dart';
import 'package:surplus_marketplace/design_system/components/qr_display_block.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';
import 'package:surplus_marketplace/features/orders/presentation/dialogs/cancel_order_dialog.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/directions_launcher.dart';
import 'package:surplus_marketplace/features/orders/presentation/utils/window_state_label.dart';

enum _Phase { loading, loaded, notFound, error }

/// §4.2 `/orders/:orderId/pickup`, §5d.3. Gets the user to the right
/// counter and lets them prove the reservation — with or without a network
/// connection (**A1**).
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  static const _clock = SystemClock();

  _Phase _phase = _Phase.loading;
  Order? _order;
  PickupToken? _token;
  bool _offline = false;
  bool _brightened = false;
  Timer? _pollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  double? _originalBrightness;

  @override
  void initState() {
    super.initState();
    _brighten();
    _watchConnectivity();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _brighten() async {
    try {
      _originalBrightness = await ScreenBrightness.instance.application;
      await ScreenBrightness.instance.setApplicationScreenBrightness(1);
      if (mounted) setState(() => _brightened = true);
    } on Object {
      // No platform support (e.g. web) — the manual toggle simply no-ops.
    }
  }

  Future<void> _restoreBrightness() async {
    final original = _originalBrightness;
    if (original == null) return;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(original);
    } on Object {
      // Best-effort restore.
    }
  }

  Future<void> _toggleBrightness() async {
    try {
      if (_brightened) {
        await _restoreBrightness();
      } else {
        await ScreenBrightness.instance.setApplicationScreenBrightness(1);
      }
      if (mounted) setState(() => _brightened = !_brightened);
    } on Object {
      // No platform support — no-op.
    }
  }

  void _watchConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline =
          results.isEmpty ||
          results.every(
            (r) => r == ConnectivityResult.none,
          );
      if (mounted) setState(() => _offline = offline);
    });
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(ordersRepositoryProvider);
      final order = await repo.getOrder(widget.orderId);
      PickupToken? token;
      try {
        token = await repo.getPickupToken(widget.orderId);
      } on Object {
        token = null; // Silently fall back to the fallback code alone.
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _token = token;
        _phase = _Phase.loaded;
      });
      if (order.status == OrderStatus.collected ||
          order.status == OrderStatus.cancelledByMerchant) {
        _announceTerminal(order.status);
      }
      _scheduleNextPoll();
    } on NotFoundException {
      if (mounted) setState(() => _phase = _Phase.notFound);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _announceTerminal(OrderStatus status) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    SemanticsService.announce(
      status == OrderStatus.collected
          ? l10n.pickupCollectedTitle
          : l10n.merchantCancelledTitle,
      Directionality.of(context),
      assertiveness: Assertiveness.assertive,
    );
  }

  /// Amendment A14 — 5 s while the window is open, 30 s otherwise. No
  /// backgrounding detection (would need a `WidgetsBindingObserver`); this
  /// fake has nothing pushing state changes to poll for anyway once a
  /// terminal status is reached, so polling simply stops there.
  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    final order = _order;
    if (order == null ||
        order.status == OrderStatus.collected ||
        order.status == OrderStatus.cancelledByMerchant ||
        order.status == OrderStatus.expiredUncollected) {
      return;
    }
    final urgency = order.pickupWindow.urgencyAt(_clock);
    final interval = urgency == WindowUrgency.upcoming
        ? const Duration(seconds: 30)
        : const Duration(seconds: 5);
    _pollTimer = Timer(interval, _load);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: l10n.pickupBrightnessToggle,
            icon: Icon(_brightened ? Icons.brightness_7 : Icons.brightness_4),
            onPressed: _toggleBrightness,
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.notFound => _NotFound(l10n: l10n),
          _Phase.error => _ErrorState(onRetry: _load, l10n: l10n),
          _Phase.loaded => _Loaded(
            order: _order!,
            token: _token,
            offline: _offline,
            clock: _clock,
            l10n: l10n,
          ),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.order,
    required this.token,
    required this.offline,
    required this.clock,
    required this.l10n,
  });

  final Order order;
  final PickupToken? token;
  final bool offline;
  final Clock clock;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.collected) {
      return _Terminal(
        icon: Icons.task_alt,
        title: l10n.pickupCollectedTitle,
        body: l10n.pickupCollectedBody,
        assertive: true,
      );
    }
    if (order.status == OrderStatus.cancelledByMerchant) {
      return _Terminal(
        icon: Icons.cancel_outlined,
        title: l10n.merchantCancelledTitle,
        body: l10n.merchantCancelledBody(
          order.merchantSnapshot.displayName,
          Fmt.money(order.breakdown.total),
        ),
        assertive: true,
      );
    }
    if (order.status == OrderStatus.expiredUncollected) {
      return _Terminal(
        icon: Icons.timer_off_outlined,
        title: l10n.orderExpiredTitle,
        body: l10n.orderExpiredBody(Fmt.timeOfDay(order.pickupWindow.endAt)),
        assertive: false,
      );
    }

    final colors = context.colors;
    final urgency = order.pickupWindow.urgencyAt(clock);
    final showOfflineLayer = offline && token != null;
    final qrPayload = showOfflineLayer
        ? token!.offlineToken
        : token?.rotatingPayload;

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            windowStateLabel(order.pickupWindow, clock, l10n),
            style: context.type.title.copyWith(
              color: colors.urgencyForeground(urgency),
            ),
          ),
        ),
        const SizedBox(height: Space.x4),
        Center(
          child: qrPayload != null
              ? QrDisplayBlock(payload: qrPayload, dimmed: showOfflineLayer)
              : const SizedBox.shrink(),
        ),
        if (showOfflineLayer) ...[
          const SizedBox(height: Space.x2),
          Center(
            child: Text(
              l10n.pickupOfflineNote,
              style: context.type.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: Space.x4),
        Center(
          child: Column(
            children: [
              Text(
                l10n.pickupFallbackLabel,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: Space.x1),
              MonospaceCodeDisplay(
                code: token?.fallbackCode ?? '------',
                style: context.type.codeMono,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x6),
        Text(order.merchantSnapshot.displayName, style: context.type.title),
        Text(
          order.merchantSnapshot.address.displayLine,
          style: context.type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x3),
        AppButton(
          label: l10n.pickupDirections(order.merchantSnapshot.displayName),
          variant: AppButtonVariant.secondary,
          onPressed: () => openDirections(
            order.merchantSnapshot.address.geo.latitude,
            order.merchantSnapshot.address.geo.longitude,
          ),
        ),
        const Divider(height: Space.x8),
        Text(
          order.orderCode,
          style: context.type.caption.copyWith(color: colors.textSecondary),
        ),
        Text(order.bagSnapshot.title, style: context.type.body),
        Text(
          'x${order.quantity}',
          style: context.type.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Space.x6),
        AppButton(
          label: l10n.orderActionReportIssue,
          variant: AppButtonVariant.tertiary,
          onPressed: () =>
              OrderIssueRoute(orderId: order.id).push<void>(context),
        ),
        if (order.status == OrderStatus.confirmed) ...[
          const SizedBox(height: Space.x3),
          AppButton(
            label: l10n.orderActionCancel,
            variant: AppButtonVariant.tertiary,
            onPressed: () => showCancelOrderDialog(context, orderId: order.id),
          ),
        ],
      ],
    );
  }
}

class _Terminal extends StatelessWidget {
  const _Terminal({
    required this.icon,
    required this.title,
    required this.body,
    required this.assertive,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool assertive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.textSecondary),
            const SizedBox(height: Space.x4),
            Semantics(
              liveRegion: assertive,
              child: Text(
                title,
                style: context.type.display,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Space.x2),
            Text(
              body,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.notFoundTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.notFoundBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.l10n});

  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.errorServerTitle,
              style: context.type.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              l10n.errorServerBody,
              style: context.type.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x6),
            AppButton(label: l10n.errorRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
