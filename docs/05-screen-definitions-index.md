# Phase 5 — Screen Definitions: Index & Shared Conventions

Status: conventions for approval · Depends on: Phases 1–4 · Consumers: Phases 6, 9

Every screen definition follows the brief's required structure: **Purpose · User goals · Components ·
States · Empty states · Error states · Validation · Accessibility.**

To keep 48 definitions readable, the conventions that apply *everywhere* are defined once here.
Area documents record only what a screen adds or overrides.

---

## Area documents

| Doc | Area | Screens | Status |
|---|---|---|---|
| [05a](05a-onboarding-auth.md) | Onboarding & Auth (+ blocking states) | 11 | for approval |
| 05b | Discovery | 10 | pending |
| 05c | Reserve & Pay | 8 (incl. A5 primer) | pending |
| 05d | Orders & Pickup | 7 | pending |
| 05e | Engagement | 5 | pending |
| 05f | Account | 11 | pending |

---

## C1 — Standard state vocabulary

Every data-bearing screen is one of these. A screen definition names only its **deviations** and its
screen-specific meaning for each.

| State | Meaning | Default treatment |
|---|---|---|
| `initial` | Mounted, no request issued | Skeleton, never a blank frame |
| `loading` | First load in flight | Skeleton matching final layout geometry |
| `refreshing` | Reload over existing data | Existing content stays visible + subtle indicator. **Never** replace loaded content with a skeleton. |
| `loaded` | Data present | |
| `empty` | Request succeeded, zero results | Screen-specific. Always states a *reason* and offers a *next action* (§C4) |
| `error` | Request failed | Screen-specific. Always states what failed and offers retry (§C5) |
| `offline` | No connectivity | Cached content + persistent banner, or the offline empty state |
| `stale` | Cached content past TTL | Content + "as of HH:MM" (per §2.5) |
| `submitting` | Mutation in flight | CTA → in-place spinner, form disabled, **screen not blocked by a modal overlay** |
| `submitError` | Mutation failed | Inline near the cause. Input **never** discarded. |

**Skeletons, not spinners, for first loads.** A skeleton that matches the final layout prevents the
content jump that makes a mid-tier device feel broken. Spinners are for in-place actions only.

**The 400 ms rule.** No loading indicator appears before 400 ms. An indicator that flashes for 150 ms
reads as a glitch. Applies to every `loading` and `submitting` state in the app.

## C2 — Loading choreography

| Duration | Treatment |
|---|---|
| < 400 ms | Nothing |
| 400 ms – 8 s | Skeleton or in-place spinner |
| > 8 s | *"Taking longer than usual"* + retry, without cancelling the in-flight request |
| > 30 s | Fail to `error` with retry |

## C3 — Offline conventions

- **Reads:** serve cache, show a persistent (non-blocking, dismissible-per-session) offline banner.
- **Writes:** blocked, with one exception — saved-merchant and watchlist toggles queue and replay
  (§2.5). Every other mutation shows *"You're offline. This needs a connection."* and preserves input.
- **Never** an offline full-screen takeover when usable cached content exists.

## C4 — Empty-state contract

Every empty state carries three things: **what** is empty · **why** · **one next action.**

A bare "No results" fails all three. The three empty states with real product weight are the
zero-supply Discover state (§3.1a), an empty Orders list, and an empty Saved list.

## C5 — Error taxonomy

| Class | User-facing framing | Retry |
|---|---|---|
| Network / timeout | *"Check your connection"* | Yes, manual |
| Server 5xx | *"Something went wrong on our side"* | Yes, manual + one silent auto-retry with backoff |
| 4xx validation | Specific, inline, at the field | Fix-and-resubmit |
| 401 / token invalid | Silent refresh; on failure → `/session-expired` | Automatic |
| 409 conflict (sold out, hold lost) | **Domain-specific, never generic** — "This bag just went" | Alternatives offered |
| 402 / payment | Never generic. See §3.6. | Per state machine |

**Never surface raw error codes, HTTP statuses, stack traces, or backend messages.** Every error has
authored copy. A correlation ID may be shown in an expandable "Details" affordance for support use.

## C6 — Accessibility baseline (WCAG 2.2 AA target)

Applies to every screen; area docs note only additions.

| Requirement | Rule |
|---|---|
| Touch targets | ≥ 48 × 48 dp, ≥ 8 dp spacing |
| Text contrast | ≥ 4.5:1 body, ≥ 3:1 large text and UI boundaries — **verified in both light and dark themes** |
| Colour independence | Never colour alone. Veg/non-veg marks, selection, and status each carry an icon *and* a text label. Critical in India, where the green-dot/brown-triangle marks are conventional but not accessible. |
| Text scaling | Layouts must survive `textScaleFactor` 2.0 without clipping or overlap. No fixed-height text containers. |
| Screen reader | Every interactive element has a semantic label stating its action. Decorative images use `ExcludeSemantics`. Composite widgets are merged into one node, not read as fragments. |
| Focus order | Follows visual reading order. Modals trap focus and restore it on dismiss. |
| Labels | Every field has a persistent visible label. **Placeholder-as-label is prohibited** — it disappears on input and is not reliably announced. |
| Live regions | Async outcomes announced via `SemanticsService.announce`. `polite` by default; `assertive` reserved for errors and money-state changes. |
| Motion | `MediaQuery.disableAnimations` honoured. No motion-only feedback: error shakes and success animations always have a text equivalent. |
| Timing | Countdowns (cart hold, OTP resend, pickup window) are **informational, never the sole mechanism**. Anything lost to a timer is recoverable in one tap. WCAG 2.2 §2.2.1. |
| Language | `Semantics` locale set correctly so TTS pronounces Indian place names via the right engine |
| Haptics | Confirmations and errors carry a haptic, always paired with visual + semantic feedback |

## C7 — Copy conventions

- Plain English, no jargon, no exclamation marks in error states.
- **Never blame the user** — including where it would be accurate (§3.5).
- Money states are explained with honest timeframes, never spun (§3.8).
- `en_IN` formatting: ₹1,00,000 · 12-hour clock with am/pm · "Today"/"Tomorrow" over dates for
  anything inside 48 hours.
- Time is always visible on any surface touching an order (§3.8).

## C8 — Definition of Done for a screen (Phase 9 gate)

1. All C1 states implemented and reachable in the mock layer
2. Empty and error states authored, not defaulted
3. `textScaleFactor` 2.0 verified
4. Light and dark verified
5. Screen reader traversal verified
6. Widget tests covering: loaded · empty · error · submitting
7. Zero hardcoded strings — all via ARB
8. Zero hardcoded colours, spacing, or type — all via design tokens (Phase 6)
