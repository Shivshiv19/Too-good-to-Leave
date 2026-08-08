# Phase 4 — Navigation Flow

Status: for approval · Depends on: [Phase 1](01-business-understanding.md), [Phase 2](02-information-architecture.md), [Phase 3](03-user-journeys.md) (incl. amendments A1–A6) · Consumers: Phases 5, 8, 9

---

## 4.1 Navigation architecture

**`go_router` with `StatefulShellRoute.indexedStack` for the four-tab shell.**

Justification against the alternatives:

| Option | Verdict |
|---|---|
| Imperative `Navigator` + named routes | Rejected. Cannot satisfy §2.6 constraint 1 (every route resolvable from cold start with no in-memory state). Deep-link handling degenerates into hand-rolled stack reconstruction. |
| `go_router` with a single stack | Rejected. Tabs would share one back stack, so switching Discover → Orders → Discover loses the user's scroll and filter position. Unacceptable for a browse-heavy product. |
| **`go_router` + `StatefulShellRoute.indexedStack`** | **Chosen.** Declarative URL-addressable routes (satisfies cold-start deep links), one persistent `Navigator` per tab (independent back stacks, preserved state), a single central `redirect` for guards, and typed route objects via `go_router_builder` so a route change is a compile error rather than a runtime 404. |
| `auto_route` | Viable, comparable feature set. Rejected on ecosystem gravity — `go_router` is first-party (Flutter team), which matters for a codebase intended to outlive its first engineers. |

### The synchronous-redirect constraint

`go_router`'s `redirect` callback **cannot await**. Any state a guard depends on must already be
resolved and synchronously readable. This dictates the startup design:

- A single `SessionState` object exposes synchronous flags: `isBootstrapped`, `forceUpdateRequired`,
  `hasSeenOnboarding`, `hasLocation`, `isAuthenticated`, `isProfileComplete`,
  `unresolvedPaymentOrderId`.
- All asynchronous work (token read from secure storage, remote config fetch, cached location read,
  unresolved-payment check) happens **once, in the Splash route**, before any guard can need it.
- The router is wired to `refreshListenable: sessionState`, so a change to any flag re-runs the
  redirect chain. Logout, token expiry, and location acquisition therefore reroute automatically
  without a single imperative `navigate` call at the call site.

This is why Splash is a real route with real work, not a decorative delay.

---

## 4.2 Route tree

```
/splash                                  bootstrap · force-update gate · A3 payment recovery
/force-update                            terminal, blocking
/maintenance                             terminal, blocking
/session-expired                         terminal until re-auth

/onboarding                              carousel
/location-primer                         our screen, precedes the OS dialog
/location-setup                          detect · locality search · map pin  (denial-safe path)
/dietary-setup                           4 envelopes + show-all

/auth/phone?redirect=<path>              E.164 entry
/auth/otp?redirect=<path>                verify · resend · voice/WhatsApp fallback
/auth/profile-setup?redirect=<path>      name only

ShellRoute (StatefulShellRoute.indexedStack) — bottom nav visible
│
├── branch 0  /discover?<facets>         list · map toggle · filters live in the URL (§4.5)
│              /discover/search
│              /discover/category/:categoryId
│              /discover/merchant/:merchantId
│              /discover/bag/:bagId
│
├── branch 1  /orders                    active + history
│              /orders/:orderId
│              /orders/:orderId/pickup    ← A1 three-layer token surface
│              /orders/:orderId/refund
│              /orders/:orderId/review
│              /orders/:orderId/issue
│
├── branch 2  /saved                     merchants | watchlist (segmented)
│              /saved/merchant/:merchantId
│              /saved/bag/:bagId
│
└── branch 3  /account
               /account/profile
               /account/locations
               /account/notifications
               /account/settings
               /account/help
               /account/help/:topicId
               /account/contact
               /account/legal/:docId      terms · privacy · refunds · grievance officer
               /account/about
               /account/delete

/notifications                           notification centre — pushed above the shell

CheckoutFlow — outside the shell, no bottom nav (§4.4)
   /checkout?bagId=<id>                  cart · hold countdown
   /checkout/pay
   /checkout/processing                  gateway / app-switch in flight
   /checkout/verifying?orderId=<id>      pendingVerification · A3 resume target
   /checkout/failed?orderId=<id>
   /checkout/confirmed/:orderId
   /checkout/notify-primer/:orderId      ← A5: permission ask lands here
```

### Bag detail and merchant profile are declared in more than one branch

`/discover/bag/:bagId` and `/saved/bag/:bagId` are **two route declarations rendering one shared
widget.**

