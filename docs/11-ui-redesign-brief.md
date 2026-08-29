# Mobile App — UI Redesign Brief

Scope: **customer-facing mobile app only** (`surplus_marketplace`, this repo's root). Not the shop app,
not the back office.

## How to use this

This is a checklist of every screen in the app, grouped the way a customer actually moves through it.
For each one:

1. Say what you want changed — a new color, a different layout, "make this feel more premium," a
   reference screenshot/link, whatever. Leave it blank to leave the screen alone.
2. If you want a whole new look (new palette, new type, new spacing rhythm), fill in **Section 2**
   instead of repeating it on every screen.

Hand this back to me (edited, or just tell me the changes out loud) and I'll implement it.

---

## 1. App shell

Bottom navigation, 4 tabs, present on every top-level screen:

| Tab | Icon | Screen |
|---|---|---|
| Discover | storefront | `discover_screen.dart` |
| Orders | receipt (with a badge for active orders) | `orders_screen.dart` |
| Saved | bookmark | `saved_screen.dart` |
| Account | person | `account_screen.dart` |

**Redesign notes:**

---

## 2. Current design system (snapshot)

So changes are relative to something concrete. Full source: `lib/app/theme/app_colors.dart`,
`app_typography.dart`, `lib/design_system/foundations/dimens.dart`.

- **Typeface** — Inter everywhere (one typeface for display/heading/body), via Google Fonts. Tight
  letter-spacing (`-0.01em`). Monospace for order/pickup codes only.
- **Color** — Green primary (`Green.c500` light / `Green.c400` dark) on cream surfaces
  (`Cream.c100`/`c200`) in light mode, dark neutral surfaces in dark mode. Semantic
  success/critical/info/attention roles, each with its own fg/bg/border triplet, defined
  independently per theme (not derived).
- **Spacing** — 4dp base unit, 8dp rhythm (`x1`=4 … `x16`=64).
- **Shape** — Pill-shaped (`radius: 999`) for anything tappable and horizontal (buttons, search,
  chips, nav). Cards use a fixed 12px radius. Bottom sheets round only the top corners, generously
  (32px).
- **This is a prior rebrand** ("Starbucks-inspired") already applied earlier — so you're not starting
  from a generic Flutter default, you're revising a deliberate palette.

**Redesign notes** (new palette / type / spacing, if you want a different system entirely):

---

## 3. Onboarding & Auth

First-run and sign-in — nobody sees the rest of the app until this is done.

| Screen | Purpose |
|---|---|
| `onboarding_screen.dart` | First-run intro/value prop before sign-in |
| `phone_entry_screen.dart` | Enter phone number to start sign-in |
| `otp_verify_screen.dart` | Enter the OTP sent to that phone |
| `profile_setup_screen.dart` | Name/basic profile after first verify |
| `dietary_setup_screen.dart` | Veg/non-veg/egg/Jain preference, used to filter Discover |
| `location_setup_screen.dart` | Set delivery/pickup area |
| `location_primer_screen.dart` | Explains why location access is needed, before the OS permission prompt |

**Redesign notes:**

---

## 4. Discovery

Browsing and picking a surplus bag to buy — the app's main loop.

| Screen | Purpose |
|---|---|
| `discover_screen.dart` | Main feed — bags near you, the home tab |
| `search_screen.dart` | Search by shop/dish name |
| `category_browse_screen.dart` | Browse by category (bakery, restaurant, cafe, etc.) |
| `bag_detail_screen.dart` | One bag's full detail — price, pickup window, what's inside |
| `merchant_profile_screen.dart` | One shop's profile — its other bags, hours, rating |
| `reviews_list_screen.dart` | Full list of a shop's reviews |

**Redesign notes:**

---

## 5. Reserve & Pay

Checkout — from "add to bag" to a confirmed order.

| Screen | Purpose |
|---|---|
| `cart_screen.dart` | What's about to be reserved, with the hold countdown |
| `review_pay_screen.dart` | Final review + payment method before paying |
| `processing_screen.dart` | Payment in flight |
| `verifying_screen.dart` | Payment verification in flight (e.g. UPI) |
| `confirmed_screen.dart` | Order placed — pickup window, order code |
| `payment_failed_screen.dart` | Payment didn't go through |
| `notify_primer_screen.dart` | Explains why notification access helps (pickup reminders), before the OS prompt |

**Redesign notes:**

---

## 6. Orders & Pickup

Managing an order after it's placed.

| Screen | Purpose |
|---|---|
| `orders_screen.dart` | List of active + past orders |
| `order_detail_screen.dart` | One order's detail |
| `pickup_screen.dart` | The pickup screen itself — QR/code shown at the counter |
| `refund_status_screen.dart` | Tracking a refund in progress |
| `report_issue_screen.dart` | Reporting a problem with an order |

**Redesign notes:**

---

## 7. Engagement

Keeping people coming back.

| Screen | Purpose |
|---|---|
| `notifications_screen.dart` | In-app notification inbox |
| `saved_screen.dart` | Bookmarked/favourite shops |
| `rate_review_screen.dart` | Rating a shop after pickup |

**Redesign notes:**

---

## 8. Account

Profile, settings, support, legal.

| Screen | Purpose |
|---|---|
| `account_screen.dart` | Account home — profile summary, links to everything below |
| `edit_profile_screen.dart` | Edit name/photo/details |
| `impact_screen.dart` | This customer's own meals-saved/kg-saved/CO2e stats |
| `app_settings_screen.dart` | General app settings |
| `notification_settings_screen.dart` | Notification preferences |
| `saved_locations_screen.dart` | Manage saved addresses |
| `help_screen.dart` | Support home |
| `faq_topic_screen.dart` | One FAQ topic's detail |
| `contact_screen.dart` | Contact support |
| `about_screen.dart` | About the app |
| `legal_document_screen.dart` | Terms/privacy/legal text |
| `delete_account_screen.dart` | Account deletion flow |
| `logout_dialog.dart` | Log-out confirmation |

**Redesign notes:**

---

## 9. Shared components

These appear across many screens above, so a change here ripples everywhere — worth deciding once
rather than per-screen. Full list: `lib/design_system/components/`.

Notable ones: `app_button.dart` (every button in the app), `bag_card.dart` (the core Discover/Search
card), `hero_pickup_card.dart` (the big pickup-window card), `order_status_chip.dart`,
`dietary_mark_chip.dart`, `countdown_text.dart`, `price_breakdown_list.dart`, `star_rating_input.dart`,
`saved_merchant_card.dart`, `settings_list.dart`.

**Redesign notes:**
