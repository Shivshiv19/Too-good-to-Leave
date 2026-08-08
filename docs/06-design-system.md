# Phase 6 — Design System: Foundations

Status: for approval · Depends on: Phases 1–5 · Consumers: Phases 8, 9 · Companion: [06b Component Library](06b-component-library.md)

> Amendments: **A21** (§6.2.6) · **A22** (§6.2.5).

Brand identity is unresolved (Phase 1 open items). The system is therefore built so that **a brand
palette is a data change, not a code change.** The placeholder palette below is complete, coherent, and
contrast-checked — usable to ship with, and replaceable in one file.

---

## 6.1 Token architecture

Three layers, with one enforceable rule.

| Layer | Contains | Theme-aware | Example |
|---|---|---|---|
| **1 · Primitive** | Raw values with no meaning | No | `ember.500`, `space.4`, `neutral.900` |
| **2 · Semantic** | Meaning and intent | **Yes** | `color.action.primary.bg`, `color.text.secondary` |
| **3 · Component** | Per-component knobs, only where genuinely needed | Yes | `bagCard.image.radius` |

**The rule: no widget may reference a Layer 1 primitive.** Components consume semantic tokens only.
This is the entire mechanism by which a brand swap, a dark theme, and a future white-label all become
possible — and it is worthless unless enforced, so Phase 8 adds a custom lint that fails the build on a
primitive reference outside the theme definition files.

Corollary: **no hardcoded colour, spacing, radius, duration, or text style anywhere in feature code.**
This is already a §C8 Definition-of-Done gate.

---

## 6.2 Colour

### 6.2.1 The primary colour is not green — deliberately

Three reasons, in order of weight:

1. **Green is the vegetarian mark in India.** A green primary action colour sitting beside a green
   dietary mark degrades a signal that carries religious and ethical weight (Phase 1 §3.1). Reserving
   green for that meaning is a safety decision, not an aesthetic one.
2. **Green is the competitor's identity**, and Phase 1 requires an original visual identity.
3. **Green is the default of every sustainability brand**, so it reads generic in a category where our
   proposition is *good food, much cheaper* — with sustainability as the reason to feel good afterwards,
   not the reason to buy.

The placeholder primary is a **warm terracotta/ember** family: appetising, warm, distinctly Indian in
feel, and unambiguous against both the dietary green and the semantic success green.

### 6.2.2 Primitive ramps

**Ember** (primary)

| Step | Hex | | Step | Hex |
|---|---|---|---|---|
| 50 | `#FFF4ED` | | 500 | `#F25C18` |
| 100 | `#FFE4D3` | | 600 | `#D14509` |
| 200 | `#FFC7A8` | | 700 | `#A9350A` |
| 300 | `#FFA271` | | 800 | `#872D0F` |
| 400 | `#FF7A3D` | | 900 | `#6E2810` |

**Neutral** — warm-tinted rather than blue-grey. Warm neutrals harmonise with the primary and read as
more appetising in a food context; cool greys read clinical.

| Step | Hex | | Step | Hex |
|---|---|---|---|---|
| 0 | `#FFFFFF` | | 500 | `#7D746E` |
| 50 | `#FAF8F7` | | 600 | `#5C544F` |
| 100 | `#F4F1EF` | | 700 | `#423C38` |
| 200 | `#E7E2DF` | | 800 | `#2A2522` |
| 300 | `#D3CCC7` | | 900 | `#1A1614` |
| 400 | `#A89F99` | | 950 | `#0F0D0C` |

**Dark surface tiers** — never `#000000`. Pure black smears on OLED during scroll and produces harsh
contrast at high brightness, which is exactly the condition of the §5d.3 pickup screen.

| Tier | Hex | Use |
|---|---|---|
| base | `#14110F` | Scaffold |
| +1 | `#1C1917` | Cards |
| +2 | `#24201D` | Sheets, dialogs |
| +3 | `#2C2724` | Menus |
| +4 | `#35302C` | Snackbar, tooltip |

**Semantic hues**

| Role | Light | Dark |
|---|---|---|
| Success | `#136F45` | `#4ECB8A` |
| Critical | `#B3261E` | `#FF8A80` |
| Info | `#0F5EA8` | `#7FB6EE` |
| Attention | `#8A5A00` | `#E8B84B` |