The alternative — a single top-level `/bag/:bagId` pushed above the shell — was rejected because it
hides the bottom navigation. A user reading a bag detail must be able to jump to Orders to check a
pickup they already have; a bag detail that traps them is a dead end for the sake of a tidier route
table. The duplication is two lines of declaration and is the idiomatic `go_router` answer.

Navigation helper: `bagRoute(bagId)` resolves the path for the *currently active* branch, so tapping
a bag from Saved keeps the user in Saved. Deep links from push resolve into the Discover branch,
which is the correct default for an externally-originated link.

---

## 4.3 Route guards

A single ordered `redirect`. **First match wins** — order is load-bearing.

| # | Condition | Redirect to | Notes |
|---|---|---|---|
| 1 | `forceUpdateRequired` | `/force-update` | Outranks everything, including an in-flight payment. A client we have declared unsafe must not transact. |
| 2 | `maintenanceMode` | `/maintenance` | |
| 3 | `!isBootstrapped` | `/splash` | |
| 4 | `unresolvedPaymentOrderId != null` | `/checkout/verifying?orderId=…` | **A3.** Placed above onboarding and auth deliberately: a debited user with no order is the most urgent state in the app. |
| 5 | `!hasSeenOnboarding` | `/onboarding` | |
| 6 | `!hasLocation` **and** target requires location | `/location-primer` | Scoped, not global — `/account/legal/:docId` must be reachable without a location |
| 7 | target requires auth **and** `!isAuthenticated` | `/auth/phone?redirect=<target>` | **A4.** The auth wall. |
| 8 | `isAuthenticated` **and** `!isProfileComplete` | `/auth/profile-setup?redirect=<target>` | |
| 9 | — | no redirect | |

### Route auth classification (A4 — deferred auth)

| Class | Routes |
|---|---|
| **Public, no location** | `/splash` · `/force-update` · `/maintenance` · `/onboarding` · `/location-*` · `/dietary-setup` · `/auth/*` · `/account/legal/:docId` · `/account/about` · `/account/help` · `/account/help/:topicId` |
| **Public, location required** | `/discover` and all its children — merchant profiles and bag details included |
| **Auth required** | `/checkout/*` · `/orders/*` · `/saved/*` · `/account/*` (except the public entries above) · `/notifications` |

The wall sits precisely at `/checkout`. Everything a first-time user needs in order to *believe the
offer is real* is reachable without an account.

### Destination preservation

`?redirect=<url-encoded path incl. query>` threads through `/auth/phone` → `/auth/otp` →
`/auth/profile-setup`, then `context.go(redirect)` on success. Satisfies §2.6 constraint 2 — a push
tapped by a logged-out user completes its journey instead of dead-ending on home.

**Security:** the `redirect` value is validated against the known route table and rejected unless it
is an internal path. An unvalidated redirect parameter is an open-redirect primitive; treating a
query parameter as a navigation instruction without validation is the same class of bug on mobile as
it is on the web.

**Revalidation on return (§3.1 step 8):** arriving back at `/checkout?bagId=…` after the auth
detour performs a hard availability revalidation per rule R2. Bags sell out during OTP; this is the
common case, not the edge case.

---

## 4.4 Checkout sits outside the shell

No bottom navigation from `/checkout` onward. Payment is a committed linear flow; letting the user
tab away mid-transaction produces ambiguous state, orphaned holds, and abandonment. It also keeps
the A2 hold countdown continuously visible, which is the one piece of information that cannot be
missed.

`/checkout/confirmed/:orderId` transitions with `go()`, not `push()` — it **replaces** the stack.
Back from a confirmation must never re-enter a payment screen.

---

## 4.5 Filters are URL state, not a screen

`/discover?diet=pureVeg&maxKm=3&cat=bakery,cafe&sort=distance&anchor=loc_7`

The filter and sort sheets are **editors of URL state**, not destinations. Three consequences, all
of them wins:

1. A filtered view is shareable and restorable — including from a `newBagsNearby` push carrying an
   `anchor`, per §2.6.
2. Filter state survives process death and tab switching for free, with no bespoke persistence code.
3. Discovery becomes testable by URL: a widget test navigates to a path and asserts the rendering,
   with no sheet interaction to drive.

The sticky dietary preference (§2.3) is the default value of `diet` when the parameter is absent —
never an invisible filter applied beneath the URL. What narrows the results is always legible in the
route.

---

## 4.6 Modal vs. page classification

**Principle: a surface gets a route if it is deep-linkable, restorable, or blocking. Otherwise it is
a sheet owned by its parent screen.**

