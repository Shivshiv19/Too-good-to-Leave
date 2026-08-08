# Phase 5e — Screen Definitions: Engagement

Status: for approval · Conventions: [05-index](05-screen-definitions-index.md) · Routes: [Phase 4 §4.2](04-navigation-flow.md)

**Surface reconciliation.** Phase 2 §2.4 listed 5 destinations. They resolve to **3 screens**:

- **Bag watchlist merges into Saved** as a per-item toggle — see amendment **A17**.
- **Review submitted** is a *state* of the review screen, not a route. A dedicated thank-you route adds
  a back-stack entry that lands the user nowhere useful, for content amounting to one line and an
  optional next action.

> Amendments: **A17** (§5e.2).

---

## 5e.1 Notification centre — `/notifications`

**Purpose.** A durable record of time-sensitive events. Push is ephemeral; OS notifications get swiped
away, cleared by a reboot, or lost in a tray of forty others.

This screen carries more weight here than in most apps. The entire supply loop is push-driven (§2.6),
so a user who dismissed a `pickupClosingSoon` alert has **no other trace of it** — and money riding on
it.

**User goals.** Catch up on what was missed; get back to something dismissed by accident.

**Components.** Newest-first list grouped *Today / Yesterday / Earlier* · per-item type icon, title,
body, relative timestamp, unread indicator · tap → deep-link destination · **Mark all read** ·
shortcut to notification settings (§05f).

### Retention and dismissal rules

| Class | Dismissible | Retention |
|---|---|---|
| **Transactional** — `pickupWindowOpening`, `pickupClosingSoon`, `merchantCancelled`, `orderConfirmed`, `paymentFailed`, refund events | **Not while the order is live.** Dismissible once the order reaches a terminal state. | 30 days after terminal |
| **Discovery** — `newBagsNearby`, `watchedMerchantListed` | Freely | **Auto-expire after 24 h** |
| **Prompt** — `rateYourPickup` | Freely | 7 days |

Transactional notices are the record of a financial commitment, so they are not swipe-able into
oblivion while that commitment is open. Discovery notices auto-expire because a *"bags near you"*
notice from three days ago is noise, and a notification centre that accumulates noise stops being read
at all — which would break the one channel this product depends on.

**States.** `loading` · `loaded` · `refreshing` · `empty` · `emptyPermissionDenied` · `stale` ·
`offline` · `error` · `markingRead`.

**Empty states — two, and the distinction matters.**

| Case | Treatment |
|---|---|
| Permission granted, nothing yet | *"No notifications yet"* + what we'll send (bags nearby, pickup reminders) |
| **OS permission denied** | *"Notifications are off — turn them on to get pickup reminders"* + settings deep link |

An empty notification centre while permission is *denied* is actively misleading: the user concludes
nothing happened, when in fact things happened and were never delivered. Given §5c.9 allows declining,
this is a real and reachable state, not an edge case.

**Error states.** Fetch fails with cache → cached list + stale banner. **Stale deep links** — a
notification for a since-withdrawn bag — resolve to a scoped not-found (§4.8), never a crash.

**Validation.** None.

**Accessibility.** Unread state is part of the item's semantic label, **never a coloured dot alone**.
Each item is one merged node stating type, title, and time. **Relative timestamps also expose absolute
time** in semantics — *"Today at 7:42 pm"* — because *"2 hours ago"* is unhelpful to someone returning
after several days, and ambiguous when read aloud. *Mark all read* announces its result.

---

## 5e.2 Saved — `/saved`

**Purpose.** The retention loop. Convert one good pickup into a habit.

Under §5b.8 the highest-value empty state in the app pushes users to **Watch** a merchant. This screen
is where those accumulate, and it is where a burst-supply marketplace earns repeat purchase.

**User goals.** Get back to a shop I trust; know when it has something.

**Components.** List of saved merchants, each card carrying: photo · name · category · distance ·
rating · **live availability state** · **bell toggle** (notify when they list) · overflow → Unsave.
Plus a *Only show shops with bags now* filter.

**Live availability is the entire point.** A saved list that does not say *"2 bags now"* versus *"usually
lists around 8 pm"* versus *"closed today"* is a bookmark folder, and bookmark folders do not drive
retention. Sort order: merchants with live bags first, then by distance.

**States.** `loading` · `loaded` · `empty` · `togglingWatch` (optimistic) · `unsaving` (optimistic) ·
`stale` · `offline` · `error`.

**Empty states.** *"Save shops you like"* + the reason (*"we'll tell you when they have bags"*) +
Discover CTA. Framed as an invitation, not an absence.

**Error states.** Watch or unsave toggle fails → **optimistic rollback** with a brief message (§2.5).
Offline → queued and replayed, per the §C3 exception. **Unsave is undoable** via a snackbar — cheap,
and it prevents the irritating loss of a list built up over weeks.

**Validation.** None.

**Accessibility.** The bell toggle announces its state — *"Notifications on for Sweet Crumb"* /
*"off"* — not merely its presence. Availability state is text, never colour alone. **Unsave lives in an
overflow menu, not a swipe-only action**: swipe-only destructive actions are unreachable by screen
reader and by users with motor impairments. Cards are merged nodes.