### 6.2.3 The button-contrast decision

`ember.500` (`#F25C18`) with white text is approximately **3.4:1** — it **fails** the 4.5:1 body-text
requirement. This is the standard orange-button trap, and most systems ship it broken.

Two ways out: darken the fill to `ember.700` (safe with white text, but muddy and less appetising), or
keep the vibrant fill and use a **near-black label**.

**Decision: primary filled button = `ember.500` fill with a `neutral.900` label.** It keeps the vibrant,
food-appropriate colour and clears 4.5:1 comfortably.

**Flagged for a designer's eye:** dark-on-orange can read faintly "warning-ish" in isolation. I believe
it is right — it is a common and confident pattern, and correctness beats a marginal aesthetic
preference — but this is the single token in the system I would most want reviewed by a visual designer
before launch.

### 6.2.4 Semantic tokens

Abbreviated; the full set lives in code (`lib/core/theme/`).

| Token | Light | Dark |
|---|---|---|
| `surface.base` | `neutral.0` | dark.base |
| `surface.raised` | `neutral.0` | dark.+1 |
| `surface.sunken` | `neutral.50` | dark.base |
| `surface.overlay` | `neutral.0` | dark.+2 |
| `text.primary` | `neutral.900` | `#F0EBE8` |
| `text.secondary` | `neutral.600` | `#B8B0AB` |
| `text.tertiary` | `neutral.500` | `#8F8781` |
| `text.onAction` | `neutral.900` | `neutral.900` |
| `border.subtle` | `neutral.200` | `#332E2A` |
| `border.strong` | `neutral.300` | `#4A443F` |
| `action.primary.bg` | `ember.500` | `ember.400` |
| `action.primary.fg` | `neutral.900` | `neutral.900` |
| `action.secondary.bg` | transparent | transparent |
| `action.secondary.border` | `ember.700` | `ember.300` |
| `action.destructive.bg` | `critical.light` | `critical.dark` |
| `feedback.success.*` | success ramp | success ramp |
| `feedback.critical.*` | critical ramp | critical ramp |
| `feedback.attention.*` | attention ramp | attention ramp |
| `feedback.info.*` | info ramp | info ramp |

**Never pure white text in dark mode.** `#F0EBE8` rather than `#FFFFFF` — pure white on a dark surface
produces halation that makes body text harder to read, not easier.

### 6.2.5 Amendment A22 — dietary marks sit outside the theme system

**Finding.** Building the token layer exposed that dietary marks cannot be theme tokens. They are a
**regulatory-style convention**, not our brand: the Indian convention of a green mark for vegetarian
and a brown/maroon mark for non-vegetarian is what users recognise, and it must look the same in light
mode, dark mode, and under any future brand palette. Theming them would break recognition of a signal
carrying religious weight.

**Change.** Dietary marks are **fixed, non-themeable values** held outside the semantic layer:

| Mark | Fill | Notes |
|---|---|---|
| Vegetarian | `#007A3D` | Filled circle inside a squared outline — the conventional form |
| Non-vegetarian | `#8B1A1A` | Filled triangle inside a squared outline |
| Contains egg | `#C98A00` | **No regulatory standard exists for egg**, so this mark is our own design — which makes its text label mandatory, not merely recommended |
| Jain | Veg mark + explicit "Jain" label | Visually a subset of vegetarian; the label carries the distinction |

**In dark mode these marks render on a light chip**, because `#007A3D` against `#14110F` is low
contrast. The mark keeps its fixed colour; the chip provides the contrast.

**Text label is always mandatory** (§C6) — the marks are conventional, not universal, and not
accessible on their own.

### 6.2.6 Amendment A21 — the QR always renders on a light surface

**Finding.** In dark mode a QR code would naturally invert to light-on-dark. **Many scanners fail on
inverted QR codes**, and merchant-side scanning hardware and camera apps are exactly the population we
cannot control (§3.3). A theme preference must never degrade the one step in the journey that cannot
fail (A1).

**Change.** The QR block (§5d.3) **always** renders dark modules on a light surface, in both themes,
with a defined quiet-zone margin. In dark mode it appears as a light card — a deliberate, visible
exception to the theme.