| Surface | Presentation | Reasoning |
|---|---|---|
| Filter · Sort · Location switcher | Bottom sheet, **no route** | Editors of URL state (§4.5) |
| Payment method · UPI app chooser | Bottom sheet, **no route** | Ephemeral, inside a flow that already has routes |
| Replace-cart confirm · Cancel-order confirm · Leave-verification confirm | Dialog, **no route** | Transient decisions |
| Force update · Maintenance · Session expired | **Full route** | Blocking; must survive process death and cannot be dismissed |
| Notification centre | **Full route**, above the shell | Push-targetable |
| Bag detail · Merchant profile | **Full route**, in-shell | Deep-link targets |
| Pickup screen | **Full route** | Deep-link target, and the highest-stakes surface in the product |
| Onboarding · Auth · Permission primers | **Full route** | Guard targets |

---

## 4.7 Back behaviour

Enumerated because the defaults are wrong in exactly the places where being wrong costs money.

| From | Back does | Why |
|---|---|---|
| Tab root (Orders/Saved/Account) | Switch to Discover branch | Standard Android tab semantics |
| Discover root | System exit | |
| `/checkout` (cart) | Return to bag detail, **hold retained**, countdown banner persists | Backing out of a cart is browsing, not abandonment. The hold is released only by explicit removal or TTL expiry. |
| `/checkout/pay` | Return to `/checkout` | |
| **`/checkout/processing`** | **Blocked** — `PopScope(canPop: false)` | A gateway or UPI app-switch is in flight. Popping here manufactures the orphan-payment case in §3.6. |
| **`/checkout/verifying`** | **Allowed, behind a confirm dialog** — *"We'll notify you. Your money is safe."* → `go('/orders')` | §3.6 step 5 requires the user be able to leave verification. This is the deliberate difference from `processing`, and it is not an inconsistency: during `processing` we do not yet have a server-side record to reconcile against; during `verifying` we do. |
| `/checkout/confirmed/:id` | → `/orders/:id` (stack replaced) | Never back into payment |
| `/checkout/notify-primer/:id` | → `/orders/:id` | Skippable by design |
| `/orders/:id/pickup` | → `/orders` | Never back into checkout |
| `/force-update`, `/maintenance` | **Blocked** | Terminal |
| `/auth/otp` | → `/auth/phone`, `redirect` preserved | Number correction must not lose the destination |

**Android predictive back (14+):** every screen declaring `PopScope` must report `canPop`
*accurately* rather than intercepting unconditionally, or the predictive-back animation
desynchronises from actual behaviour. Only `processing` reports `canPop: false`; `verifying` reports
`canPop: true` and handles confirmation in `onPopInvokedWithResult`.

---

## 4.8 Deep links

Path structure is **identical** across all three entry mechanisms, so one resolver serves all:

| Mechanism | Form |
|---|---|
| Custom scheme | `foodapp://` + path *(scheme provisional pending branding, Phase 6)* |
| Android App Links | `https://<domain>/` + path, verified via `assetlinks.json` |
| iOS Universal Links | `https://<domain>/` + path, via `apple-app-site-association` |

**Cold start from push:** payload carries a `route` string → Splash bootstraps → the §4.3 guard
chain runs → `go(route)`. Auth insertion and destination preservation come free from the guard
chain rather than from bespoke notification-handling code. This is the payoff for centralising
guards.

**Warm-start rule — a notification must never navigate away from an in-flight payment.** If the
current route is `/checkout/processing` or `/checkout/verifying`, an incoming deep link is **queued**
and surfaced as an in-app banner instead. Yanking a user out of a payment they are mid-way through,
to show them a different bag, is how you produce a double payment and a support ticket.

**Unresolvable targets** (order not found, belongs to another account, bag withdrawn) resolve to a
scoped not-found state inside the relevant tab — never the global `errorBuilder`, and never a crash.
A stale notification tapped a week later is an ordinary event.

---

## 4.9 Requirements this phase hands to Phase 5

1. Splash owns four outcomes: normal, force-update, maintenance, **unresolved-payment resume** (A3).
2. `/location-setup` must be fully functional under permanent permission denial.
3. `/checkout/verifying` needs an explicit *leave-safely* affordance and its confirm dialog.
4. `/checkout/processing` needs a no-exit state that still feels responsive rather than frozen.
5. Every `:id` route needs a not-found state.
6. `/checkout/notify-primer/:orderId` is a new destination created by A5.
7. Filter and sort sheets are specified as URL-state editors, with the sticky dietary default made
   visible in the UI.
