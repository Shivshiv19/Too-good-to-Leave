# Phase 8 — Flutter Project Architecture

Status: for approval · Depends on: Phases 1–7 (incl. A1–A24) · Consumers: Phase 9

No amendments. One clarification of §2.1 (§8.3.2) — a phase that produces no amendments is a reasonable
signal that the earlier phases held.

---

## 8.1 Architectural shape

Clean Architecture, three layers, **feature-first** module organisation.

```
presentation  ──depends on──►  domain  ◄──implements──  data
                                 ▲
                                 │ (value objects only)
                            core/domain
```

**The load-bearing rule: `presentation` must never import `data`.** Presentation depends on abstract
repository interfaces in `domain`; concrete implementations are bound only at the composition root. This
single rule is what makes the Phase 1 locked decision — fake repositories now, HTTP later — a
configuration change rather than a refactor. It is enforced by lint, not by convention (§8.7).

---

## 8.2 Top-level structure

```
lib/
  main.dart                     # thin — runApp(ProviderScope(overrides: …))
  bootstrap.dart                # env, global error handlers, DI overrides

  app/
    app.dart                    # MaterialApp.router
    router/
      routes.dart               # typed routes (go_router_builder)
      router.dart               # GoRouter + the §4.3 ordered redirect chain
      guards.dart
      deep_link_validator.dart  # §4.3 — validates remote routes against the table
    theme/
      tokens/primitives.dart    # LAYER 1 — the only file permitted to hold raw values
      tokens/semantic_light.dart
      tokens/semantic_dark.dart
      theme_extensions.dart     # feedback.* · financial.* · urgency.*
      dietary_marks.dart        # A22 — theme-invariant by construction
      app_theme.dart

  core/
    domain/                     # cross-cutting value objects — no owner, no repository
      money.dart  address.dart  lat_lng.dart  pickup_window.dart
      dietary_envelope.dart  price_breakdown.dart  clock.dart
    error/
      app_exception.dart        # sealed hierarchy
      error_mapper.dart         # HTTP + §7.1.5 code → AppException
    network/
      dio_client.dart
      interceptors/
        auth_interceptor.dart         # A24 — serialised refresh
        idempotency_interceptor.dart  # §7.1.6
        etag_interceptor.dart         # §7.1.8
        retry_interceptor.dart
    storage/
      secure_store.dart         # tokens only
      cache_store.dart          # Drift
      prefs.dart
    l10n/                       # ARB files + generated
    utils/formatters.dart       # en_IN money/date — the ONLY formatting site
    permissions/  connectivity/  analytics/  logging/

  design_system/
    foundations/                # spacing · radii · elevation · motion · typography
    components/                 # the 41 components from 06b

  features/
    config/  onboarding/  auth/  location/  catalog/
    checkout/  orders/  engagement/  account/
```

Nine features, derived from the Phase 5 areas. `config` is a feature rather than core because it has a
repository, a cache, and a fake — the same shape as everything else.

---

## 8.3 Feature module anatomy

```
features/catalog/
  domain/
    entities/          surprise_bag.dart  merchant.dart  coverage_status.dart
    repositories/      catalog_repository.dart          # ABSTRACT
    usecases/                                            # only where non-trivial
  data/
    dto/               bag_dto.dart  merchant_dto.dart   # freezed + json_serializable
    mappers/           bag_mapper.dart
    repositories/      catalog_repository_http.dart
                       catalog_repository_fake.dart
    fixtures/          bags_bengaluru.json
  presentation/
    providers/         discover_providers.dart
    screens/           discover_screen.dart  bag_detail_screen.dart  …
    widgets/
  catalog.dart                                           # BARREL — the only public surface
```

### 8.3.1 Cross-feature dependencies

Each feature exposes a **barrel** that is its sole public surface. Cross-feature imports go through the
barrel; reaching into another feature's internals is a lint failure (§8.7).

The dependency graph must stay acyclic. The only edges V1 needs:

| From | To | Reason |
|---|---|---|
| `checkout` | `catalog` | Cart displays the bag being reserved |
| every feature | `config` | `policyValues`, taxonomy |
| every feature | `core`, `design_system` | |