This pairs with the existing §5d.3 rules: minimum size floor, page scrolls rather than shrinking the
QR, brightness maximised with a manual toggle.

### 6.2.7 The urgency scale avoids the brand hue

The pickup-window states (§5d.3, §5c.1) need three visually distinct treatments. Amber or orange for a
middle "attention" tier would collide with the ember primary and read as brand chrome rather than
warning.

**Resolution — semantics rather than a heat ramp:**

| Window state | Treatment | Why |
|---|---|---|
| `upcoming` | `text.secondary`, neutral | Nothing to act on yet |
| `openNow` | **success** | This is *good* news — you can collect right now |
| `closingSoon` (< 30 min) | **critical** | Genuine urgency, genuine money at risk |
| `closed` | `text.tertiary`, de-emphasised | Terminal |

Three unmistakable hues, none competing with the brand, and the mapping is truthful: "collect now" is a
positive state and should not look like a warning.

**Financial states** get their own mapping, because pending money is not a warning:
`financial.pending` → **info** · `financial.failed` → critical · `financial.success` → success ·
`financial.refunding` → **info**.

### 6.2.8 Contrast validation gate

Every token pair used for text or a UI boundary is validated at **4.5:1** (body) or **3:1** (large text
and boundaries), **in both themes**, as a Phase 9 CI check rather than a manual review. A theme that
cannot be verified automatically will regress.

---

## 6.3 Typography

### 6.3.1 Typeface

**Inter** (variable) for Latin · **Noto Sans Devanagari** as the Devanagari fallback ·
**JetBrains Mono** for codes.

Devanagari coverage is required **in V1 despite the English-only launch** (assumption A12): merchant
names, localities, and landmark strings will contain Devanagari regardless of UI language, and Hindi is
the next locale.

**Line heights are derived from Devanagari metrics, not Latin.** Devanagari needs more vertical room for
the shirorekha and for stacked matras; sizing line height to Latin metrics clips them. Deriving from the
taller script means both render correctly and — importantly — **text does not reflow when the script
changes**, so a Devanagari merchant name cannot break a card's layout.

**Fonts are bundled, not fetched.** A network font request on first paint is a cold-start cost and a
failure mode on the connectivity floor we designed for (Phase 1 §3.6).

**Codes use JetBrains Mono** for unambiguous `0/O` and `1/l/I` — the fallback code (§5d.3) is read aloud
across a counter, and the alphabet itself already excludes ambiguous characters (§2.1).

### 6.3.2 Type scale

Roles, not sizes. Sizes are dp; second figure is line height.

| Role | Size/LH | Weight | Use |
|---|---|---|---|
| `display` | 32/40 | 700 | Blocking states, primer headlines |
| `headline` | 24/32 | 700 | Screen titles |
| `title` | 20/28 | 600 | Section headers, merchant name |
| `titleSmall` | 18/26 | 600 | Card titles |
| `bodyLarge` | 16/24 | 400 | Primary reading text |
| `body` | 14/22 | 400 | Secondary text, descriptions |
| `caption` | 12/18 | 400 | Metadata, timestamps |
| `label` | 14/20 | 600 | Buttons, chips |
| `priceLarge` | 28/36 | 700 | Bag detail price |
| `priceMedium` | 20/28 | 700 | Cart, checkout totals |
| **`codeMono`** | 24/32 | 500 | Fallback code · order code. Letter-spacing `0.15em`, mono |
| **`countdown`** | 16/24 | 600 | **Tabular figures** |

**Tabular figures on countdowns is not a detail.** Proportional digits change width as they tick, so a
countdown visibly jitters and reflows its container — on a screen the user stares at while standing in a
shop. `FontFeature.tabularFigures()`.

**`codeMono` letter-spacing** exists because the code is transcribed by a stranger at arm's length.

### 6.3.3 Scaling

All roles honour `textScaleFactor` to **2.0** without clipping (§C6). No fixed-height text containers.
`codeMono` scales generously. The QR does **not** scale (A21, §5d.3) — the page scrolls instead.

---

## 6.4 Spacing and grid

**Base unit 4 dp, rhythm of 8.**