### Amendment A17 — the watchlist is not a separate destination

**Finding.** Phase 2 §2.4 listed *Saved merchants* and *Bag watchlist* as two destinations, and
§2.7.2 established `BagWatch` as the reinterpretation of "Favorite items". Specifying both as screens
exposed that they are two lists of largely the same merchants, distinguished by an intent difference
users will not reliably hold in their heads: *"I want to find this again"* versus *"tell me when"*.

Two overlapping lists of the same entities is a well-known source of user confusion — *"why is this
shop in one list and not the other?"* — and it doubles the maintenance surface for a distinction of
marginal value.

**Change.** **Watching implies saving.** One list (`/saved`), with watch as a **per-item bell toggle**.
Enabling watch on an unsaved merchant saves it; unsaving clears the watch. The `BagWatch` domain entity
(§2.1) is unchanged — this is purely a surface consolidation.

**Cost, accepted:** a user cannot receive notifications for a merchant without it appearing in Saved.
That is a marginal preference, and it is a fair price for eliminating a whole destination and a
recurring category of confusion.

**Effect.** Engagement's destination count goes from 5 to 3. `/saved` loses its segmented control.
`/saved/bag/:bagId` (Phase 4 §4.2) remains — it is how a user opens a live bag from a saved merchant's
card.

---

## 5e.3 Rate & review — `/orders/:orderId/review`

**Purpose.** Generate the trust signal a trust-limited marketplace runs on (Phase 1 §3.2), and surface
merchant quality problems early enough to act on them.

**User goals.** Say whether it was good, quickly, and feel heard.

**Entry.** `rateYourPickup` push at T+1 h after `collected`, or from order detail.

**Components.**

| Element | Detail |
|---|---|
| Context | Merchant · bag title · date — so the user knows *what* they are rating |
| **Star rating** | 1–5, required |
| **Tag chips** | **Conditional on the rating** — see below |
| Comment | Optional, ≤ 500 characters |
| **Escalation bridge** | Prominent *Report an issue* when the rating is low |
| Submit | |

**Tag sets are conditional on rating**, because a single neutral set serves neither case:

| Rating | Tags |
|---|---|
| 4–5 | Great value · Fresh · Generous portion · Easy pickup · Friendly staff |
| 1–3 | Not fresh · Too little · Hard to find · Long wait · Not as described |

Asking a delighted user *"what went wrong?"* is jarring; asking an angry one *"what was great?"* is
worse. The rating is captured first precisely so the follow-up can be appropriate.

**The escalation bridge is not a courtesy.** A 1-star review mentioning illness or spoilage must not
merely become public text — it must enter the §5d.6 / A16 escalation path. So a rating ≤ 2, or any
selection of *Not fresh*, surfaces *Report an issue* as a prominent action alongside submission.
Without this, our earliest signal of a food-safety problem lands in a reviews table that nobody is
paged on.

**Phase 7 implication:** review submission may need to spawn a linked `OrderIssue`, so the contract
must support creating both from one user action without a double round-trip.

**States.** `idle` · `ratingGiven` · `submitting` · `submitted` · `error` · `alreadyReviewed` ·
`notEligible`.

`submitted` — inline confirmation stating the *value* of the contribution (*"Thanks — this helps other
people trust Sweet Crumb"*), then auto-return to order detail after ~1.5 s, with an explicit **Done**
for anyone who prefers it. Stating the value is what makes a user review a second time.

**Empty states.** None.

**Error states.**

| Case | Treatment |
|---|---|
| Submit fails | Input retained, retry offered |
| `alreadyReviewed` | Existing review shown **read-only**. **No editing in V1** — editing brings moderation and versioning complexity for marginal benefit. Recorded as a deliberate limitation. |
| `notEligible` | Order not `collected` → plain explanation + route back. One review per collected order (§2.1). |

**Validation.** Rating required · comment trimmed, ≤ 500 characters.

**No client-side profanity filtering.** It is locale-specific, error-prone in a multilingual market,
and censoring a legitimate complaint is a worse failure than publishing a rude one. Moderation belongs
server-side.

**One client-side check is worth having:** warn — do not block — when the comment appears to contain a
phone number or email address. Users routinely put contact details in reviews without realising the
text will be published publicly.

**Accessibility.**

- **The star rating is five discrete buttons of ≥ 48 dp, not a drag target.** Drag-based star widgets
  are the single most common accessibility failure in review UIs: unusable by screen reader and
  unreliable for users with motor impairments. Announced as *"Rate 3 of 5 stars"*.
- Tag chips use toggle semantics with state announced.
- Character counter is a polite live region.
- Submission outcome announced assertively.
- **The rating requirement is announced**, not merely enforced by a silently disabled button — a
  screen-reader user must be told what is missing.

---

## Handed to Phase 6

New design-system requirements: **notification list item** with unread treatment and type iconography ·
**saved merchant card** with live-availability state and inline bell toggle · **availability state
badge** (three variants) · **star rating input** (discrete buttons, not a drag target) · **conditional
tag chip set** · **undo snackbar** · **inline confirmation** with auto-dismiss and reduced-motion
variant · **escalation bridge** treatment (visually distinct from both error and CTA).