### 8.3.2 Clarification of §2.1 — order snapshots are their own types

`Order` does **not** reference `catalog`'s `SurpriseBag` or `Merchant`. It holds
`OrderBagSnapshot` and `OrderMerchantSnapshot`, owned by the `orders` feature.

This falls directly out of the §2.1 snapshot principle rather than being an architectural convenience:
a snapshot is an immutable historical copy with a different lifecycle from the live entity. Sharing the
type would invite a live merchant object to be assigned onto an order, which is the exact defect §2.1
forbids. The pleasant side effect is that `orders` has **no dependency on `catalog` at all**.

### 8.3.3 What belongs in `core/domain`

Only value objects with **no repository, no owning feature, and no dependencies**: `Money`, `Address`,
`LatLng`, `PickupWindow`, `DietaryEnvelope`, `PriceBreakdown`, `Clock`.

Aggregates always live in features. This boundary is what prevents `core/domain` degenerating into the
god-module that every "shared" folder becomes without a stated admission rule.

---

## 8.4 State management — the Riverpod decision

Promised in Phase 1. The honest comparison:

| | Bloc | Riverpod |
|---|---|---|
| State machine explicitness | **Excellent** — event→state is the whole model | Permissive; discipline required |
| DI | Separate system (`get_it` / `provider`) | **Unified with state** |
| Test injection | Widget-tree dependent for lookup | **Provider overrides, no widget tree needed** |
| Async state vocabulary | Hand-rolled per feature | **`AsyncValue` = loading / data / error** |
| Cache invalidation | Manual | **`ref.watch` dependency graph** |
| Boilerplate | 3+ files per slice | Low, with codegen |
| Prescriptiveness | High (a virtue on large teams) | Low (a risk) |

**Decision: Riverpod.** Three reasons specific to *this* application, not generic preference:

1. **Provider overrides are the mock-swap mechanism.** The Phase 1 locked decision — build entirely
   against fakes — is a one-line override per repository at the composition root, and the same mechanism
   injects per-test fakes. With Bloc this needs a second DI container and manual re-registration.
2. **`AsyncValue` maps onto the §C1 state vocabulary almost exactly**, so 51 screens share one state
   idiom instead of each inventing one.
3. **`ref.watch` invalidation mirrors the §2.5 cache-authority model.** A TTL expiry or a push
   invalidation invalidates a provider, and everything downstream recomputes — which is precisely what
   §2.5 describes in prose.

### The caveat that makes it safe

Riverpod's permissiveness is most dangerous exactly where we need most rigour: the money paths.

**So the payment and order state machines are modelled as explicit sealed unions** (`freezed`), driven by
a notifier that **only permits transitions declared in §2.2**. An illegal transition asserts in debug and
is logged as an error in release.

This takes Bloc's explicitness where it earns its cost — §5c, the area where a bug loses a user's money —
without paying Bloc's boilerplate across all 51 screens.

### Errors: exceptions, not `Result`

Repositories return values and **throw typed exceptions**; `AsyncValue.error` captures them. A
`Result<T, E>` would add ceremony duplicating what `AsyncValue` already provides, and would fight the
idiom of every package in the stack.

---

## 8.5 Error handling

**A sealed `AppException` hierarchy in `core/error`, carrying typed details — and no user-facing
strings.**

```dart
sealed class AppException
  NetworkException · TimeoutException · ServerException
  AuthException(sessionExpired)
  ForceUpdateException(storeUrl, reason) · MaintenanceException(etaAt?)
  ValidationException(fieldErrors)
  PaymentException(chargeState, reason)          // A13
  sealed DomainConflictException
    BagSoldOut(alternativeBagIds)                // §5b.9
    BagWithdrawn · BagWindowClosed
    HoldExpired(bagId)                           // §5c.1 one-tap re-reserve
    PurchaseCapExceeded(remainingAllowance)      // A9
    HoldConflictOtherMerchant(merchantName)      // A6
    CancellationWindowPassed(cutoffAt)           // A15
    OtpInvalid(attemptsRemaining) · OtpExpired · OtpAttemptsExhausted(retryAfter)
    AccountDeletionBlocked(blockers)             // A20
    NotificationNotDismissible(orderId)
```