`space.0` 0 · `space.1` 4 · `space.2` 8 · `space.3` 12 · `space.4` 16 · `space.5` 20 · `space.6` 24 ·
`space.8` 32 · `space.10` 40 · `space.12` 48 · `space.16` 64

| Rule | Value |
|---|---|
| Screen horizontal margin | `space.4` (16) |
| Card internal padding | `space.4` |
| Gap between list items | `space.3` |
| Section spacing | `space.6` |
| **Content max width** | **600 dp, centred** |
| Minimum touch target | 48 × 48 dp, ≥ 8 dp apart (§C6) |
| Sticky action bar | Respects bottom safe-area inset **and** system nav bar |

**The 600 dp content cap** matters because Flutter apps run on tablets and unfolded foldables. Without
it, body text stretches to unreadable line lengths and the bag list becomes a sparse, awkward grid of
full-width rows.

**Radii.** `radius.sm` 8 · `radius.md` 12 · `radius.lg` 16 · `radius.xl` 24 · `radius.full` 999.
Cards use `md`, sheets use `xl` (top corners only), chips use `full`.

---

## 6.5 Elevation

**Light mode — shadow.** Five levels, warm-tinted shadow (`neutral.900` at low alpha, never pure black
shadow, which reads cold against warm neutrals).

| Level | Use |
|---|---|
| 0 | Flat surfaces |
| 1 | Cards |
| 2 | App bar on scroll, sticky action bar |
| 3 | Bottom sheet, dialog |
| 4 | Snackbar, menu |

**Dark mode — surface lightness, not shadow.** Shadows are invisible on dark surfaces; elevation is
conveyed by stepping up the surface tier (§6.2.2). A dark theme that relies on shadow for hierarchy is
a flat theme.

---

## 6.6 Motion

| Token | Duration | Use |
|---|---|---|
| `instant` | 100 ms | State toggles, chip selection |
| `quick` | 200 ms | Buttons, small transitions |
| `standard` | 300 ms | Sheets, dialogs, page transitions |
| `deliberate` | 500 ms | Success affirmation, celebratory moments |

Easing: `standard` (emphasised ease-in-out) · `decelerate` (entering) · `accelerate` (exiting).

### Reduced motion is a first-class variant, not a fallback

`MediaQuery.disableAnimations` is honoured throughout, with specific substitutions rather than "animation
off":

| Default | Reduced-motion substitute | Source |
|---|---|---|
| Animated success check | Static mark + text | §5c.8 |
| Error shake | Colour + text + announcement | §5a.7 |
| Page slide | Cross-fade | §5a.2 |
| **Skeleton shimmer** | **Static placeholder** | §C1 |
| Countdown pulse at critical | Static critical treatment | §5d.3 |

No state in the app is communicated by motion alone (§C6).

---

## 6.7 Iconography

Outline style · 24 dp grid · 2 dp stroke · consistent optical weight · 48 dp minimum touch target when
interactive.

**Status is never icon-only** (§C6) — every status icon is paired with a text label.

Domain icons needed beyond a standard set: **surprise bag · QR/pickup · pickup window (clock variant) ·
landmark · watch (bell) · FSSAI verified badge · storefront**.

Dietary marks are **not** part of the icon system (A22) — they are fixed regulatory-style marks with
their own rules.

---

## 6.8 Theming implementation

- `ThemeExtension` subclasses carry the semantic token sets — not `ColorScheme` alone, which cannot
  express `feedback.*`, `financial.*`, or the urgency scale.
- Light and dark themes are **two complete token sets**, not one set with runtime derivations. Derived
  dark themes are how you ship an unreadable dark mode.
- Theme switching applies **immediately, without restart and without a flash** (§5f.5 requirement).
- `MaterialApp.themeMode` bound to the persisted setting; `system` is the default.
- Dietary marks and the QR surface (A21, A22) are theme-invariant by construction, not by convention.
- **Custom lint fails the build** on any primitive reference or hardcoded style outside
  `lib/core/theme/` (§6.1).

---

## 6.9 Open

**Brand identity remains unresolved** — name, wordmark, logo, and final palette. The placeholder ember
palette is coherent and shippable; substituting a brand palette means editing the Layer 1 ramps and the
`action.*` semantic mappings in one directory, with no component changes.

The one token I would want a visual designer to review before launch is the §6.2.3 primary button
treatment.
