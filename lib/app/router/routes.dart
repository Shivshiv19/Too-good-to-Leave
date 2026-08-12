import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:surplus_marketplace/app/screens/app_shell_screen.dart';
import 'package:surplus_marketplace/app/screens/force_update_screen.dart';
import 'package:surplus_marketplace/app/screens/maintenance_screen.dart';
import 'package:surplus_marketplace/app/screens/session_expired_screen.dart';
import 'package:surplus_marketplace/app/screens/splash_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/about_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/account_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/app_settings_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/contact_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/delete_account_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/faq_topic_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/help_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/impact_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/legal_document_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/notification_settings_screen.dart';
import 'package:surplus_marketplace/features/account/presentation/screens/saved_locations_screen.dart';
import 'package:surplus_marketplace/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:surplus_marketplace/features/auth/presentation/screens/phone_entry_screen.dart';
import 'package:surplus_marketplace/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:surplus_marketplace/features/catalog/presentation/screens/bag_detail_screen.dart';
import 'package:surplus_marketplace/features/catalog/presentation/screens/category_browse_screen.dart';
import 'package:surplus_marketplace/features/catalog/presentation/screens/discover_screen.dart';
import 'package:surplus_marketplace/features/catalog/presentation/screens/merchant_profile_screen.dart';
import 'package:surplus_marketplace/features/catalog/presentation/screens/search_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/cart_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/confirmed_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/notify_primer_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/payment_failed_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/processing_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/review_pay_screen.dart';
import 'package:surplus_marketplace/features/checkout/presentation/screens/verifying_screen.dart';
import 'package:surplus_marketplace/features/engagement/presentation/screens/notifications_screen.dart';
import 'package:surplus_marketplace/features/engagement/presentation/screens/rate_review_screen.dart';
import 'package:surplus_marketplace/features/engagement/presentation/screens/saved_screen.dart';
import 'package:surplus_marketplace/features/location/presentation/screens/location_primer_screen.dart';
import 'package:surplus_marketplace/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:surplus_marketplace/features/orders/presentation/screens/orders_screen.dart';
import 'package:surplus_marketplace/features/orders/presentation/screens/pickup_screen.dart';
import 'package:surplus_marketplace/features/orders/presentation/screens/refund_status_screen.dart';
import 'package:surplus_marketplace/features/orders/presentation/screens/report_issue_screen.dart';
import 'package:surplus_marketplace/features/location/presentation/screens/location_setup_screen.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/screens/dietary_setup_screen.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/screens/onboarding_screen.dart';

part 'routes.g.dart';

/// Typed routes (`go_router_builder`, Phase 8 §8.9) — a route change is a
/// compile error rather than a runtime 404.
///
/// **Scope note (Phase 9 Step 5).** The four-tab shell now exists
/// (`StatefulShellRoute.indexedStack`, §4.1) with `catalog`'s real
/// `/discover` branch (list, search, category, merchant, bag) — Orders,
/// Saved, and Account remain placeholder branches until their owning
/// features (Phase 8 §8.12 steps 7–9) land. `HomePlaceholderScreen` and
/// `/home` are deleted; anything that used to fall through to `/home` now
/// falls through to `/discover`.

@TypedGoRoute<SplashRoute>(path: '/splash')
class SplashRoute extends GoRouteData with $SplashRoute {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SplashScreen();
}

@TypedGoRoute<ForceUpdateRoute>(path: '/force-update')
class ForceUpdateRoute extends GoRouteData with $ForceUpdateRoute {
  const ForceUpdateRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ForceUpdateScreen();
}

@TypedGoRoute<MaintenanceRoute>(path: '/maintenance')
class MaintenanceRoute extends GoRouteData with $MaintenanceRoute {
  const MaintenanceRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MaintenanceScreen();
}

@TypedGoRoute<OnboardingRoute>(path: '/onboarding')
class OnboardingRoute extends GoRouteData with $OnboardingRoute {
  const OnboardingRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OnboardingScreen();
}

@TypedGoRoute<DietarySetupRoute>(path: '/dietary-setup')
class DietarySetupRoute extends GoRouteData with $DietarySetupRoute {
  const DietarySetupRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DietarySetupScreen();
}