**Two-stage mapping, deliberately:**

1. `data` maps HTTP status + §7.1.5 `code` → `AppException`. No strings.
2. `presentation` maps `AppException` → an **l10n key plus its typed data**.

The domain layer holding no user-facing copy is what lets §C5 ("never surface raw messages") and the
i18n requirement (assumption A12) be satisfied by the same structure instead of fighting each other. The
typed details are what make §C5's *domain-specific* copy possible — `BagSoldOut` carries the alternatives
the screen needs to offer.

---

## 8.6 Composition root and environments

`bootstrap.dart` builds the `ProviderScope` overrides.

| Flavour | Repositories | Scenario selector |
|---|---|---|
| `dev` | **Fakes** (Phase 1 decision) | Present |
| `staging` | HTTP | Absent |
| `prod` | HTTP | Absent |

Configured via `--dart-define`. The §7.10 scenario selector is guarded by a **compile-time const**, not
`kDebugMode` alone, so tree-shaking removes it entirely from release builds rather than shipping a
disabled debug affordance.

**Vendor abstractions** — every third-party boundary is an interface in `core` with a swappable
implementation, per the Phase 1 engineering defaults:

`MapProvider` (Google → Mappls/Ola swappable, Phase 1 §3.4) · `AuthOtpProvider` (Phase 1 §3.5) ·
**`PaymentGateway`** · `PushProvider` · `AnalyticsProvider` · `Clock`.

**`PaymentGateway` matters most.** No gateway is selected yet, and no gateway SDK type may appear in
`domain` or `presentation`. The interface is defined now against the §7.5 contract so choosing Razorpay,
Cashfree, or PhonePe later touches one file.

---

## 8.7 Enforcement

Conventions that are not mechanically enforced decay. Six custom lint rules, all build-failing:

| Rule | Enforces |
|---|---|
| `no_primitive_token_outside_theme` | §6.1 — the brand-swap mechanism |
| `no_hardcoded_style` | No colour / spacing / `TextStyle` literals in feature code (§C8) |
| `presentation_must_not_import_data` | §8.1 — the fake↔HTTP swap |
| `no_cross_feature_deep_import` | §8.3.1 — barrels only |
| **`no_money_arithmetic`** | **R1** — flags arithmetic operators applied to `Money` outside `core/domain` |
| `no_raw_string_in_widget` | l10n (§C8) |

`no_money_arithmetic` is the one I would keep even if all the others were dropped. R1 is stated in four
documents and is the rule a well-meaning contributor will break first, because summing two prices is the
obvious thing to do. A lint catches it at the moment it is typed; a code review catches it if someone
happens to look.

Also enabled: `riverpod_lint` (provider misuse), `very_good_analysis` as the base rule set.

---

## 8.8 Test structure

```
test/
  unit/            # mirrors lib/ — entities, invariants, mappers, state machines
  widget/          # per screen: loaded · empty · error · submitting (§C8 gate 6)
  golden/          # light × dark × scale 1.0 × scale 2.0  (§6b.5)
integration_test/
  journeys/        # one file per Phase 3 journey
```

**`integration_test/journeys/` maps 1:1 onto Phase 3's six journeys** — including
`journey_06_payment_ambiguity_test.dart`, which drives the fake through
`pendingVerification → uncertain → resolved` and asserts the §5c.6 copy is shown. The journeys were
written as specifications; this makes them executable.

**Golden matrix: four variants per component**, which is the §6b.5 gate. Reduced-motion variants are
asserted in widget tests rather than goldens (a static frame cannot express the difference).

**Determinism:** `Clock` is injected everywhere time is read (§7.10), so pickup windows, countdowns, hold
expiry, and token validity are all testable without waiting and goldens are stable.

---

## 8.9 Package selection

