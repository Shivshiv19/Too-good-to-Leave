# Surplus Marketplace — Customer App

A surplus-food marketplace for India. Businesses list food that would otherwise be discarded;
customers reserve and prepay, then collect during a stated pickup window.

Original product. Implements the marketplace concept only — no branding, copy, graphics, or
implementation is taken from any existing product.

> **Status: pre-alpha.** Design phases 1–8 are complete. Implementation is at step 1 of 9 and
> **has not been compiled or tested** — see [docs/09-implementation-log.md](docs/09-implementation-log.md).
> Flutter is not installed on the development machine; that is the current blocker.

---

## Scope

**V1 is the customer mobile application only.** No merchant app, no admin panel, no backend
implementation — the API contracts are designed and every repository runs against a swappable fake, so
the app is fully demoable with no server.

| Decision | Value |
|---|---|
| Offer model | **Surprise Bag only** — contents undisclosed, dietary envelope guaranteed |
| Fulfilment | Pickup only |
| Payment | Prepaid only, UPI pre-selected |
| Cart | Single merchant |
| Auth | Phone + OTP, with **discovery available anonymously** |
| Locale | English at launch, full i18n scaffolding and `en_IN` formatting from the start |
| Backend | None yet — contracts plus fake repositories |

---

## Documentation

Read in order. Each phase depends on the ones before it, and amendments A1–A24 are recorded where they
were discovered rather than silently folded back.

| Phase | Document |
|---|---|
| 1 | [Business understanding, assumptions, constraints](docs/01-business-understanding.md) |
| 2 | [Information architecture](docs/02-information-architecture.md) |
| 3 | [User journeys](docs/03-user-journeys.md) |
| 4 | [Navigation flow](docs/04-navigation-flow.md) |
| 5 | [Screen definitions — conventions](docs/05-screen-definitions-index.md) · [a](docs/05a-onboarding-auth.md) · [b](docs/05b-discovery.md) · [c](docs/05c-reserve-and-pay.md) · [d](docs/05d-orders-and-pickup.md) · [e](docs/05e-engagement.md) · [f](docs/05f-account.md) |
| 6 | [Design system](docs/06-design-system.md) · [Component library](docs/06b-component-library.md) |
| 7 | [API contracts](docs/07-api-contracts.md) |
| 8 | [Project architecture](docs/08-project-architecture.md) |
| 9 | [Implementation log](docs/09-implementation-log.md) |

51 screens, 41 components, 24 amendments.

---

## The rules that matter most

Four constraints are referenced throughout the codebase and are enforced by lint where possible.
Breaking one is a correctness or trust defect, not a style disagreement.

| Rule | Statement |
|---|---|
| **R1** | **Money is never computed on the client.** The app renders a server-supplied price breakdown. No summing, no tax, no fees. A quantity change asks the server for a new quote. |
| **R2** | **Availability is never read from cache at a mutation boundary.** Cached listings are for browsing; add-to-cart and checkout each revalidate. |
| **R3** | **Payment outcome is never determined by a client callback.** Gateway and UPI callbacks are hints that trigger server verification, never facts. |
| **A1** | **Pickup must work offline.** A window-duration signed token is cached at order confirmation, alongside the rotating QR and a spoken-aloud fallback code. |

Two further invariants live in the domain layer:

- A pickup window must close **strictly before** the food's safe-consumption deadline (FSSAI).
- A customer's dietary setting is an **acceptance set**, not a single value — Jain food is a strict
  subset of pure vegetarian, so a pure-vegetarian customer can eat a Jain bag (amendment A7).

---

## Architecture

Clean Architecture, three layers, feature-first modules. `presentation` never imports `data`; concrete
repositories bind only at the composition root, which is what makes the fake/HTTP swap a configuration
change. Riverpod for state and DI, with the payment and order state machines modelled as explicit
sealed unions so the money paths are rigorous where the rest of the app can be flexible.

See [Phase 8](docs/08-project-architecture.md) for the layout, dependency rules, package rationale, and
the six custom lint rules that enforce the boundaries.

---

## Getting started

Flutter is not yet installed on this machine. The full bring-up sequence, including the expectation
that the first `dart analyze` will fail, is in
[docs/09-implementation-log.md](docs/09-implementation-log.md#bring-up-sequence).

```bash
flutter --version          # requires Flutter stable, Dart SDK ^3.5.0
flutter pub get
dart analyze
flutter test
```

---

## Naming

`surplus_marketplace` is a working package name. Brand identity is unresolved; the design system is
built on a semantic token layer so substituting a brand palette means editing
`lib/app/theme/tokens/primitives.dart` and the `action.*` mappings — no component changes.