@TypedGoRoute<LocationPrimerRoute>(path: '/location-primer')
class LocationPrimerRoute extends GoRouteData with $LocationPrimerRoute {
  const LocationPrimerRoute({this.redirectTo});

  final String? redirectTo;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LocationPrimerScreen(redirect: redirectTo);
}

@TypedGoRoute<LocationSetupRoute>(path: '/location-setup')
class LocationSetupRoute extends GoRouteData with $LocationSetupRoute {
  const LocationSetupRoute({this.redirectTo});

  final String? redirectTo;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LocationSetupScreen(redirectTo: redirectTo);
}

@TypedGoRoute<PhoneEntryRoute>(path: '/auth/phone')
class PhoneEntryRoute extends GoRouteData with $PhoneEntryRoute {
  const PhoneEntryRoute({this.redirectTo});

  // Named `redirectTo`, not `redirect` — GoRouteData already declares a
  // `redirect` method for its own per-route redirect callback.
  final String? redirectTo;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PhoneEntryScreen(redirect: redirectTo);
}

@TypedGoRoute<OtpVerifyRoute>(path: '/auth/otp')
class OtpVerifyRoute extends GoRouteData with $OtpVerifyRoute {
  const OtpVerifyRoute({
    required this.phoneE164,
    required this.requestId,
    this.redirectTo,
  });

  final String phoneE164;
  final String requestId;
  final String? redirectTo;

  @override
  Widget build(BuildContext context, GoRouterState state) => OtpVerifyScreen(
    phoneE164: phoneE164,
    requestId: requestId,
    redirect: redirectTo,
  );
}

@TypedGoRoute<ProfileSetupRoute>(path: '/auth/profile-setup')
class ProfileSetupRoute extends GoRouteData with $ProfileSetupRoute {
  const ProfileSetupRoute({this.redirectTo});

  final String? redirectTo;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ProfileSetupScreen(redirect: redirectTo);
}

@TypedGoRoute<SessionExpiredRoute>(path: '/session-expired')
class SessionExpiredRoute extends GoRouteData with $SessionExpiredRoute {
  const SessionExpiredRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SessionExpiredScreen();
}