| Package | Role | Rationale |
|---|---|---|
| `flutter_riverpod` + `riverpod_generator` | State + DI | §8.4 |
| `freezed` + `json_serializable` | Immutable models, sealed unions | Brief requires immutability; sealed unions carry §8.4's state machines and §8.5's errors |
| `go_router` + `go_router_builder` | Routing | §4.1 — first-party, typed |
| `dio` | HTTP | Interceptor model fits A24 refresh, idempotency, ETag, retry |
| `flutter_secure_storage` | Tokens | Keystore/Keychain; §5a.1 handles its failure modes |
| **`drift`** | Cache + persistence | SQLite-backed with real migration support. Order history is persistent-indefinite (§2.5) and needs querying, so a relational store is right. Chosen over Isar on maintenance-continuity grounds. |
| `cached_network_image` | Images | WebP, disk cache (Phase 1 §3.6) |
| `intl` | `en_IN` formatting | §C7 — used only in `core/utils/formatters.dart` |
| `qr_flutter` | QR rendering | Must honour A21's fixed light surface |
| `screen_brightness` | §5d.3 | Brightness control with restore |
| `geolocator` + `permission_handler` | Location | §5a.3 branch handling incl. approximate |
| `google_maps_flutter` | Map | **Behind `MapProvider`** (Phase 1 §3.4) |
| `firebase_core` + `firebase_messaging` | Push | **Behind `PushProvider`** |
| `smart_auth` | SMS Retriever + Phone Number Hint | §5a.7 zero-permission autofill |
| `share_plus` | Receipt share | §5d.2 |
| `package_info_plus`, `device_info_plus`, `connectivity_plus` | Version gate, device session, §C3 | |
| `mocktail`, `alchemist` | Tests, goldens | |
| — | **Payment gateway SDK** | **Deferred** until a gateway is chosen; `PaymentGateway` interface defined now |

`flutter_localizations` + ARB for l10n; fonts bundled, not fetched (§6.3.1).

---

## 8.10 Conventions

| Item | Convention |
|---|---|
| Files | `lower_snake_case.dart` |
| Providers | `<subject><Role>Provider` — `discoverFeedProvider`, `bagByIdProvider(id)` |
| DTO ↔ entity | `BagDto` ↔ `SurpriseBag`; mappers are pure functions, unit-tested |
| Screens | `<Name>Screen`; route constants in `routes.dart` only |
| Test names | `<unit>_test.dart`, mirroring the `lib/` path |
| Package name | `lower_snake_case`, set explicitly at `flutter create` (the repo root is `D:\Project\Food`, which does not constrain it) |

---

## 8.11 Phase 9 prerequisites

**Blocking:** Flutter and Dart are **not on PATH** on this machine (verified at Phase 1). Phase 9 cannot
produce running, tested code until the SDK is installed. Everything through Phase 8 is unaffected.

**Non-blocking but needed soon:**

| Item | Needed by |
|---|---|
| **A15 cancellation cutoff sign-off** | Now a `policyValues` entry (§7.3), so a one-line change |
| Brand name, wordmark, palette | Substituting Layer 1 ramps + `action.*` mappings; no component changes (§6.9) |
| Launch city | Mock fixture seed data and copy |
| Payment gateway selection | `PaymentGateway` implementation only |

---

## 8.12 Proposed Phase 9 sequence

Features in dependency order, so each is built on something already tested rather than on a stub:

| # | Feature | Delivers |
|---|---|---|
| 1 | **`core` + `design_system` + theme** | Tokens, the 41 components with goldens, lints active. Not a feature — the substrate everything else asserts against. |
| 2 | `config` | `policyValues`, taxonomy, force-update gate. First end-to-end vertical slice through all three layers. |
| 3 | `auth` + `onboarding` | Includes A23 device token, A24 refresh, §5a.7 OTP escalation |
| 4 | `location` | §5a.4, denial-safe paths |
| 5 | `catalog` | The largest UI surface: discovery, A8 scarcity, A10 coverage states |
| 6 | `checkout` | The highest-risk area: A2, A3, A11, A12, A13, R1–R3 |
| 7 | `orders` | A1 three-layer token, A14 cadence, A15, A16 |
| 8 | `engagement` | A17 |
| 9 | `account` | A18, A19, A20 |

Each feature ships with architecture notes, models, repository + fake, providers, UI, error and loading
states, unit tests, and widget tests — per the brief's Phase 9 requirements and the §C8 Definition of
Done.

**Recommendation: start with step 1.** Building a screen before the design system exists means either
hardcoded styles that the §8.7 lints will later reject, or a token layer retrofitted under working code.