/// The four-tab shell (§4.1, §2.4) — one persistent `Navigator` per branch.
@TypedStatefulShellRoute<AppShellRouteData>(
  branches: [
    TypedStatefulShellBranch<DiscoverBranchData>(
      routes: [
        TypedGoRoute<DiscoverRoute>(
          path: '/discover',
          routes: [
            TypedGoRoute<DiscoverSearchRoute>(path: 'search'),
            TypedGoRoute<DiscoverCategoryRoute>(path: 'category/:categoryId'),
            TypedGoRoute<DiscoverMerchantRoute>(path: 'merchant/:merchantId'),
            TypedGoRoute<DiscoverBagRoute>(path: 'bag/:bagId'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<OrdersBranchData>(
      routes: [
        TypedGoRoute<OrdersRoute>(
          path: '/orders',
          routes: [
            TypedGoRoute<OrderDetailRoute>(path: ':orderId'),
            TypedGoRoute<OrderPickupRoute>(path: ':orderId/pickup'),
            TypedGoRoute<OrderRefundRoute>(path: ':orderId/refund'),
            TypedGoRoute<OrderIssueRoute>(path: ':orderId/issue'),
            TypedGoRoute<OrderReviewRoute>(path: ':orderId/review'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<SavedBranchData>(
      routes: [
        TypedGoRoute<SavedRoute>(
          path: '/saved',
          routes: [
            TypedGoRoute<SavedMerchantRoute>(path: 'merchant/:merchantId'),
            TypedGoRoute<SavedBagRoute>(path: 'bag/:bagId'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<AccountBranchData>(
      routes: [
        TypedGoRoute<AccountRoute>(
          path: '/account',
          routes: [
            TypedGoRoute<AccountProfileRoute>(path: 'profile'),
            TypedGoRoute<AccountLocationsRoute>(path: 'locations'),
            TypedGoRoute<AccountImpactRoute>(path: 'impact'),
            TypedGoRoute<AccountNotificationsRoute>(path: 'notifications'),
            TypedGoRoute<AccountSettingsRoute>(path: 'settings'),
            TypedGoRoute<AccountHelpRoute>(path: 'help'),
            TypedGoRoute<AccountHelpTopicRoute>(path: 'help/:topicId'),
            TypedGoRoute<AccountContactRoute>(path: 'contact'),
            TypedGoRoute<AccountLegalRoute>(path: 'legal/:docId'),
            TypedGoRoute<AccountAboutRoute>(path: 'about'),
            TypedGoRoute<AccountDeleteRoute>(path: 'delete'),
          ],
        ),
      ],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  const AppShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => AppShellScreen(navigationShell: navigationShell);
}

class DiscoverBranchData extends StatefulShellBranchData {
  const DiscoverBranchData();
}

class OrdersBranchData extends StatefulShellBranchData {
  const OrdersBranchData();
}

class SavedBranchData extends StatefulShellBranchData {
  const SavedBranchData();
}

class AccountBranchData extends StatefulShellBranchData {
  const AccountBranchData();
}

class DiscoverRoute extends GoRouteData with $DiscoverRoute {
  const DiscoverRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DiscoverScreen();
}

class DiscoverSearchRoute extends GoRouteData with $DiscoverSearchRoute {
  const DiscoverSearchRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SearchScreen();
}

class DiscoverCategoryRoute extends GoRouteData with $DiscoverCategoryRoute {
  const DiscoverCategoryRoute({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CategoryBrowseScreen(categoryId: categoryId);
}

class DiscoverMerchantRoute extends GoRouteData with $DiscoverMerchantRoute {
  const DiscoverMerchantRoute({required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MerchantProfileScreen(merchantId: merchantId);
}

class DiscoverBagRoute extends GoRouteData with $DiscoverBagRoute {
  const DiscoverBagRoute({required this.bagId});

  final String bagId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      BagDetailScreen(bagId: bagId);
}

class OrdersRoute extends GoRouteData with $OrdersRoute {
  const OrdersRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OrdersScreen();
}

class OrderDetailRoute extends GoRouteData with $OrderDetailRoute {
  const OrderDetailRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      OrderDetailScreen(orderId: orderId);
}

class OrderPickupRoute extends GoRouteData with $OrderPickupRoute {
  const OrderPickupRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PickupScreen(orderId: orderId);
}

class OrderRefundRoute extends GoRouteData with $OrderRefundRoute {
  const OrderRefundRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RefundStatusScreen(orderId: orderId);
}

class OrderIssueRoute extends GoRouteData with $OrderIssueRoute {
  const OrderIssueRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ReportIssueScreen(orderId: orderId);
}

class SavedRoute extends GoRouteData with $SavedRoute {
  const SavedRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SavedScreen();
}

class SavedMerchantRoute extends GoRouteData with $SavedMerchantRoute {
  const SavedMerchantRoute({required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MerchantProfileScreen(merchantId: merchantId);
}

class SavedBagRoute extends GoRouteData with $SavedBagRoute {
  const SavedBagRoute({required this.bagId});

  final String bagId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      BagDetailScreen(bagId: bagId);
}

class OrderReviewRoute extends GoRouteData with $OrderReviewRoute {
  const OrderReviewRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RateReviewScreen(orderId: orderId);
}

class AccountRoute extends GoRouteData with $AccountRoute {
  const AccountRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AccountScreen();
}

class AccountProfileRoute extends GoRouteData with $AccountProfileRoute {
  const AccountProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const EditProfileScreen();
}

class AccountLocationsRoute extends GoRouteData with $AccountLocationsRoute {
  const AccountLocationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SavedLocationsScreen();
}

class AccountImpactRoute extends GoRouteData with $AccountImpactRoute {
  const AccountImpactRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ImpactScreen();
}

class AccountNotificationsRoute extends GoRouteData
    with $AccountNotificationsRoute {
  const AccountNotificationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationSettingsScreen();
}

class AccountSettingsRoute extends GoRouteData with $AccountSettingsRoute {
  const AccountSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AppSettingsScreen();
}

class AccountHelpRoute extends GoRouteData with $AccountHelpRoute {
  const AccountHelpRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HelpScreen();
}

class AccountHelpTopicRoute extends GoRouteData with $AccountHelpTopicRoute {
  const AccountHelpTopicRoute({required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      FaqTopicScreen(topicId: topicId);
}

class AccountContactRoute extends GoRouteData with $AccountContactRoute {
  const AccountContactRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ContactScreen();
}

class AccountLegalRoute extends GoRouteData with $AccountLegalRoute {
  const AccountLegalRoute({required this.docId});

  final String docId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LegalDocumentScreen(docId: docId);
}

class AccountAboutRoute extends GoRouteData with $AccountAboutRoute {
  const AccountAboutRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AboutScreen();
}

class AccountDeleteRoute extends GoRouteData with $AccountDeleteRoute {
  const AccountDeleteRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DeleteAccountScreen();
}

// ---------------------------------------------------------------------------
// `checkout` (Phase 8 §8.12 step 6) — outside the shell, no bottom nav
// (§4.4). The wall (A4) sits precisely at `/checkout`; see
// `router.dart`'s `_authRequiredPrefixes`.
// ---------------------------------------------------------------------------

@TypedGoRoute<CheckoutRoute>(path: '/checkout')
class CheckoutRoute extends GoRouteData with $CheckoutRoute {
  const CheckoutRoute({required this.bagId, required this.quantity});

  final String bagId;
  final int quantity;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CartScreen(bagId: bagId, quantity: quantity);
}

@TypedGoRoute<CheckoutPayRoute>(path: '/checkout/pay')
class CheckoutPayRoute extends GoRouteData with $CheckoutPayRoute {
  const CheckoutPayRoute({required this.holdId});

  final String holdId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ReviewPayScreen(holdId: holdId);
}

@TypedGoRoute<CheckoutProcessingRoute>(path: '/checkout/processing')
class CheckoutProcessingRoute extends GoRouteData
    with $CheckoutProcessingRoute {
  const CheckoutProcessingRoute({
    required this.orderId,
    required this.paymentId,
    required this.gatewayPayload,
  });

  final String orderId;
  final String paymentId;
  final String gatewayPayload;

  @override
  Widget build(BuildContext context, GoRouterState state) => ProcessingScreen(
    orderId: orderId,
    paymentId: paymentId,
    gatewayPayload: gatewayPayload,
  );
}

@TypedGoRoute<CheckoutVerifyingRoute>(path: '/checkout/verifying')
class CheckoutVerifyingRoute extends GoRouteData with $CheckoutVerifyingRoute {
  const CheckoutVerifyingRoute({required this.orderId, this.resumed = false});

  final String orderId;

  /// True only when reached via §4.3 rule 4 (A3's cold-start resume).
  final bool resumed;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VerifyingScreen(orderId: orderId, resumed: resumed);
}

@TypedGoRoute<CheckoutFailedRoute>(path: '/checkout/failed')
class CheckoutFailedRoute extends GoRouteData with $CheckoutFailedRoute {
  const CheckoutFailedRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PaymentFailedScreen(orderId: orderId);
}

@TypedGoRoute<CheckoutConfirmedRoute>(path: '/checkout/confirmed/:orderId')
class CheckoutConfirmedRoute extends GoRouteData with $CheckoutConfirmedRoute {
  const CheckoutConfirmedRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ConfirmedScreen(orderId: orderId);
}

@TypedGoRoute<CheckoutNotifyPrimerRoute>(
  path: '/checkout/notify-primer/:orderId',
)
class CheckoutNotifyPrimerRoute extends GoRouteData
    with $CheckoutNotifyPrimerRoute {
  const CheckoutNotifyPrimerRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      NotifyPrimerScreen(orderId: orderId);
}

// ---------------------------------------------------------------------------
// `engagement` (Phase 8 §8.12 step 8) — `/notifications` is pushed above the
// shell (§4.2), same "outside the four-tab bottom nav" shape as `checkout`.
// ---------------------------------------------------------------------------

@TypedGoRoute<NotificationsRoute>(path: '/notifications')
class NotificationsRoute extends GoRouteData with $NotificationsRoute {
  const NotificationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationsScreen();
}
