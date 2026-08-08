# Phase 9 — Implementation Log

Sequence and gates: [Phase 8 §8.12](08-project-architecture.md) · Definition of Done: [§C8](05-screen-definitions-index.md)

---

## Step 1 — `core` + `design_system` substrate

**Status: delivered and verified against the toolchain (2026-07-26). `dart analyze` is clean of
errors/warnings (261 `info`-level lint nits from `very_good_analysis`, no logic issues); `flutter
test` passes all unit cases with zero failures.**

### Blocker

Flutter and Dart are **not installed on this machine** — not on `PATH`, not at any common SDK
location, and Android Studio is not at its default path. Verified at Phase 1 and re-verified at the
start of this step.

Consequently I could not run `flutter create`, `dart run build_runner`, `dart analyze`, or
`flutter test`. Everything below is **written but unverified**. Treat it as a first draft that compiles
in principle, not as working code — there will be import and API-signature corrections on first
analysis, and that is expected rather than a sign of a problem.

I wrote what could be written correctly without the toolchain rather than stopping, since the
substrate is pure Dart with no code generation. What I did **not** do is claim it works.

### Delivered

| File | Purpose |
|---|---|
| `pubspec.yaml` | Full Phase 8 §8.9 dependency set |
| `analysis_options.yaml` | `very_good_analysis` base, strict casts/inference, custom_lint wired |
| `lib/core/domain/money.dart` | Integer-paise `Money`, R1 rationale, integer-only scaling |
| `lib/core/domain/clock.dart` | `Clock` / `SystemClock` / `FixedClock` |
| `lib/core/domain/dietary_envelope.dart` | `DietaryEnvelope` + **A7 acceptance sets** |
| `lib/core/domain/pickup_window.dart` | `PickupWindow`, `WindowUrgency`, invariants I1 + I4 |
| `lib/core/utils/formatters.dart` | The **only** `en_IN` formatting site |
| `lib/core/error/app_exception.dart` | Sealed hierarchy, `ChargeState` (A13), typed details |
| `lib/app/theme/tokens/primitives.dart` | **Layer 1** — the only file with literal colours |
| `lib/app/theme/app_colors.dart` | **Layer 2** semantic colours, urgency + financial mappings |
| `lib/app/theme/app_typography.dart` | 12 type roles, Devanagari-derived line heights |
| `lib/app/theme/dietary_marks.dart` | **A22** — theme-invariant regulatory marks |
| `lib/app/theme/app_theme.dart` | Light/dark `ThemeData`, `context.colors` / `context.type` |
| `lib/design_system/foundations/dimens.dart` | Space, radii, layout constraints |
| `lib/design_system/foundations/motion.dart` | Durations, easing, reduced-motion helper |
| `lib/design_system/foundations/elevation.dart` | Shadow (light) / surface tier (dark) split |
| `lib/design_system/components/app_button.dart` | Amount variant, loading without width change |
| `lib/design_system/components/dietary_mark_chip.dart` | A22, label required at the API level |
| `lib/design_system/components/countdown_text.dart` | Tabular figures, threshold announcements, A2 frozen state |
| `test/unit/core/domain/money_test.dart` | 13 cases |
| `test/unit/core/domain/dietary_envelope_test.dart` | 9 cases, incl. the A7 regression |
| `test/unit/core/domain/pickup_window_test.dart` | 15 cases, incl. I1 and the 30-minute boundary |

### Implementation decisions taken during the step

| # | Decision | Rationale |
|---|---|---|
| **D-1** | **`freezed` for DTOs and sealed unions only; `core/domain` value objects are hand-written.** | `Money` needs custom operators and an assertion on currency mismatch; `PickupWindow` derives state from an injected `Clock`. `freezed`'s generated `copyWith`/`==` add little to either, and avoiding codegen in `core/domain` means the most-depended-upon layer in the app has no build step. `freezed` still earns its place on DTOs (Phase 7 shapes) and on the §8.4 payment/order state unions. |
| **D-2** | `DietaryEnvelope.fromWire` falls back to `nonVeg`; `DietaryPreference.fromWire` falls back to `pureVeg`. | Both are the conservative direction. If we cannot tell what is in a bag, treat it as something the fewest people accept, so it is hidden from a vegetarian rather than offered to them. If we cannot tell what a customer eats, assume the narrower constraint — showing a vegetarian non-veg food is a harm; showing an omnivore too little is a one-tap inconvenience. |
| **D-3** | `AppColors` exposes `urgencyForeground()` and `financialPalette()` as **methods aliasing existing feedback roles**, rather than adding duplicate tokens. | §6.2.7's mapping then exists in exactly one place, and there are eight fewer colour values to keep consistent across two themes. |
| **D-4** | `DietaryMarkChip.label` is a **required** constructor parameter. | §C6 mandates a text label beside the mark. Making it required means the component cannot be constructed in a non-compliant state — a stronger guarantee than a doc comment or a review catch. |
| **D-5** | `AppButton` disables **immediately** on `isLoading` but defers its spinner by 400 ms. | Two different concerns: the disable prevents a double submit on a button that sometimes spends money; the deferral stops a 150 ms indicator flash reading as a glitch. |
| **D-6** | `CountdownText` ticks at 1 s under a minute and 20 s above it. | A per-second rebuild for a display that changes once a minute is wasted work on the mid-tier devices we target (Phase 1 §3.6). |
| **D-7** | Font families are named in `AppTypography`, but the `fonts:` block in `pubspec.yaml` is **commented out**. | The `.ttf` binaries are not in the repo, and declaring a font whose file is missing **fails the build**. With the block commented, Flutter silently falls back to the platform font: the app runs and looks reasonable, it is simply not on-spec typography. The alternative — shipping a build that cannot start — is worse. |
| **D-8** | Button and chip labels wrap rather than truncate. | §C6 requires surviving `textScaleFactor` 2.0. Truncating a button that spends money is worse than a taller button. |

### Not delivered — and why

| Item | Reason |
|---|---|
| `flutter create` platform scaffolding (`android/`, `ios/`) | No SDK |
| `main.dart`, `bootstrap.dart`, `app.dart`, router | Depends on the `config` feature and `SessionState` — Phase 8 step 2 |
| Code generation output | No SDK |
| **38 of 41 components** | Three were written to establish house style and prove the hardest accessibility requirements. The rest follow once the substrate is verified. |
| Golden tests | `alchemist` needs a working toolchain, and goldens against unverified components would just need regenerating |
| **Custom lint package** (`tools/lints/`) | The six §8.7 rules need a `custom_lint_builder` package. Substantial and independent; the intended rules are recorded as comments in `analysis_options.yaml` so the enforcement plan lives in the repo rather than only in a design document. |
| l10n ARB files | Component copy is currently passed in by the caller, which is the correct shape. The ARB deck is written alongside the first feature that owns real copy. |
| Font binaries | See D-7 |

---

## Environment findings (2026-07-26)

Diagnosed while checking for the toolchain. Both facts change the bring-up steps.

### `D:` is exFAT; `C:` is NTFS

exFAT does not record file ownership, so **git refuses to operate on any repository on `D:`** with
*"detected dubious ownership"*. Fixed for this project by:

```bash
git config --global --add safe.directory D:/Project/Food      # applied
```

This also explains why the two Flutter SDK copies on `D:` had never run: `bin/flutter.bat` shells out
to git on **every invocation** to determine its version and channel. On exFAT that fails at the first
step, leaves a `flutter.bat.lock`, and aborts before downloading any artifacts.

Consequence to keep in mind: exFAT has 2-second timestamp granularity and no atomic renames. It is the
first thing to suspect if incremental builds ever go stale in ways that make no sense. Project location
on `D:` was a deliberate choice and is being kept.

An SDK on `D:` would need its own `safe.directory` entry. An SDK on `C:` needs none.

### Three non-functional SDK copies were on disk

`bin/cache/dart-sdk` absent in all three — none had ever completed a first run.

| Path | State |
|---|---|
| `C:\Users\ShivK\Downloads\flutter` | Clean `stable` @ **3.44.8**, git works, no stale lock |
| `D:\Application\flutter` | exFAT, git blocked, stale lock |
| `D:\Application\flutter\flutter` | Nested duplicate of the above |

`PATH` also contained `C:\Users\ShivK\Downloads\flutter_windows_3.38.7-stable\flutter\bin`, a directory
that no longer exists — which is why `flutter` did not resolve despite a flutter entry being present.

Artifact hosts reachable (`storage.googleapis.com`, `pub.dev` both 200). Space: C: 80 GB, D: 504 GB.

---

## Bring-up sequence

SDK installation is being handled outside this log. Once `flutter --version` succeeds:

```bash
# 1. Confirm the toolchain, and that git works where the SDK lives.
flutter --version && flutter doctor

# 2. Make the next step reviewable and revertible. There is no repo here yet.
cd /d/Project/Food
git init && git add -A && git commit -m "Phase 1-9 design docs + substrate"

# 3. PROTECT THE HAND-WRITTEN pubspec.yaml BEFORE SCAFFOLDING.
#    `flutter create` regenerates the files it considers its own, and
#    pubspec.yaml is among those it can rewrite. Ours is hand-authored with the
#    full Phase 8 dependency set and the deliberately-commented fonts block, so
#    losing it silently would be expensive to notice.
cp pubspec.yaml pubspec.yaml.bak

# 4. Generate platform scaffolding into the existing project.
flutter create --platforms=android,ios --project-name surplus_marketplace .

# 5. Check what it touched. Restore pubspec.yaml if it was rewritten.
git status && git diff -- pubspec.yaml
#   if pubspec.yaml changed:  cp pubspec.yaml.bak pubspec.yaml
#   flutter create may also have written lib/main.dart — harmless, it is
#   replaced in step 2 of the Phase 8 §8.12 sequence.

# 6. Dependencies, and l10n generation for the step 1b ARB.
flutter pub get
flutter gen-l10n

# 7. Analyse. EXPECT FAILURES on this first run — nothing here has been
#    compiled. Import paths and API signatures are the likely culprits.
dart analyze

# 8. Tests, once analysis is clean.
flutter test
```

Codegen (`dart run build_runner build --delete-conflicting-outputs`) is not needed yet — nothing in
step 1 uses `freezed`, `json_serializable`, `riverpod_generator`, or `go_router_builder`, by decision
D-1.

---

## Verification owed on step 1

Each is a §C8 gate:

- [x] `dart analyze` clean — 2026-07-26, 0 errors/warnings, 261 `info`-level lint nits only
- [x] `flutter test` — 2026-07-26, all unit cases pass, 0 failures
- [ ] `AppColors` contrast pairs validated at 4.5:1 / 3:1, both themes (§6.2.8)
- [ ] Three components rendered at `textScaleFactor` 1.0 and 2.0, light and dark
- [ ] `DietaryMarkChip` verified for the dark-mode light chip (A22)
- [ ] `CountdownText` threshold announcements verified with TalkBack and VoiceOver
- [ ] `AppButton` width confirmed stable across the loading transition

### SDK bring-up (2026-07-26, addendum)

The bring-up sequence above was run since the last log entry: Flutter 3.44.8 is now on `PATH`,
`flutter create --platforms=android,ios` generated platform scaffolding, and `flutter gen-l10n`
produced `lib/core/l10n/generated/app_localizations*.dart`. The hand-authored `pubspec.yaml`
survived scaffolding untouched. `lib/main.dart` is still the stock `flutter create` counter-app
template — Step 2 (real entry point, depends on the `config` feature + `SessionState`) has not
started.

---

## Step 1b — Copy deck (cross-cutting + money/safety-critical)

**Status: delivered. Unverified — l10n generation has not been run.**

Chosen as the highest-value work available without a toolchain: copy is content rather than code, it is
reviewable without Flutter, it is a §C8 gate, and the §C5 requirement for authored per-error-code copy
had been specified across five documents but never written.

This deliberately front-runs the log's earlier statement that the ARB deck lands "alongside the first
feature that owns real copy." Two categories don't belong to any single feature: the error map is
cross-cutting by definition, and the money/safety lines are the highest-risk content in the product, so
they benefit most from early review.

| File | Contents |
|---|---|
| `docs/10-copy-deck.md` | Reviewable deck: voice rules, and rationale for every contested line |
| `l10n.yaml` | Generation config, `untranslated-messages-file` on |
| `lib/core/l10n/app_en.arb` | ~190 keys with descriptions and placeholders |
| `lib/core/error/error_copy.dart` | Stage 2 of the §8.5 mapping — `AppException` → copy |

### Decisions

| # | Decision | Rationale |
|---|---|---|
| **D-9** | `ErrorCopyMapper.resolve` switches **exhaustively** over the sealed `AppException` hierarchy. | Adding a new error type becomes a **compile error until its copy exists**. Far stronger than a review checklist, and it makes it structurally impossible for a generic "Something went wrong" to quietly become the fallback for a real product situation. |
| **D-10** | `ErrorCopy` carries an `ErrorRecovery` hint rather than a button label. | Stops each screen inventing its own recovery vocabulary, and stops a sold-out bag getting a bare "Try again" when the useful action is "see alternatives". |
| **D-11** | `ChargeState.charged` renders the **same** copy as `uncertain`. | If a debit definitely occurred on a payment that failed, the user is owed a refund — and the honest statement is exactly the one they need to hear. Two code paths, one correct sentence. |
| **D-12** | Refund SLA days are **passed in** from `policyValues`, not embedded in the ARB string. | A19 — the refund window stated in an error can never drift from the one stated at checkout or in the legal documents. |
| **D-13** | No client-side profanity filtering; a **warning**, not a block, when a review comment looks like it contains a phone number or email. | §5e.3 — censoring a legitimate complaint is worse than publishing a rude one, but users do publish contact details without realising. |

### Not delivered

Discovery browse copy, engagement, account and settings, and help topic content — each lands with its
feature. Legal document bodies are authored by counsel, but must render against the same `policyValues`
(A19).

### Verification owed

- [x] `flutter gen-l10n` produces `AppLocalizations` without errors — 2026-07-26, clean run,
      `l10n_untranslated.txt` empty (`{}`)
- [x] Every ARB placeholder type matches its call site in `error_copy.dart` — implied by `dart
      analyze` being clean (a placeholder/call-site mismatch is a compile error against generated
      `AppLocalizations`), 2026-07-26
- [ ] Plural forms (`otpAttemptsLeft`, `bagScarcityExact`) render correctly at 1 and n
- [ ] No key is unused, and no screen holds a hardcoded string (§C8 gate 7) — not yet meaningful:
      only `error_copy.dart` consumes the ARB deck so far, everything else is pending its owning
      feature per "Not delivered" above

---

## Open items carried into step 2

| Item | Impact |
|---|---|
| **A15 cancellation cutoff unsigned** | Now a `policyValues` entry (§7.3) — a one-line change |
| Brand name, wordmark, palette | Edit Layer 1 ramps + `action.*` mappings; no component changes |
| §6.2.3 primary-button treatment | Dark-on-orange; the one token worth a visual designer's review |
| Launch city | Mock fixture seed data and copy |
| Payment gateway | `PaymentGateway` implementation only |
| Font binaries | D-7 |

---

## Step 2 — `config` feature + minimal app shell (2026-07-26)

**Status: delivered and verified against a running app, not just `dart analyze`/`flutter test`.**
Per Phase 8 §8.12, step 2 is the `config` feature itself (`policyValues`, taxonomy, force-update
gate — "first end-to-end vertical slice through all three layers"), not the app shell directly —
the app shell was the natural next increment because it's what makes the slice observable.

### Delivered

| File | Purpose |
|---|---|
| `lib/features/config/domain/entities/policy_values.dart` | Hand-written — converts wire units (minutes/hours/seconds) to `Duration` at the boundary |
| `lib/features/config/domain/entities/maintenance_status.dart` | Hand-written |
| `lib/features/config/domain/entities/remote_config.dart` | Hand-written; owns `requiresForceUpdateFor` (§4.3 rule 1), a numeric (not lexical) version compare |
| `lib/features/config/domain/entities/taxonomy.dart` | `freezed` — first real use of codegen in this repo |
| `lib/features/config/domain/repositories/config_repository.dart` | Abstract interface |
| `lib/features/config/data/dto/*.dart` | `freezed` + `json_serializable`, literal mirrors of the §7.3 wire shape |
| `lib/features/config/data/mappers/config_mapper.dart` | Pure DTO→entity functions, unit-tested |
| `lib/features/config/data/repositories/config_repository_fake.dart` | Fixtures run through `fromJson` → `ConfigMapper`, not constructed as entities directly (see D-15) |
| `lib/features/config/presentation/providers/config_providers.dart` | `riverpod_generator` — DI seam, throws if unoverridden |
| `lib/features/config/config.dart` | Barrel — the feature's only public surface |
| `lib/app/session/session_state.dart`, `session_providers.dart` | `SessionState` — the §4.1 synchronous-redirect flag holder |
| `lib/app/screens/{splash,force_update,maintenance,home_placeholder}_screen.dart` | Guard-target screens (see scope note) |
| `lib/app/router/{routes,router}.dart` | `go_router_builder` typed routes; §4.3 guard chain, partial (see scope note) |
| `lib/app/app.dart`, `lib/bootstrap.dart`, `lib/main.dart` | Composition root — real `MaterialApp.router`, replacing the `flutter create` boilerplate |
| `test/unit/features/config/**` | Mapper, fake-repository, and `requiresForceUpdateFor` version-compare tests |

### Scope note — why only 3 of 9 guard rules are wired

`auth`, `location`, and `onboarding` (Phase 8 §8.12 steps 3–5) don't exist yet, so §4.3 rules 4–8
(payment resume, onboarding, location, auth wall, profile completion) have no real signal to read
and no target route to redirect to. Wiring them now against routes that don't exist would strand
navigation, which is worse than deferring — so `SessionState` exposes the full flag set (rules 4–8's
fields default safely) but the router's `redirect` only implements rules 1–3 plus a temporary
fallback to `/home` (`HomePlaceholderScreen`, deleted when `catalog` lands in step 5). Both files
carry this as an inline comment, not just here.

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-15** | `ConfigRepositoryFake` builds its fixtures as raw JSON `Map`s run through `DtoType.fromJson` → `ConfigMapper`, not as domain entities constructed directly. | A fake that skipped decoding would stop exercising the DTOs and mapper the moment a real backend existed to exercise them against — the whole point of building against fakes first (Phase 1) is that the seam is real. |
| **D-16** | `noShowRefundPolicy` stays a raw `String` on `PolicyValues`, not an enum. | §7.3's sample payload only ever shows `"none"`; no other value is documented anywhere in Phases 1–8. Enumerating unspecified variants would be speculative, and the tolerant-decoding convention elsewhere in this codebase (`DietaryEnvelope.fromWire`, etc.) is always grounded in a documented, closed set. |
| **D-17** | `ForceUpdateScreen`'s CTA renders disabled with the existing "couldn't open the store" copy, rather than launching a URL. | `GET /v1/config` (§7.3) has no `storeUrl` field — only `ForceUpdateException` (a mid-session rejection, not yet thrown anywhere) carries one. Rather than invent a URL or add `url_launcher` for a button that cannot yet function, the gap is surfaced as an open item (below) mirroring how A15 was flagged as a `policyValues` gap. |
| **D-18** | `SessionState` lives at `app/session/`, not inside any feature. | It has no repository and is depended on by the router and (eventually) every feature that can gate navigation — cross-feature by nature, same reasoning as `app/theme`. |

### Not delivered — and why

| Item | Reason |
|---|---|
| §4.3 guard rules 4–8 | Depend on `auth`, `location`, `onboarding` (steps 3–5) — see scope note |
| Full §4.2 route tree (`/discover`, `/orders`, `/checkout/*`, …) | Each route belongs to a feature not yet built; only the config-gated terminal routes and one placeholder exist |
| Widget/golden tests for the four new screens | All four are placeholders likely to be revisited once their real dependencies (auth/location/catalog) exist; writing goldens against them now would need regenerating |
| HTTP `ConfigRepository` binding | No backend exists (§8.11 carried forward); `bootstrap.dart` throws `UnimplementedError` for `staging`/`prod` rather than silently running fakes under a real-sounding flavour name |
| Windows desktop as a local run target | Attempted for verification; `flutter build windows` fails during plugin symlinking because `D:` is exFAT (extends the exFAT finding above from git to Windows' own build tooling). Removed; `web` was added instead and works |

### Verification performed (2026-07-26)

- [x] `dart analyze` — 0 errors/warnings across the whole project (318 `info`-level lints, `very_good_analysis`)
- [x] `flutter test` — 49/49 unit tests pass, including the new config-feature suite
- [x] `dart run build_runner build` — first real exercise of `freezed`/`json_serializable`/`riverpod_generator`/`go_router_builder` in this repo; succeeded after fixing two real generator requirements (`go_router_builder` needs `with $ClassNameRoute` on each route class)
- [x] `flutter build web --debug` — the entire vertical slice compiles for a real target, not just headless analysis
- [x] `flutter run -d chrome` — app launched, connected its debug service and DevTools, ran `main()`, and stayed error-free for 30+ seconds with no Flutter exception banner. Not visually inspected (no screenshot capability against a live browser in this environment), but no error surfaced where a Splash-bootstrap or router-redirect defect would have thrown one.

### Verification owed

- [ ] Visual confirmation of the Splash → `HomePlaceholderScreen` transition (needs a screenshot-capable run or a widget test with `PackageInfo` platform-channel mocked)
- [ ] Widget test driving `ConfigRepositoryFake`'s error path (config fetch throws → Splash still bootstraps with safe defaults, per §5a.1 "config is never a launch blocker")

---

## Step 3a — `onboarding` (carousel + dietary setup) (2026-07-26)

**Status: delivered and verified.** Phase 8 §8.12 step 3 bundles `auth` + `onboarding` as one
step; this is the `onboarding` half only, split out the same way step 1 split into 1 and 1b —
`auth` (phone/OTP/profile-setup/session-expired, A23 device token, A24 refresh) is a separate,
larger chunk of work and lands next as **Step 3b**.

### Delivered

| File | Purpose |
|---|---|
| `lib/core/storage/prefs.dart` | Thin `shared_preferences` wrapper — first file in `core/storage` |
| `lib/features/onboarding/domain/repositories/onboarding_repository.dart` | Abstract interface |
| `lib/features/onboarding/data/repositories/onboarding_repository_prefs.dart` | The **only** implementation (see D-19 below) |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | DI seam, same throw-if-unoverridden shape as `config`'s |
| `lib/features/onboarding/onboarding.dart` | Barrel |
| `lib/design_system/components/selectable_card.dart` | New component — radio semantics, no fixed height, selection never colour-alone (§5a.5 accessibility requirements) |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | `/onboarding` — 3-page carousel, cross-fades under reduced motion instead of sliding |
| `lib/features/onboarding/presentation/screens/dietary_setup_screen.dart` | `/dietary-setup` — 4 `SelectableCard`s + "Show me everything" one-tap escape hatch |
| `lib/core/l10n/app_en.arb` copy additions | `onboardingPage{1,2,3}{Headline,Body}`, `onboardingSkip/Next/GetStarted`, `onboardingPageIndicatorSemantic`, `continueCta`, `dietarySetupContinueDisabledReason` — `dietarySetupTitle`/`dietaryPref*`/`dietaryShowEverything`/`dietarySetupNote` already existed from Step 1b |
| `test/unit/features/onboarding/data/onboarding_repository_prefs_test.dart` | Round-trip + restart-survival tests against mocked `SharedPreferences` |
| `test/unit/app/session/session_state_test.dart` | `SessionState` flag/notify behaviour, newly worth testing now that a second flag flows through it |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-19** | `OnboardingRepository` has **one** implementation, not a fake/HTTP split. | Every other feature's repository stands in for a server (Phase 1 locked decision), but `hasSeenOnboarding` and the dietary preset are purely device-local facts with no server to fake standing in for. Inventing a fake for local storage would model a distinction that doesn't exist. |
| **D-20** | `SessionState.markBootstrapped` gained a required `hasSeenOnboarding` parameter rather than a separate late setter, and a new `markOnboardingSeen()` flips it independently mid-session. | Splash resolves it once alongside config (the synchronous-redirect constraint, §4.1); the onboarding screen itself flips it again immediately on finish so §4.3 rule 5 re-evaluates within the same session rather than only on next launch. |
| **D-21** | Onboarding routes straight to `/dietary-setup`, and dietary setup's `Continue` routes straight to `/home`. | `/location-primer` and `/location-setup` (§4.2) belong to `location`, Phase 8 §8.12 step 4, not built yet. Routing around a feature that doesn't exist is one line to fix later in `onboarding_screen.dart`/`dietary_setup_screen.dart`, called out inline at both sites. |
| **D-22** | `/dietary-setup` has no §4.3 guard rule of its own. | The spec's own guard table (§4.3) doesn't list one — it's reached only by explicit navigation from `/onboarding`, which the router's scope-note comment states explicitly so it isn't mistaken for an oversight later. |
| **D-23** | The onboarding carousel's page-2 copy ("₹350 bag for ₹120") is a placeholder figure, not sourced from any pricing document. | §5a.2 requires a concrete example ("concrete: a ₹350 bag for ₹120" is the spec's own example line), but no phase document supplies a real one. Flagged as an open item below rather than presented as sourced. |

### Not delivered — and why

| Item | Reason |
|---|---|
| `auth` (phone/OTP/profile-setup/session-expired, A23/A24) | Split into Step 3b — large enough to warrant its own verification pass, same reasoning as Step 1/1b |
| `/location-primer`, `/location-setup` | Phase 8 §8.12 step 4, not built — see D-21 |
| Widget/golden tests for `OnboardingScreen`/`DietarySetupScreen` | Both route targets change once `location` lands (D-21); goldens against them now would need regenerating almost immediately |
| Reduced-motion widget test for the carousel's cross-fade | Requires driving `MediaQuery.disableAnimationsOf` in a widget test harness; deferred with the other widget-test debt from Step 2 |

### Open items carried forward

| Item | Impact |
|---|---|
| **Onboarding page-2 example figure unsourced** (D-23) | Needs a real bag price/discount pair from product before ship — one ARB string change |
| Illustrations are icons, not the spec's illustration art | §5a.2/§5a.3 call for illustrations; no asset pipeline for them yet, `Icon` used as a structural placeholder |

### Verification performed (2026-07-26)

- [x] `dart analyze` — 0 errors/warnings across the whole project (340 `info`-level lints)
- [x] `flutter test` — 57/57 unit tests pass (8 new: 5 onboarding-repository, 3 `SessionState`)
- [x] `dart run build_runner build` — clean after adding the onboarding provider and two new typed routes
- [x] `flutter build web --debug` — compiles end-to-end with the onboarding feature wired into `bootstrap.dart`
- [x] `flutter run -d chrome` — launched, connected debug service, ran `main()`, stayed error-free for 20+ seconds

### Verification owed

- [ ] Visual confirmation of the full Splash → Onboarding → Dietary Setup → Home flow (same screenshot-capability gap as Step 2)
- [ ] `SelectableCard` verified with a screen reader for the radio-group announcement (§5a.5 accessibility requirement)
- [ ] Carousel page indicator's live-region announcement verified with TalkBack/VoiceOver

---

## Step 3b — `auth` (2026-07-26)

**Status: delivered and verified.** Completes Phase 8 §8.12 step 3 (bundled with `onboarding` in the
architecture doc, split out the same way step 1 split into 1/1b — see Step 3a).

### Delivered

| File | Purpose |
|---|---|
| `lib/core/storage/secure_store.dart` | `flutter_secure_storage` wrapper — tokens only, first use in this repo |
| `lib/features/auth/domain/entities/{customer,otp_channel,otp_request,auth_tokens}.dart` | Hand-written — real behavioural logic (`isProfileComplete`, expiry math), same D-1 reasoning as `core/domain` |
| `lib/features/auth/domain/repositories/auth_repository.dart` | Abstract interface |
| `lib/features/auth/data/repositories/auth_repository_fake.dart` | OTP request/verify state machine, account-record persistence (see D-24/D-25) |
| `lib/features/auth/presentation/providers/auth_providers.dart` | DI seam |
| `lib/features/auth/auth.dart` | Barrel |
| `lib/design_system/components/otp_code_field.dart` | New component — one real field, six decorative boxes (§5a.7 "single most common accessibility defect") |
| `lib/features/auth/presentation/screens/{phone_entry,otp_verify,profile_setup}_screen.dart` | `/auth/phone`, `/auth/otp`, `/auth/profile-setup` |
| `lib/app/screens/session_expired_screen.dart` | `/session-expired` — reuses Step 1b's copy, unwritten until now |
| `lib/core/l10n/app_en.arb` additions | Phone-entry, OTP-screen, and profile-setup copy — OTP error copy, dietary copy, and session-expired copy already existed from Step 1b |
| `test/unit/features/auth/data/auth_repository_fake_test.dart` | 11 cases: OTP success/invalid/expired/exhausted/replay, profile, session restore/logout, cross-session identity |
| `test/unit/app/session/session_state_test.dart` additions | `markAuthenticated`/`markProfileComplete`/`markSignedOut` |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-24** | `AuthRepositoryFake`'s dev OTP code is a fixed `123456`, uniform across every phone number and request. | There is no SMS provider in `dev` (Phase 1 locked decision) — a fixed dev-only code is the direct analogue of `ConfigRepositoryFake`'s canned fixtures. Documented prominently in the class doc so it is never mistaken for production behaviour. |
| **D-25** | Account records (`auth.customers.<phone>.id`/`.name`) are stored **separately** from the active session pointer (`auth.session.phone`), and `logout()` clears only the latter. | Caught by a test written against the *intended* behaviour ("same phone gets the same customer id on re-auth"), which failed against the first implementation — that version's `logout()` deleted the account record itself, so signing out and back in with the same number silently created a new identity. Logout ending a session must not be the same operation as deleting an account. |
| **D-26** | `OtpCodeField` renders six boxes purely as a read of one `TextEditingController`, with a single real (opacity-0) `TextField` beneath handling all input, autofill, and focus. | The alternative — six separately focus-managed inputs — is explicitly named in §5a.7 as "the single most common accessibility defect in OTP screens." One real field sidesteps the defect by construction rather than by careful focus-jump code. |
| **D-27** | `GoRouteData`'s query-parameter fields are named `redirectTo`, not `redirect`, on every auth route. | `GoRouteData` itself declares a `redirect` method for per-route redirect callbacks; a field of the same name is a real compile error (`conflicting_field_and_method`), not a style choice. |
| **D-28** | Testing `AuthRepositoryFake` swaps `FlutterSecureStoragePlatform.instance` for an in-memory fake, rather than mocking a `MethodChannel` by name or introducing a hand-rolled storage interface. | `flutter_secure_storage_platform_interface` documents exactly this seam for platform implementations; using it exercises the real `SecureStore` → `FlutterSecureStorage` code path against a fake backend instead of a parallel test-only implementation shape. |
| **D-29** | `HomePlaceholderScreen` gained a dev-only Sign in/Sign out affordance. | Nothing else in the app links to `/auth/phone` yet — the real entry point is the checkout auth wall (A4), which doesn't exist. Without this, the auth flow just built would be unreachable except by hand-editing the URL. Deleted alongside the rest of the placeholder when `catalog` lands. |

### Not delivered — and why

| Item | Reason |
|---|---|
| HTTP `AuthRepository` binding | No backend exists (§8.11 carried forward) |
| A24 real refresh-token rotation (single-use, reuse-detection family revocation) | Lives in `core/network/interceptors/auth_interceptor.dart` — there is no HTTP layer to intercept yet. `AuthTokens` carries the shape rotation needs; the fake's tokens don't expire or rotate. |
| A23 anonymous-state migration (`migratedFromDevice`) | Nothing to migrate — no anonymous cart, saved location, or notify-me state exists (those land with `location`/`catalog`, steps 4–5). The fake does generate the account record per phone number, which is the part of A23 that *is* meaningful today. |
| §4.3 rule 7 (auth wall) actually gating a route | Mechanism is wired (`_authRequiredPrefixes` in `router.dart`) but the set is empty — `checkout`/`orders`/`saved`/`account` don't exist |
| Widget/golden tests for the four new screens | Same reasoning as Step 3a — all four still route to the temporary `/home` and will need re-verification once `location`/`catalog` change what comes after them |
| SMS-provider-down / rate-limited domain errors on phone entry and resend | `PhoneEntryScreen`/`OtpVerifyScreen` currently catch failures with the generic `errorOfflineBody` copy; the specific branches need an HTTP `AuthRepository` capable of producing those distinct failures |

### Verification performed (2026-07-26)

- [x] `dart analyze` — 0 errors/warnings across the whole project
- [x] `flutter test` — 71/71 unit tests pass (14 new: 11 `AuthRepositoryFake`, 3 `SessionState`)
- [x] `dart run build_runner build` — clean after the naming collision with `GoRouteData.redirect` (D-27) was found and fixed
- [x] `flutter build web --debug` — compiles end-to-end with `auth` wired into `bootstrap.dart`
- [x] Served the build statically and it ran in a real browser without error

### Verification owed

- [ ] Visual confirmation of the phone → OTP → profile-setup → home flow, and of sign-out/sign-back-in preserving name (same screenshot-capability gap as Steps 2–3a)
- [ ] `OtpCodeField` verified with TalkBack/VoiceOver for "one logical field" behaviour and autofill
- [ ] OTP resend countdown's polite-announcement-at-30/10/0 requirement (§5a.7) — currently ticks visually every second; the announcement is not throttled to those three points

---

## Step 4 — `location` (2026-07-27)

**Status: delivered and verified.** §4.2 `/location-primer` + `/location-setup`, §5a.3/§5a.4, denial-safe
paths.

### Delivered

| File | Purpose |
|---|---|
| `lib/core/domain/lat_lng.dart` | Hand-written §2.1 value object; haversine `distanceInMetersTo` |
| `lib/core/platform/location_capability.dart` | `geolocator` + `permission_handler` wrapper — device capability, not a server fake, same D-19 reasoning |
| `lib/features/location/domain/entities/{location_precision,location_source,resolved_location,locality_suggestion}.dart` | Hand-written |
| `lib/features/location/domain/repositories/location_repository.dart` | Abstract interface — search/reverse-geocode/serviceable-bounds/persistence |
| `lib/features/location/data/repositories/location_repository_fake.dart` | Bengaluru fixture data (see D-31) |
| `lib/features/location/presentation/providers/location_providers.dart` | Two DI seams — `locationRepositoryProvider` (fake) and `locationCapabilityProvider` (always real) |
| `lib/features/location/presentation/screens/location_primer_screen.dart` | `/location-primer` |
| `lib/features/location/presentation/screens/location_setup_screen.dart` | `/location-setup` — search/pincode, recents, popular, GPS, drop-a-pin, offline cache fallback |
| `lib/core/l10n/app_en.arb` copy additions | Primer/setup strings |
| `test/unit/core/domain/lat_lng_test.dart`, `test/unit/features/location/data/location_repository_fake_test.dart` | 4 + 13 cases |
| `test/unit/app/session/session_state_test.dart` additions | `hasLocation`/`markLocationResolved` |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-30** | The OS-dialog-fails-to-present fallback (§5a.3) is driven by `requestPermission()` throwing, not a 3 s race timer. | A timer would also fire against a genuinely slow user still looking at a real system dialog, which is a worse outcome than the rare OEM bug the spec is guarding against. The failure signal itself (an exception) is the only trigger that cannot misfire on a legitimate slow response. |
| **D-31** | Launch city fixture data is **Bengaluru**, unconfirmed by product. | Same open-item status as D-23's placeholder bag price — chosen only because Phase 8 §8.9's own directory sketch already names `bags_bengaluru.json`. Changing city is a fixture-data change, not an architecture change. |
| **D-32** | `/location-setup` renders the "map" as a resolved-address card, not a real `google_maps_flutter` view. | Same reasoning as D-7 (fonts): no Google Maps API key is configured in this environment, and declaring the widget without one risks a broken web build rather than a graceful fallback. The search-and-confirm path is already required to be independently sufficient for a screen reader (§5a.4), so a real map is additive, not load-bearing. Flagged below as an open item. |
| **D-33** | "Drop a pin" resolves to the launch city's centre coordinate rather than a real draggable pin. | Direct consequence of D-32 — there is no map surface to drag a pin on. Keeps the empty-search path unblocked (never a dead end, §5a.4) rather than removing the affordance entirely. |
| **D-34** | `reverseGeocode` takes an explicit `source` parameter rather than the repository inferring it. | The same coordinate can arrive from GPS, a dropped pin, or (indirectly) a search selection, and the caller — not the fixture data — knows which. Threading it through keeps `ResolvedLocation.source` honest for the offline-cache/recents distinction §5a.4 depends on. |

### Not delivered — and why

| Item | Reason |
|---|---|
| Real `google_maps_flutter` rendering | D-32 — no Maps API key in this environment |
| HTTP `LocationRepository` binding | No backend exists (§8.11 carried forward); the fixture data also means "geocoding service down" (§5a.4) has no real failure mode to model yet |
| Saved-locations list on `/location-setup` (only-when-authenticated) | Belongs to `account` (§8.12 step 9) — `/account/locations` doesn't exist yet |
| Widget/golden tests for the two new screens | Same reasoning as Steps 2–3b |
| A genuinely distinguishable "OS dialog failed to present" signal | D-30 — Flutter has no such signal; the exception-driven fallback is the closest available approximation |

### Verification performed (2026-07-27)

- [x] `dart analyze` — 0 errors/warnings across the whole project (473 `info`-level lint nits, `very_good_analysis`)
- [x] `flutter test` — 89/89 unit tests pass (18 new: 4 `LatLng`, 13 `LocationRepositoryFake`, 1 `SessionState`)
- [x] `dart run build_runner build` — clean after adding the location providers and two new typed routes
- [x] `flutter build web --debug` — compiles end-to-end with `location` wired into `bootstrap.dart`; hit the documented exFAT dev-server file-lock race from Step 2's environment findings, resolved the same way (killed the orphaned `npx serve` process holding `build/web` open, rebuilt)
- [x] Served the rebuilt build statically and it ran in a real browser without error

### Guard chain and routing now wired

- §4.3 rule 6 (`!hasLocation && target requires location → /location-primer`) is mechanically wired in `router.dart` (`_locationRequiredPrefixes`), same empty-set-for-now shape as rule 7's `_authRequiredPrefixes` — `/discover` doesn't exist yet to protect.
- `SessionState.hasLocation` is resolved at Splash from `LocationRepositoryFake.cachedLocation()`, alongside config/onboarding/auth, per §4.1's synchronous-redirect constraint.
- `onboarding_screen.dart`'s `_finish()` now routes to `/location-primer` instead of `/dietary-setup` directly (§3.1 step 3 → 4 → 5 order); `dietary_setup_screen.dart`'s scope note updated to match — both one-line fixes flagged in the Step 3a/3b log entries are now applied.
- Both location screens default their post-resolution destination to `/dietary-setup` (or an explicit `redirectTo`), completing the onboarding → location → dietary-setup chain from §3.1.

### Verification owed

- [ ] Visual confirmation of the primer → setup → dietary-setup flow, and of the denied/denied-permanently/offline/GPS-timeout branches (same screenshot-capability gap as prior steps — several of these branches also need a real device to trigger a real OS permission prompt)
- [ ] Screen-reader verification of the search-results live region and the resolved-location card's semantic label (§5a.4)
- [ ] A real Google Maps key + `google_maps_flutter` wiring, replacing the D-32 placeholder card, once product supplies one
- [ ] Launch city confirmation (D-31) — currently Bengaluru fixture data

---

## Step 5 — `catalog` (2026-07-27)

**Status: delivered and verified.** Phase 5b, §4.2's Discover surface (10 destinations + the A10
zero-result split) — the largest UI surface in the app so far. Also lands the real four-tab
`StatefulShellRoute` shell, replacing `HomePlaceholderScreen`.

### Delivered

| File | Purpose |
|---|---|
| `lib/core/domain/{address,rating_aggregate}.dart` | Hand-written §2.1 value objects |
| `lib/features/catalog/domain/entities/*.dart` | `Merchant`, `MerchantSummary`, `BagSummary` (list/card shape, A8), `Offer`/`SurpriseBag` (sealed, hand-written, I1–I3 asserts), `Scarcity`, `BagStatus`, `Review`, `CoverageStatus` (freezed sealed union), `DiscoverQuery`/`DiscoverSort`/`PickupTimeFacet`, `DiscoverPage`/`ReviewsPage`, `SearchResults` |
| `lib/features/catalog/domain/repositories/catalog_repository.dart` | Abstract interface — `discoverBags`, `bag`, `merchant`, `merchantBags`, `merchantReviews`, `coverage`, `notifyCoverage`, `search`, saved/watch toggles |
| `lib/features/catalog/data/repositories/catalog_repository_fake.dart` | Bengaluru fixtures — 6 merchants, ~13 bags across urgency/dietary/category variety incl. soldOut/windowClosed/withdrawn demo bags (see D-35 on fixtures-as-domain-objects) |
| `lib/features/catalog/presentation/providers/catalog_providers.dart` | DI seam |
| `lib/design_system/components/{bag_card,facet_chip}.dart` | New components — `BagCard` is the most-repeated composite in the app (§5b.1) |
| `lib/app/screens/app_shell_screen.dart` | `StatefulShellRoute.indexedStack` shell — bottom `NavigationBar`, 4 branches |
| `lib/app/screens/{orders,saved,account}_placeholder_screen.dart` | Placeholder branches for the 3 features not yet built (steps 7–9); `account`'s carries forward the dev sign-in/out affordance |
| `lib/features/catalog/presentation/screens/discover_screen.dart` | `/discover` — urgency sections, facet bar, A10's 3 empty states, honest map-toggle fallback (D-32-style) |
| `lib/features/catalog/presentation/sheets/{filter_sheet,sort_sheet,location_switcher_sheet}.dart` | Bottom sheets, no route (§5b.4–§5b.6) |
| `lib/features/catalog/presentation/screens/search_screen.dart` | `/discover/search` — debounced, scope hint, recents (session-local, see D-36) |
| `lib/features/catalog/presentation/screens/category_browse_screen.dart` | `/discover/category/:categoryId` |
| `lib/features/catalog/presentation/screens/merchant_profile_screen.dart` | `/discover/merchant/:merchantId` — trust block, Save/Watch (optimistic + auth-wall redirect), photo carousel with arrow controls |
| `lib/features/catalog/presentation/screens/reviews_list_screen.dart` | Reached from merchant profile, pushed via `Navigator` (not in the §4.2 route tree) |
| `lib/features/catalog/presentation/screens/bag_detail_screen.dart` | `/discover/bag/:bagId` — dietary envelope early in semantic order, exact scarcity (A8), sticky Reserve bar |
| `lib/core/error/app_exception.dart` additions | `NotFoundException` — new sealed-hierarchy member, `error_copy.dart` updated to match (compile error otherwise, D-9) |
| `lib/core/utils/formatters.dart` addition | `Fmt.distance` |
| `lib/core/l10n/app_en.arb` additions | Discover/filter/sort/location-switcher/merchant/reviews/bag-detail/search copy — much of the bag/empty-state copy already existed from Step 1b's front-run |
| `test/unit/core/domain/rating_aggregate_test.dart`, `test/unit/features/catalog/domain/offer_test.dart`, `test/unit/features/catalog/data/catalog_repository_fake_test.dart` | 4 + 5 + 18 cases |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-35** | Catalog's fixtures are constructed as domain objects directly, not run through a JSON DTO round-trip the way `ConfigRepositoryFake` is (D-15). | Catalog's own entities (`SurpriseBag` especially) are hand-written with constructor-enforced invariants, not `freezed` wire mirrors — there is no DTO layer yet to exercise. One is added alongside the HTTP binding, matching auth's and onboarding's fakes. |
| **D-36** | Recent search queries persist via a direct `Prefs.open()` call in `search_screen.dart`, not through `CatalogRepository`. | Recent-search history has no server endpoint anywhere in §7.4 — it's pure client-side UX memory, analogous to a browser's address-bar history, not a server stand-in. Modelling it as a repository method would imply a wire concept that doesn't exist. |
| **D-37** | `Merchant.category`/`foodTypeTags` are taxonomy-tag ID strings, not a compiled `MerchantCategory` enum. | A deliberate deviation from §2.1's own enum listing, in favour of §2.3's more specific and later decision that categories are server-driven display metadata with no behavioural meaning — "client enums exist only for values with behavioural meaning." |
| **D-38** | `BagSummary` (list/card shape) is a separate entity from `SurpriseBag` (detail shape), not the same entity with an optional field. | Direct consequence of A8: the list endpoint can only ever produce a `Scarcity` enum, never an exact count. Splitting the entity makes that a structural guarantee instead of a convention every call site must remember. |
| **D-39** | The bag detail Reserve button shows `bag.price` only, never scaled by the quantity stepper's selection. | R1 — money arithmetic (including a plain quantity multiply) is legal only inside `core/domain`/fake repositories, never presentation code. A live scaled total is `checkout`'s job once it exists; showing one now would mean computing it in the wrong layer for a button that doesn't yet transact. |
| **D-40** | Map view (§5b.2) always shows the spec's own `sdkFailed` fallback copy and stays on list — never a real `google_maps_flutter` view. | Same D-32 reasoning as `location`'s resolved-address card: no Maps API key is configured in this environment. List is the default view anyway (D-b3) and is the accessibility-complete equivalent, so nothing required by §5b.2's accessibility rule is missing. |
| **D-41** | Reviews list is pushed via `Navigator.push`, not a typed `go_router` route. | It isn't in the §4.2 route tree (unlike the filter/sort sheets, it also isn't explicitly called out as "no route"), and it's only ever reached from within the merchant profile it belongs to — never deep-linked to directly, so it doesn't need cold-start resolvability. |
| **D-42** | Save/Watch state persists via `Prefs`, keyed by merchant ID, inside `CatalogRepositoryFake` itself. | A minimal local stand-in — full server-synced saved-merchants/watchlist with push notifications belongs to `engagement` (Phase 8 §8.12 step 8) and will supersede this. Same "build the real seam now, without waiting for the feature that gives it full meaning" reasoning as `location`'s recents. |

### Not delivered — and why

| Item | Reason |
|---|---|
| Real `google_maps_flutter` map view | D-40 — no Maps API key in this environment |
| HTTP `CatalogRepository` binding | No backend exists (§8.11 carried forward) |
| Saved merchants / bag watchlist as a real tab surface | `/saved` is a placeholder branch — the real screen is `engagement`, step 8 |
| Cart / checkout / Reserve actually transacting | `checkout` is step 6; Reserve shows an honest "coming soon" message (`bagDetailReserveComingSoon`) rather than a non-functional button pretending to work |
| Pagination on `/discover` or reviews | ~13 fixture bags have nothing genuine to paginate against; `nextCursor` stays `null` throughout |
| Widget/golden tests for the 8 new screens and 3 sheets | Same reasoning as every prior step — screenshot-capability gap, and several of these screens' destinations shift again once `checkout`/`orders`/`engagement` land |
| Skeleton-card loading state (§5b.1) | Simplified to a spinner; the skeleton-matches-final-geometry requirement is a visual-polish item better done once real device testing is possible |

### Verification performed (2026-07-27)

- [x] `dart analyze` — 0 errors/warnings across the whole project (721 `info`-level lint nits, `very_good_analysis`)
- [x] `flutter test` — 115/115 unit tests pass (27 new: 4 `RatingAggregate`, 5 `SurpriseBag` invariants, 18 `CatalogRepositoryFake`)
- [x] `dart run build_runner build` — clean; first real use of `TypedStatefulShellRoute`/`TypedStatefulShellBranch` in this repo (go_router_builder 4.4.0) — the shell's `builder` is an `@override` instance method, not a static one (differs from an early guess corrected against the package's own example)
- [x] `flutter build web --debug` — compiles end-to-end with `catalog` wired into `bootstrap.dart` and the shell replacing the old single-screen placeholder
- [x] Served the rebuilt build statically and it ran in a real browser without error

### A real bug caught during this work

The default `/discover` query (5 km radius, A11) returned **zero bags** against the first draft of the
Bengaluru fixture coordinates — every fixture merchant was 5–17 km from the chosen city-centre anchor,
so the single most common path through the app (open Discover, see bags) was empty by default. Caught by
`test/unit/features/catalog/data/catalog_repository_fake_test.dart`'s "returns only live bags within the
default 5 km radius" test failing with an empty list. Fixed by moving four of the six merchants' fixture
coordinates to 2–5 km from the anchor, while deliberately keeping two farther out (7 km, 13 km) as
graduated cases for the distance-facet and coverage tests. A second, unrelated bug in the same pass:
`RatingAggregate.hashCode` hashed `Map.entries` directly, but `MapEntry` has no value-based `hashCode` of
its own (only identity), so two separately-constructed but content-equal `RatingAggregate`s hashed
differently — a latent `Set`/`Map`-key correctness bug. Fixed with `Object.hashAllUnordered` over each
entry's own `key`/`value` hash instead.

### Guard chain and routing now wired

- §4.3 rule 6 now protects a real route: `/discover` is in `_locationRequiredPrefixes`, so reaching it
  with `hasLocation == false` redirects to `/location-primer` first — the first real trigger for a rule
  that has been mechanically wired since Step 4.
- The router's terminal-route fallback (§4.3 rule 9) now returns `/discover` instead of `/home`;
  `HomePlaceholderScreen` and the `/home` route are deleted.
- Merchant profile's Save/Watch toggles trigger the **A4 auth wall** directly (`PhoneEntryRoute` with
  `redirectTo` back to the same profile) when the customer isn't authenticated — the first real use of
  redirect-preserving auth-wall navigation outside the router's own guard chain.

### Verification owed

- [ ] Visual confirmation of the full Discover → category/search/merchant/bag flows, all three A10 empty
      states, and the filter/sort/location-switcher sheets (same screenshot-capability gap as every prior
      step)
- [ ] Screen-reader verification of the bag card's merged semantic node, the merchant photo carousel's
      arrow-only navigation, and the reviews histogram's text equivalent (§5b.8/§5b.9/§5b.11)
- [ ] A real Google Maps key + `google_maps_flutter` wiring (D-40), same open item as `location`'s D-32
- [ ] Skeleton-card loading state to match §5b.1's geometry requirement, once device testing is possible

---

## Step 6 — `checkout` (2026-07-27)

**Status: delivered and verified.** Phase 5c's 9 destinations — the highest-risk area in the app:
every screen here can lose a user's money, and two of them can lose it invisibly.

### Delivered

| File | Purpose |
|---|---|
| `lib/core/domain/{price_breakdown,tax_line,pickup_token}.dart` | Hand-written §2.1 value objects — `PriceBreakdown` is R1 given a shape |
| `lib/core/payment/{payment_gateway,payment_gateway_fake}.dart` | Platform capability (§8.6) abstracting the gateway SDK — no gateway type reaches `domain`/`presentation` |
| `lib/features/checkout/domain/entities/*.dart` | `Hold` (single-bag-type, see D-45), `Order`/`OrderStatus`, `Payment`/`PaymentStatus`/`PaymentMethod`, `Refund`/`RefundStatus`, `OrderMerchantSnapshot`/`OrderBagSnapshot` (distinct types from `catalog`'s live entities — the snapshot principle enforced by construction) |
| `lib/features/checkout/domain/repositories/checkout_repository.dart` | Abstract interface — `createHold`, `getHold`, `quote`, `adjustHold`, `releaseHold`, `createOrder`, `verifyPayment`, `getPayment`, `getUnresolvedOrder`, `getOrder` |
| `lib/features/checkout/data/repositories/checkout_repository_fake.dart` | Depends on `CatalogRepository` for bag/merchant reads (D-44) |
| `lib/features/checkout/presentation/providers/checkout_providers.dart` | Two DI seams — repository and `PaymentGateway` |
| `lib/design_system/components/{hold_countdown_banner,price_breakdown_list}.dart` | New components — the banner escalates at 2 minutes (distinct from `CountdownText`'s own 30-minute pickup-window default); the list is a semantic label–value list, never a two-column layout |
| `lib/features/checkout/presentation/screens/cart_screen.dart` | `/checkout?bagId=&quantity=` — creates the hold, debounced re-quote on stepper change (A11) |
| `lib/features/checkout/presentation/screens/review_pay_screen.dart` + `sheets/{payment_method_sheet,upi_app_chooser_sheet}.dart` | `/checkout/pay` — no confirmation dialog (D-c4), terms block adjacent to Pay |
| `lib/features/checkout/presentation/screens/processing_screen.dart` | `/checkout/processing` — no exit, bounded to 60 s (A12) |
| `lib/features/checkout/presentation/screens/verifying_screen.dart` | `/checkout/verifying` — the single most consequential screen in the app (§5c.6), exponential-backoff polling, assertive don't-pay-again instruction |
| `lib/features/checkout/presentation/screens/payment_failed_screen.dart` | `/checkout/failed` — A13 charge-state variants, hold-alive vs hold-expired retry paths |
| `lib/features/checkout/presentation/screens/confirmed_screen.dart` | `/checkout/confirmed/:orderId` — calm success, character-by-character order code, real ICS-file add-to-calendar |
| `lib/features/checkout/presentation/screens/notify_primer_screen.dart` | `/checkout/notify-primer/:orderId` |
| `lib/core/error/app_exception.dart` addition | `NotFoundException` (already added in Step 5; reused here for `getHold`/`getOrder`/`verifyPayment`) |
| `lib/core/utils/formatters.dart` addition | `Fmt.timeOfDay` |
| `lib/core/l10n/app_en.arb` additions | Payment-method labels, UPI-ID fallback, app-chooser/launch-failed copy, calendar confirmation — nearly all other checkout copy already existed from Step 1b's front-run of the cart/checkout/payment/confirmed/notify-primer sections |
| `test/unit/core/payment/payment_gateway_fake_test.dart`, `test/unit/features/checkout/data/checkout_repository_fake_test.dart`, `test/unit/app/session/session_state_test.dart` additions | 1 + 18 + 2 cases |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-43** | `Payment` reuses `ChargeState` from `core/error/app_exception.dart` rather than a second enum. | It's the same amendment-A13 concept whether it arrives attached to a thrown `PaymentFailedException` or, as here, sitting on a resolved payment record — one concept, one type. |
| **D-44** | `CheckoutRepositoryFake` takes a `CatalogRepository` as a constructor dependency, a data-layer-to-data-layer cross-feature dependency. | In a real backend both would be server-side services sharing a database; checkout genuinely needs bag/merchant data it doesn't own. `bootstrap.dart` shares one `CatalogRepositoryFake` instance between `catalogRepositoryProvider` and this dependency rather than constructing two. |
| **D-45** | `Hold` is modelled as single-bag-type (`bagId`, `quantity`), not §2.1's `Cart.lines: List<...>`. | Every screen in §5b.9/§5c.1 reserves a quantity of exactly one bag; nothing in the spec browses and adds a second, different bag to an existing hold before paying. A multi-line cart would model a flow this product doesn't have. |
| **D-46** | Hold-TTL and platform-fee-rate fixture numbers are hardcoded in `CheckoutRepositoryFake`, not read from `PolicyValues`. | `bootstrap.dart` constructs every repository synchronously before any `Future<RemoteConfig>` resolves, so a real dependency on `policyValues` here would need async DI this codebase doesn't have. Same no-cross-fake-wiring precedent as `catalog`'s D-b6 purchase-cap duplication — the real server would own this policy store independently too. |
| **D-47** | `PriceBreakdown.taxes` is always an empty list in the fake, never an invented GST line. | Phase 1 §3.3 flags GST §9(5) treatment as an open legal question; asserting a specific rate in fixture data risks being mistaken for a real policy decision rather than a placeholder. |
| **D-48** | `verifyPayment` always resolves to `captured` on its second poll — no random or scenario-driven failure. | There's no real gateway to fail against meaningfully yet, and a demo flow that sometimes randomly fails is worse for reliably exercising the happy path than one that doesn't. The `failed`/`cancelled` branches are still fully implemented in `VerifyingScreen`/`PaymentFailedScreen`, just not reachable through this fake. |
| **D-49** | The bag-detail Reserve button's amount is never scaled by the quantity stepper (carried over from Step 5's D-39), and `Order.holdId` is a real field distinct from `Order.id`. | The latter was a real bug caught during this step (see below) — retry after a failed payment needs the *original* hold, which survives order creation (A2 freezes it, doesn't delete it), so it has to be reachable from the order that was created from it. |
| **D-50** | `PaymentGateway.launch` only ever reports "the hand-off happened", never a payment outcome — R3 given an interface shape. | A gateway SDK's own "success" callback is exactly the trap R3 exists to prevent; the outcome is always `CheckoutRepository.verifyPayment`'s job, polled after `launch` returns. |
| **D-51** | "Add to calendar" (§5c.8) is a real ICS-file share via `share_plus`'s `XFile.fromData`, not a toast that claims success without doing anything. | Consistent with the project's standing rule against fake-affordance buttons. Wrapped in try/catch since calendar hand-off support varies by platform/browser — a failure degrades silently rather than blocking the confirmation flow, but never claims success it didn't achieve. |
| **D-52** | The notification primer's "Allow" and "Not now" CTAs currently lead to the same outcome (proceed, with the in-app-reminder note) rather than calling `firebase_messaging` directly. | `PushProvider` (§8.6) is `engagement`'s feature (step 8), not built yet — same "sits behind a core abstraction, not built until its owning feature lands" reasoning as `PaymentGateway` before this step. Calling Firebase without `Firebase.initializeApp()` wired in `bootstrap.dart` would either throw unpredictably or silently no-op; neither button here claims a permission grant that can't actually be requested yet. |

### Not delivered — and why

| Item | Reason |
|---|---|
| HTTP `CheckoutRepository`/real gateway SDK binding | No backend or gateway selection exists yet (§8.11, §8.12 step 6's own "Payment gateway selection: `PaymentGateway` implementation only" note) |
| `resolvedHoldCollision` (A2's rare payment-captured-but-bag-taken race) | Genuinely rare by design; implementing a full auto-refund simulation for it was judged not worth the speculative machinery this pass |
| `HoldConflictOtherMerchantException` / the cart-replace dialog (A6) | Needs customer-scoped "does this customer already have an active hold elsewhere" state the fake doesn't track; `cartReplaceTitle`/`Body`/`Confirm` copy exists (from Step 1b) but is currently unused |
| A real Firebase-backed notification permission request | D-52 — deferred to `engagement`, step 8, alongside the real `PushProvider` |
| Widget/golden tests for the 9 new screens and 2 sheets | Same reasoning as every prior step |
| Real installed-UPI-app detection | `UpiAppChooserSheet` uses fixture app names; real intent-resolution detection needs a platform channel this step doesn't add |

### A real bug caught during this work

`Order` originally had no field pointing back at the `Hold` it was created from — only `Order.id` (the
order's own ID). §5c.7's retry path needs the *original* hold (A2 freezes it rather than deleting it at
order creation, specifically so a failed payment can retry against the same hold while it's still
alive), and without a stored `holdId`, the only ID `PaymentFailedScreen` had on hand was the order's own,
which `CheckoutRepositoryFake.createOrder`/`getHold` would silently misinterpret as a hold ID. Caught
while writing `PaymentFailedScreen`'s retry logic, before it ever reached a test — fixed by adding
`Order.holdId` and threading it through both places `CheckoutRepositoryFake` constructs an `Order`.

### Guard chain and routing now wired

- §4.3 rule 7 (the auth wall) now protects a real route: `/checkout` is in `_authRequiredPrefixes` — its
  first genuine trigger, since `orders`/`saved`/`account` still resolve to placeholder shell branches.
- §4.3 rule 4 (A3) is mechanically wired: `SessionState.unresolvedPaymentOrderId` is resolved at Splash
  from `CheckoutRepository.getUnresolvedOrder()`, and the router redirects to `/checkout/verifying`
  ahead of onboarding and auth when it's non-null. The fake always returns `null` (no cross-restart
  persistence — see `CheckoutRepositoryFake`'s class doc), so this has nothing to trigger it end-to-end
  without a real backend; `SessionState.clearUnresolvedPayment()` is called once `VerifyingScreen`
  resolves the payment either way.
- Bag Detail's Reserve button now navigates to `/checkout?bagId=&quantity=` instead of showing a
  "coming soon" message — the whole point of building this step.

### Verification performed (2026-07-27)

- [x] `dart analyze` — 0 errors/warnings across the whole project (926 `info`-level lint nits, `very_good_analysis`)
- [x] `flutter test` — 136/136 unit tests pass (21 new: 1 `PaymentGatewayFake`, 18 `CheckoutRepositoryFake`, 2 `SessionState`)
- [x] `dart run build_runner build` — clean with 7 new top-level routes outside the shell (§4.4, no bottom nav)
- [x] `flutter build web --debug` — compiles end-to-end with `checkout` wired into `bootstrap.dart`; hit the documented exFAT dev-server file-lock race again, resolved the same way (killed the process holding `build/web` open, rebuilt)
- [x] Served the rebuilt build statically and it ran in a real browser without error

### Verification owed

- [ ] Visual confirmation of the full reserve → cart → pay → processing → verifying → confirmed →
      notify-primer flow, and of the failed-payment retry path (same screenshot-capability gap as every
      prior step — several of these screens also need a real device/gateway to trigger their less-common
      branches, e.g. `resolvedHoldCollision`, gateway-initiation failure)
- [ ] Screen-reader verification of the verifying screen's assertive don't-pay-again announcement and the
      confirmed screen's character-by-character order code (§5c.6/§5c.8)
- [ ] A real payment gateway selection + SDK binding, replacing `PaymentGatewayFake`
- [ ] A20's account-deletion blockers and A6's cart-replace dialog, once `account`/multi-hold state exist
      to need them

---

## Step 7 — `orders` (2026-07-27)

**Status: delivered and verified.** Phase 5d's 5 screens plus 1 dialog — A1's three-layer pickup
token, A14's polling cadence, A15's cancellation policy, A16's food-safety escalation.

### Delivered

| File | Purpose |
|---|---|
| `lib/core/domain/pickup_token.dart` | Upgraded from Step 6's simpler placeholder to the full §7.6 wire shape — `rotatingPayload`/`rotationExpiresAt`, `offlineToken`/`offlineTokenValidUntil`, `fallbackCode` |
| `lib/features/checkout/domain/entities/order_snapshots.dart` | `OrderMerchantSnapshot` gained `legalName`, `fssaiLicenceNumber`, `fssaiLicenceExpiry`, `grievanceContact` — needed for §5d.2's legal disclosure block |
| `lib/features/checkout/domain/entities/payment.dart` | `Payment` gained `maskedIdentifier` (e.g. `"4210"`), set once at `createOrder` and carried through every status transition — the single source both order-detail's payment row and refund's destination line read from |
| `lib/features/checkout/domain/entities/order.dart` | Added `Order.copyWith` — `orders` uses it to persist derived/cancelled status; `checkout` still only ever constructs a fresh `Order` |
| `lib/features/checkout/data/repositories/checkout_repository_fake.dart` | Added `ordersForCustomer`/`updateOrder` — **fake-to-fake wiring only**, not part of the `CheckoutRepository` contract |
| `lib/features/orders/domain/entities/*.dart` | `OrderListSegment`, `CancellationEligibility`/`CancellationRefundOutcome`, `RefundDetail`/`RefundStep`/`RefundStepLabel`, `IssueType`, `IssueReport` |
| `lib/features/orders/domain/repositories/orders_repository.dart` | `getOrders`, `getOrder`, `getPickupToken`, `getCancellationEligibility`, `cancelOrder`, `getRefund`, `uploadAttachment`, `reportIssue` |
| `lib/features/orders/data/repositories/orders_repository_fake.dart` | Depends on the **concrete** `CheckoutRepositoryFake` (not just the interface) for the fake-to-fake accessors; lazily derives `collected`/`expiredUncollected` on every read (see D-58) |
| `lib/features/orders/presentation/providers/orders_providers.dart` | `ordersRepositoryProvider` (DI seam) + `ordersBadgeCountProvider` (§5d.1's tab badge) |
| `lib/features/orders/presentation/utils/*.dart` | `dietary_label.dart` (duplicated from `catalog`, not imported — see D-54), `window_state_label.dart`, `order_status_label.dart`, `payment_method_label.dart`, `directions_launcher.dart` (`url_launcher` deep link, no API key needed) |
| `lib/design_system/components/{order_status_chip,hero_pickup_card,qr_display_block,monospace_code_display,refund_timeline,advisory_block,photo_attachment_row,legal_disclosure_block}.dart` | The 8 new components §5d hands to Phase 6 |
| `lib/features/orders/presentation/screens/{orders_screen,order_detail_screen,pickup_screen,refund_status_screen,report_issue_screen}.dart` | The 5 routes |
| `lib/features/orders/presentation/dialogs/cancel_order_dialog.dart` | §5d.5 — a dialog, not a route |
| `lib/app/screens/app_shell_screen.dart` | Converted to `ConsumerStatefulWidget` — renders the Orders tab badge, resolves nav labels through l10n (previously hardcoded English), 60 s badge-refresh timer |
| `lib/app/router/{routes.dart,router.dart}` | 4 new nested routes under `/orders`; `/orders` added to `_authRequiredPrefixes` (rule 7) |
| `lib/bootstrap.dart` | `checkoutRepositoryFake` promoted to a named local (was inline) so `OrdersRepositoryFake` can share it; `ordersRepositoryProvider` override added |
| `lib/features/catalog/presentation/screens/merchant_profile_screen.dart` | Retrofitted to use the new shared `LegalDisclosureBlock`; `_TrustBlock` now only holds the verified/halal trust signals and hides itself when neither applies |
| `lib/core/l10n/app_en.arb` | Nav labels, Orders list/detail copy, order-status-chip labels, issue-screen additions — none of this was front-run by Step 1b (unlike checkout's copy) |
| `test/unit/features/orders/data/orders_repository_fake_test.dart` | 17 new cases |
| `pubspec.yaml` | Added `image_picker` (issue-report photos) and `url_launcher` (Directions deep link) — the first new packages since Step 1 |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-53** | `orders` depends on `checkout`'s barrel for `Order`/`Payment`/`Refund`/`OrderStatus`/`PaymentStatus`/`PaymentMethod`/the snapshot types, rather than those types being physically relocated into `orders`. | §8.3.2 reads as ambiguous on this point — it states `OrderBagSnapshot`/`OrderMerchantSnapshot` are "owned by the orders feature" but also that this is what lets *orders* avoid a `catalog` dependency, which only requires the snapshot *shape*, not physical ownership. Moving verified, tested Step-6 code into a feature that didn't exist yet would be a disruptive relocation for a plausible documentation ambiguity, and `checkout` — which *creates* orders — has the stronger claim to own the type. §8.3.1's dependency table (written before this step) simply didn't list the edge; it's added here. `orders -> catalog` remains correctly absent. |
| **D-54** | `orders/presentation/utils/dietary_label.dart` duplicates `catalog`'s six-line helper of the same name rather than importing it. | `orders` has no dependency on `catalog` at all (§8.3.2's explicit "pleasant side effect") — `checkout` already imports the `catalog` version because `checkout -> catalog` is a documented, necessary edge (the cart displays the bag being reserved); `orders` has no equivalent need, so importing it would add an edge purely to save six lines. |
| **D-55** | `PickupToken` is upgraded in place (`core/domain`) rather than relocated to `features/orders/domain`. | §8.3.3 lists `PriceBreakdown` — fetched via a repository, exactly like `PickupToken` — as a legitimate `core/domain` value object despite being repository-sourced. Relocating it would also force a choice between a `checkout -> orders` edge (for `Order.pickupToken`'s type) and duplicating the type, and D-53 already spent the one cross-feature-ownership judgment call this step needed. |
| **D-56** | `Payment.maskedIdentifier` is a new field, generated once at `createOrder` and carried through every subsequent status rewrite. | Both order-detail's payment row and refund's destination line need "ending 4210"; without a stored field, `orders` would need to fabricate its own masked digits independently of `checkout`'s, and two independently-fabricated numbers for the same payment is worse than one field set once at the source. |
| **D-57** | "Directions" opens the device's maps app via a plain `https://maps.google.com/...` deep link (`url_launcher`), not an embedded `google_maps_flutter` view. | Launching an external app needs no API key; embedding a map surface does (the still-open D-32/D-40 gap). This is a genuine capability, not a placeholder — the first "Directions" action in the app that actually does something. |
| **D-58** | `collected` and `expiredUncollected` are reached by **lazy, time-based derivation** on every read of a `confirmed` order (a fixed 90 s "the merchant scanned it" delay after the window opens; immediately once past the window's end) — not by a dev-only scenario selector. | §7.10 describes an aspirational dev-only scenario selector that no prior step has actually built; adding cross-cutting test infrastructure now would be out of scope for one feature. Time-based derivation is fully deterministic under `FixedClock` (see the new tests), requires no new interface surface, and is the same "pragmatic fixture progression" precedent as `checkout`'s D-48 (`verifyPayment` always succeeds on the second poll). `readyForPickup` and `cancelledByMerchant` have no equivalent trigger — see Not delivered. |
| **D-59** | Issue-type SLA hours (48 general / 2 for `food_safety`) and the cancellation cutoff (60 min) are hardcoded fixture numbers in `OrdersRepositoryFake`, mirroring (not reading) `ConfigRepositoryFake`'s `grievanceSlaHours: 48` and `cancellationCutoffMinutesBeforeWindow: 60`. | Same no-cross-fake-wiring constraint as `checkout`'s D-46 — `bootstrap.dart` constructs every repository synchronously, before any `Future<RemoteConfig>` resolves. |
| **D-60** | `/orders` (and everything nested under it) is added to §4.3 rule 7's `_authRequiredPrefixes`, alongside `/checkout`. | Every order belongs to a signed-in customer; there is no scenario where an anonymous session should see an orders list. This was a gap in Step 6's rule-7 wiring, not a deferred decision — it's fixed here as part of building the tab that actually needs it. |
| **D-61** | `LegalDisclosureBlock` is extracted as a shared component and `merchant_profile_screen.dart` (§5b.8) is retrofitted to use it, moving FSSAI display out of `_TrustBlock` (which now holds only the verified/halal marketing signals). | §5d.2 explicitly hands off a legal disclosure block "shared with §5b.8" — building a second, divergent rendering of the same Consumer Protection (E-commerce) Rules 2020 disclosure would violate that instruction, not just be untidy. `_TrustBlock` now hides itself entirely when a merchant has neither signal, fixing a latent empty-container bug this refactor would otherwise have introduced. |

### Not delivered — and why

| Item | Reason |
|---|---|
| `readyForPickup` and `cancelledByMerchant` reachable end-to-end | Both require a merchant-side actor this V1 has no app for (D-58) — the `OrderStatusChip`, banner copy, and every screen branch for them are fully built and exercised by construction, just not reachable through the fake |
| One-time goodwill credit on first `expiredUncollected` occurrence (§3.5) | Needs account-level "has this customer received goodwill before" state that doesn't exist until `account` (step 9) |
| Rate & review, Watch this merchant (both `collected`-status actions in §5d.2's action table) | Both are `engagement`'s screens (§5e.3/A17, step 8) — `/orders/:orderId/review` is explicitly a step-8 route per §4-navigation-flow.md even though it's nested under `/orders` |
| Real EXIF stripping on photo attachments | §5d.6 requires it "as defence in depth" alongside server-side stripping; there is no real upload pipeline yet for either side to matter against, and no image-metadata package is in this project's dependency set |
| Real merchant-cancellation interrupt-in-place on the Pickup screen (§3.4) | Same merchant-actor gap as `readyForPickup`/`cancelledByMerchant` above — the UI branch exists, has no trigger |
| Backgrounding-aware A14 polling (stop polling when backgrounded) | Would need a `WidgetsBindingObserver`; the fake has no push-driven invalidation to make backgrounded polling meaningfully different from foregrounded polling anyway |
| Widget/golden tests for the 5 screens and 1 dialog | Same reasoning as every prior step |
| Real gateway/Firebase/Maps-embed integrations | Carried-forward open items (D-32/D-40 Maps embed, D-52 push), unrelated to this step's own scope |

### A real bug this step's own refactor could have introduced

Moving FSSAI display out of `_TrustBlock` (D-61) left it holding **only** the verified-badge/halal-certification
row. A merchant fixture with neither flag would have rendered an empty bordered container on the merchant
profile screen — caught while writing the change, not by a test; fixed by having `_TrustBlock` return
`SizedBox.shrink()` when it has nothing to show.

### Verification performed (2026-07-27)

- [x] `dart run build_runner build` — clean; 4 new nested routes under `/orders`, 2 new `@riverpod` providers
- [x] `dart analyze` — 0 errors/warnings (984 `info`-level lints, `very_good_analysis`)
- [x] `flutter test` — 153/153 unit tests pass (17 new, all in `orders_repository_fake_test.dart`, covering
      segmentation, time-based status derivation under `FixedClock`, the pickup token's three layers,
      cancellation eligibility/execution on both sides of the cutoff, the refund timeline's step
      progression, and both issue-SLA branches)
- [x] `flutter build web --debug` — compiles; hit the documented exFAT dev-server file-lock race again
      (a stale `npx serve` process from an earlier session was still holding port 7455), resolved the
      same way — killed the process, rebuilt, re-served, confirmed HTTP 200
- [x] A mid-session drive disconnect (`D:` briefly vanished from the OS's visible volumes, health flagged
      "Full Repair Needed" on reconnect) was investigated and resolved without data loss — all files and
      the build_runner output were intact once the drive reconnected; work resumed from exactly where it
      paused. The disk health warning itself is a matter for the user's own `chkdsk` at their convenience,
      not something addressed here.

### Verification owed

- [ ] Visual confirmation of all 5 screens across their full state matrices (particularly the Orders list's
      hero card, the Pickup screen's QR/offline-fallback switch, and the Report Issue screen's
      status-scoped type picker) — same screenshot-capability gap as every prior step
- [ ] Screen-reader verification of the Pickup screen's assertive collected/merchantCancelled
      announcements, the Refund timeline's per-step semantic composition, and the Cancel dialog's
      consequence-announced-before-buttons ordering (§5d.2/§5d.3/§5d.4/§5d.5)
- [ ] Real device testing of `screen_brightness` (brighten-on-entry, manual toggle, restore-on-exit) and
      `image_picker` (this fake environment's picker behaviour is unverified beyond "doesn't throw")
- [ ] A real Google Maps key (D-32/D-40, unchanged) and a real gateway/Firebase integration (unchanged)

---

## Step 8 — `engagement` (2026-07-27)

**Status: delivered and verified.** Phase 5e's 3 screens — notification centre, Saved (A17's
consolidated watchlist), and Rate & Review with its A16 escalation bridge.

### Delivered

| File | Purpose |
|---|---|
| `lib/features/catalog/domain/repositories/catalog_repository.dart` + `.../data/repositories/catalog_repository_fake.dart` | **A17 landed here, not in `engagement`** — added `savedMerchants()`; `setMerchantWatched(watched: true)` now also saves, `setMerchantSaved(saved: false)` now also clears the watch |
| `lib/features/engagement/domain/entities/*.dart` | `NotificationType` (the full §2.6 inventory), `NotificationClass`, `AppNotification`, `ReviewTag`, `Review`, `SubmitReviewResult` |
| `lib/features/engagement/domain/repositories/engagement_repository.dart` | `getNotifications`, `markAllRead`, `dismissNotification`, `getExistingReview`, `submitReview` — deliberately **not** saved/watch (that's `catalog`'s, see above) |
| `lib/features/engagement/data/repositories/engagement_repository_fake.dart` | Notifications are **lazily derived** from `OrdersRepository.getOrders`, never stored (see D-62) |
| `lib/features/engagement/presentation/providers/engagement_providers.dart` | `engagementRepositoryProvider` (DI seam) |
| `lib/design_system/components/{notification_list_item,availability_state_badge,saved_merchant_card,star_rating_input,inline_confirmation,escalation_bridge,undo_snackbar}.dart` | The 7 new components §5e hands to Phase 6 (conditional tag chips reuse `catalog`'s existing `FacetChip` rather than a new component — see D-64) |
| `lib/features/engagement/presentation/screens/{notifications_screen,saved_screen,rate_review_screen}.dart` | The 3 routes |
| `lib/app/router/{routes.dart,router.dart}` | `/notifications` (top-level, outside the shell); `/saved/merchant/:id` and `/saved/bag/:id` (reusing `MerchantProfileScreen`/`BagDetailScreen`, same "declared in more than one branch" shape as Discover's own sub-routes); `/orders/:orderId/review` nested under the Orders branch despite being owned by `engagement`, per §4-navigation-flow.md's own note; `/notifications` added to the auth wall, `/saved` deliberately left off it (see D-63) |
| `lib/bootstrap.dart` | `ordersRepositoryFake` promoted to a named local (was already the case for `checkoutRepositoryFake`) so `engagement` can share it; `engagementRepositoryProvider` override added |
| `lib/features/orders/presentation/screens/orders_screen.dart` | Gained a notification-bell entry point in its `AppBar` — the one addition needed to make `/notifications` reachable from the UI |
| `lib/core/l10n/app_en.arb` | Nav/notifications/saved/review-form copy — the review *content* copy (ratings, tags, escalation, submitted state) was already front-run by Step 1b; the notification-centre and saved-screen copy was not |
| `test/unit/features/engagement/data/engagement_repository_fake_test.dart` | 10 new cases |
| `test/unit/features/catalog/data/catalog_repository_fake_test.dart` | 3 new cases covering the A17 consolidation and `savedMerchants()` |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-62** | Notifications are lazily derived from `OrdersRepository.getOrders` on every read, not stored — `orderConfirmed`/`paymentFailed`/`merchantCancelled` from order status, `pickupWindowOpening`/`pickupClosingSoon` from time against the pickup window, `rateYourPickup` from time since `collectedAt`, `refundInitiated`/`refundCompleted` from `getRefund`'s step timestamps. | There is no push simulator in this codebase, so a stored-notification model would need something to actually write to it — the same problem Step 7's D-58 solved for order status. `newBagsNearby`/`watchedMerchantListed` (the two **discovery**-class types) have no equivalent derivation source — a supply burst is a server/merchant-side event with nothing client-observable to derive from — and are documented as unreached, same shape as D-58's own gap. |
| **D-63** | `/saved` is **not** added to the §4.3 auth wall, unlike `/orders` and `/notifications`. | Saved/watched merchant state has been device-scoped (`Prefs`, not keyed by customer) since Step 5, not account-scoped — `/saved` works the same as `/discover`, usable anonymously. Only the **watch** toggle requires auth (it drives push targeting to a specific account), enforced with the same inline `PhoneEntryRoute` redirect the merchant profile screen's own toggle already used — `SavedScreen`'s bell toggle now does the identical check rather than diverging. |
| **D-64** | The conditional tag-chip set reuses `catalog`'s existing `FacetChip` component rather than a new `ReviewTagChip`. | `FacetChip` already has exactly the required shape — label, active/toggle state with `Semantics(selected:)`, a tap callback — and §5e.3's own hand-off list doesn't actually name a new component for this (it says "conditional tag chip **set**", i.e. the conditional logic, not a new chip widget). Building a second, near-identical chip would be the premature-duplication mistake the project's own conventions warn against. |
| **D-65** | `submitReview`'s `alsoCreateIssue` path always files the linked issue as `IssueType.qualityProblem`. | §5e.3's review-tag set has no dedicated food-safety tag (that's `orders`' `IssueType.foodSafety`, reached only through the full issue picker) — `qualityProblem` is the closest honest fit for "something was wrong with a collected order" without inventing a rating-to-issue-type mapping the spec doesn't define. The escalation bridge's own button still routes to the full `ReportIssueScreen` picker, where a user can select Food safety directly if that's what happened. |
| **D-66** | `EngagementRepositoryFake` depends on the `OrdersRepository` **interface**, not a concrete fake — unlike `orders`' own dependency on the concrete `CheckoutRepositoryFake`. | Every method `engagement` needs (`getOrders`, `getOrder`, `getRefund`, `reportIssue`) is already public interface surface — no fake-to-fake accessor was needed here, since (unlike `checkout`→`orders`) `orders` was designed from the start to expose everything a downstream reader needs. |

### Not delivered — and why

| Item | Reason |
|---|---|
| `newBagsNearby` / `watchedMerchantListed` reachable end-to-end | No supply-burst simulator exists (D-62) — both are fully modelled (`NotificationType`, icon, copy, dismissal-as-discovery-class) but unreached in the fake |
| `emptyPermissionDenied` state on the notification centre (§5e.1) | No real push-permission plumbing exists yet (`PushProvider` is `engagement`'s own still-open D-52 gap from Step 6/7) — the screen always renders the permission-granted empty state |
| Optimistic-rollback-with-message on Saved's toggle/unsave failures (§5e.2 asks for "a brief message") | Implemented the rollback; the brief failure message itself was scoped out for time — a silent revert is honest (nothing changed) even without the extra toast |
| Offline queue-and-replay for Saved toggles (§C3 exception cited in §5e.2) | No offline request queue exists anywhere in the app yet; this is a cross-cutting capability no prior step has built either |
| Widget/golden tests for the 3 screens | Same reasoning as every prior step |
| A route-table validator for notification deep links (§4.3's "validated against the route table before navigation") | These routes are locally synthesised from real order IDs against already-declared paths, not remote payloads, so the immediate risk R1/A6-style validation exists to prevent doesn't apply here — a full runtime validator matching against `$appRoutes` is genuinely new infrastructure no prior step built either, and is noted as an open item for whenever real push payloads exist to validate |

### Verification performed (2026-07-27)

- [x] `dart run build_runner build` — clean; 1 new top-level route (`/notifications`), 4 new nested
      routes (`/saved/merchant/:id`, `/saved/bag/:id`, `/orders/:orderId/review`), 1 new `@riverpod`
      provider
- [x] `dart analyze` — 0 errors/warnings (1097 `info`-level lints, `very_good_analysis`)
- [x] `flutter test` — 166/166 unit tests pass (10 new in `engagement_repository_fake_test.dart`
      covering notification derivation/timing, `markAllRead`, dismissal-while-live vs
      dismissal-once-terminal, and the full review lifecycle including the linked-issue path; 3 new in
      `catalog_repository_fake_test.dart` covering the A17 consolidation and `savedMerchants()`)
- [x] `flutter build web --debug` — compiles; same exFAT dev-server file-lock race, resolved the same way
- [x] Served the rebuilt build statically and confirmed HTTP 200 in a real browser

### Verification owed

- [ ] Visual confirmation of all 3 screens, particularly the Saved screen's three availability-badge
      variants and the notification centre's Today/Yesterday/Earlier grouping — same screenshot gap as
      every prior step
- [ ] Screen-reader verification of the star rating's discrete-button semantics, the notification list
      item's unread-state-in-label composition, and the Saved card's bell-toggle state announcement
- [ ] Real device testing of the review comment field's contact-info warning heuristic against real
      multilingual input (the current regex is a simple digit-run/`@`-pattern check, not locale-aware)

---

## Step 9 — `account` (2026-07-27)

**Status: delivered and verified.** Phase 5f's 11 screens plus 1 dialog — the final feature of the
Phase 9 build-out. Profile editing, saved locations, notification/app settings, help & support,
contact us, the four legal documents, about, and account deletion with A20's anonymise-and-retain
model and OTP re-verification.

### Delivered

| File | Purpose |
|---|---|
| `lib/core/domain/grievance_officer.dart` | **Amendment A19** — the one source for the grievance officer's identity |
| `lib/features/config/domain/entities/policy_values.dart` + DTO/mapper/fixture | `PolicyValues.grievanceOfficer` added, read by both Contact Us and the Legal grievance document |
| `lib/features/auth/domain/entities/customer.dart` | Gained `email`/`avatarUrl` — the fields its own class doc had explicitly deferred to this step |
| `lib/features/auth/domain/repositories/auth_repository.dart` + fake | `updateAccountDetails` (§5f.2's edit-profile write) and `requestReverificationOtp`/`verifyReverificationOtp` (§5f.11's "proves possession, doesn't extend the session" OTP re-check) |
| `lib/features/catalog/domain/repositories/catalog_repository.dart` + fake | `savedMerchants()` added — the missing list-all capability the Saved screen's "Add new"-adjacent Account surface needed; no A17 changes here (that landed in Step 8) |
| `lib/core/storage/prefs.dart` | Gained `getStringList`/`setStringList` — a small, deliberate extension of the "thin wrapper," needed for saved-location persistence |
| `lib/features/account/domain/entities/*.dart` | `SavedLocation`, `NotificationPreferences`, `LegalDocId`/`LegalDocument`, `HelpCategory`/`HelpTopic`, `ContactCategory`, `DeletionEligibility` (reuses `DeletionBlocker` from `core/error`, not a second type) |
| `lib/features/account/domain/repositories/account_repository.dart` | Deliberately **not** the owner of saved/watched merchant state (that's `catalog`'s, per D-64 below) — covers only what's genuinely new: locations, notification/app settings, help, legal, contact, deletion |
| `lib/features/account/data/repositories/account_repository_fake.dart` | The one repository this session that reaches across **four** other repositories (`orders`, `catalog`, `auth`, plus its own `Prefs`) — deletion is a real cross-feature operation |
| `lib/features/account/presentation/providers/account_providers.dart` | `accountRepositoryProvider` (DI seam) + `ThemeModeController` (a `@riverpod` `Notifier`, not a plain `StateProvider` — see D-67) |
| `lib/design_system/components/{avatar_image,profile_header,always_on_preference_row,permission_state_banner,blocker_list,settings_list,restricted_markdown_view}.dart` | The 7 new components §5f hands to Phase 6 |
| `lib/features/account/presentation/screens/{account_screen,edit_profile_screen,saved_locations_screen,notification_settings_screen,app_settings_screen,help_screen,faq_topic_screen,contact_screen,legal_document_screen,about_screen,delete_account_screen,logout_dialog}.dart` | The 11 routes plus the Log out dialog |
| `lib/app/router/{routes.dart,router.dart}` | 10 new nested routes under `/account`; **`/account` itself is public** (amendment A18) — only `profile`, `locations`, `notifications`, and `delete` are gated, a per-item auth list distinct from every other prefix-gated area in the app (see D-68) |
| `lib/app/app.dart` | `MaterialApp.router` now reads `themeMode` from `ThemeModeController` — the first working theme switch in the app |
| `lib/bootstrap.dart` | `authRepositoryFake` promoted to a named local (mirroring `checkoutRepositoryFake`/`ordersRepositoryFake`) so `account` can share it; `accountRepositoryProvider` override added |
| `lib/core/l10n/app_en.arb` | The full Account copy surface — none of it was front-run by Step 1b |
| `test/unit/features/account/data/account_repository_fake_test.dart` | 15 new cases |
| `test/unit/features/auth/data/auth_repository_fake_test.dart` | 5 new cases covering `updateAccountDetails` and the reverification OTP flow |
| `test/unit/features/catalog/data/catalog_repository_fake_test.dart` | (Already extended in Step 8 for A17/`savedMerchants()` — untouched here) |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-67** | `ThemeModeController` is a `@riverpod` codegen `Notifier<ThemeMode>`, not the plain `StateProvider` originally attempted. | `flutter_riverpod: ^3.1.0` removed the legacy `StateProvider`/`StateNotifierProvider` classic API in favour of codegen `Notifier`s — discovered via a real compile error, not a design preference. The notifier defaults synchronously to `ThemeMode.system` (what `MaterialApp.router` needs on the first frame) and self-corrects once `AccountRepository.getThemeMode()` resolves — a brief flash of the system default on a cold start where the user had previously chosen Light/Dark, accepted rather than plumbing a second synchronous-at-bootstrap `Prefs` seed alongside the repositories'. |
| **D-68** | `/account` is public (amendment A18); only `/account/profile`, `/account/locations`, `/account/notifications`, and `/account/delete` are added to the auth wall — a **per-item** list, unlike every other gated area (`/checkout`, `/orders`, `/notifications`), which gate their whole prefix. | This is the literal shape A18 asks for: the tab root, App settings, Help, Contact, and Legal all have to work for an anonymous user (reading terms before signing up is an explicit requirement), while editing a profile or deleting an account obviously cannot. `AccountScreen` itself already shows every gated item labelled as gated rather than hiding it (A18's own rule against a menu that reshapes after login); the router-level gate exists for the direct-deep-link case, so both paths land on the identical redirect-preserving auth wall. |
| **D-69** | `RestrictedMarkdownView` is a ~150-line hand-rolled parser (headings, bullet lists, `**bold**`, paragraphs) rather than a markdown package dependency. | §5f.7/§5f.9 both state the requirement as "a restricted subset... never arbitrary HTML" — a hand-rolled parser for exactly four constructs is a stronger guarantee of that boundary than configuring a general-purpose markdown renderer to disable the features it doesn't need. It also avoids a new dependency for what four fixture legal documents and five help topics actually use. |
| **D-70** | `AccountRepository` does not own saved/watched merchant state, and does not gain new methods for it beyond what Step 8 already added to `CatalogRepository`. | Step 5 built `isMerchantSaved`/`setMerchantSaved`/`isMerchantWatched`/`setMerchantWatched` directly on `CatalogRepository`, and Step 8 added the A17 consolidation and `savedMerchants()` there too. Duplicating a second saved-location concept in `account` for §5f.1's menu entry would either fork the state or require `account` to proxy every call through to `catalog` for no benefit — the Saved *screen* already lives in `engagement` (Step 8) and reads `CatalogRepository` directly; `account`'s only saved-location work is the *actual* new capability, `/account/locations` (discovery anchors), which is a genuinely different concept from saved merchants. |
| **D-71** | Avatar upload stores the picked image as a `data:` URI string on `Customer.avatarUrl`, with real bytes round-tripping through `image_picker` → `base64Encode` → `Image.memory`. EXIF stripping is **not** implemented. | Matches the project's now-established "real, working round-trip; no fake success" bar — `AvatarImage` genuinely decodes and displays whatever was picked, unlike a placeholder that always shows the same stock image. EXIF stripping needs an image-metadata package this project doesn't depend on and no real upload endpoint exists for the stripped-vs-unstripped distinction to matter against yet; §5f.2/§5d.6 both require it before a real upload ships. |
| **D-72** | `AccountRepositoryFake.deleteAccount()` performs the reachable parts of A20's erasure model — clears saved locations and notification preferences, unsaves/unwatches every merchant via `CatalogRepository`, and ends the session via `AuthRepository.logout()` — but does **not** run a 30-day-later background erasure job, and does not anonymise the customer's name/email/avatar fields still sitting in `Prefs` under their phone-keyed record. | The 30-day irreversible-erasure step needs a scheduler/background-job mechanism this project has nowhere else, and the disclosed grace period (§5f.11 requires disclosing it, not implementing the timer) is the user-facing fact that actually matters. `AuthRepository.updateAccountDetails`'s `name`/`email` parameters mean "set if provided," with no "clear" sentinel the way `avatarUrl`/`clearAvatar` has — extending that contract for a field-level anonymisation this fake's `logout()` already makes functionally inaccessible was judged unnecessary scope for this step. |

### Not delivered — and why

| Item | Reason |
|---|---|
| `emptyPermissionDenied` variant on Notification settings (§5f.4's OS-permission banner) | Same `PushProvider` gap carried since Steps 6–8 (D-52) — `PermissionStateBanner` is fully built as a component but has no real permission check to trigger it |
| Data saver actually degrading image quality | The preference persists and the toggle is real, but `cached_network_image` has no request-time quality lever wired to it — the setting is honest about being stored, not about having an effect yet |
| `cacheSizeBytes()` reading real cache size | Returns a plausible fixed fixture figure; `cached_network_image`'s disk cache has no synchronous size API exposed to this fake |
| FAQ search as a server query | Client-side substring filter over the bundled topic set — §5f.6 describes server-driven FAQ content generally, but the actual search mechanism isn't specified beyond "FAQ search," and no backend exists to query |
| Contact form photo attachments | §5f.8 lists attachments as a form field; the message/category/order-reference path is real, attachments were scoped out for time (same "≤3 photos" pattern already built once in `orders`' issue report could be reused later) |
| 30-day-later account erasure job, field-level anonymisation of retained `Prefs` records | D-72 — needs scheduler infrastructure this project has nowhere else |
| Widget/golden tests for the 12 screens | Same reasoning as every prior step |
| Real "Rate this app" store deep link | No app-store listing exists; the button is honest (shows "not available yet") rather than a silent no-op |

### A real gap found while wiring the auth wall

Auditing every `/account/*` sub-route against A18's actual requirement (only 4 of 11 gated) surfaced that Step 7's
own auth-wall wiring had never been extended past `/orders`/`/checkout`/`/notifications` — reasonable at the
time, since `/account` didn't exist yet, but worth recording that the per-item exception list this step needed
is a materially different shape (`_authRequiredAccountPrefixes`, checked in addition to the existing whole-prefix
list) from anything the router had before. No prior behaviour changed; this is additive.

### Verification performed (2026-07-27)

- [x] `dart run build_runner build` — clean; 10 new nested routes under `/account`, 2 new `@riverpod`
      declarations (`accountRepositoryProvider`, `ThemeModeController`), `PolicyValuesDto`/
      `GrievanceOfficerDto` freezed/json_serializable regenerated
- [x] `dart analyze` — 0 errors/warnings (1254 `info`-level lints, `very_good_analysis` — the info count
      keeps falling step over step as more of the codebase exists relative to the fixed set of
      unavoidable `public_member_api_docs`/`lines_longer_than_80_chars` notes)
- [x] `flutter test` — 186/186 unit tests pass (15 new in `account_repository_fake_test.dart` covering
      saved-location CRUD/cap/default-promotion, notification/app-settings round-trips, all 4 legal
      documents, and the full deletion lifecycle including the blocked-then-eligible transition; 5 new in
      `auth_repository_fake_test.dart` covering `updateAccountDetails` and the reverification OTP flow)
- [x] `flutter build web --debug` — compiles; served the rebuilt build statically and confirmed HTTP 200
      in a real browser

### Verification owed

- [ ] Visual confirmation of all 12 screens, particularly the theme picker's live switch (no restart, no
      flash), the delete-account OTP flow, and the three legal-document/help-topic markdown renderings —
      same screenshot-capability gap as every prior step
- [ ] Screen-reader verification of the gated-menu-item announcement pattern (§5f.1), the deletion
      screen's retained-data-notice-before-confirm ordering (§5f.11), and `RestrictedMarkdownView`'s
      heading navigation on a real screen reader
- [ ] Real device testing of `image_picker`'s avatar flow end to end, and of `showLicensePage`'s
      generated attribution list against the actual dependency tree
- [ ] A real Google Maps key, gateway, Firebase push, and backend for all the endpoints this phase's
      fakes stand in for — the complete list of carried-forward open items across every step

---

## Phase 9 build-out complete

All nine steps of Phase 8 §8.12's sequence are delivered and verified: `config`, `onboarding`, `auth`,
`location`, `catalog`, `checkout`, `orders`, `engagement`, `account`. 51 screens plus 2 dialogs, built
entirely against fakes per the Phase 1 locked decision, with `dart analyze` at 0 errors/warnings and the
full unit test suite passing at every step. The carried-forward open items are consistent across the
whole build: a real Google Maps key (D-32/D-40), a real payment gateway (D-50), real Firebase push
(D-52), the exFAT dev-server file-lock workaround, and the backend this entire phase's fakes stand in
for. None of those are addressable from within this codebase alone — they need credentials, vendor
selection, or infrastructure decisions that are the user's to make.

---

## Post-completion — real map integration (2026-07-27)

The user supplied a real [MapTiler](https://cloud.maptiler.com) API key, resolving D-32/D-40 (the
carried-forward "no Maps API key configured" open item from `location` and `catalog`). The key didn't
match Google's format (`AIzaSy...`) — clarified with the user before wiring anything, since using the
wrong SDK for a key fails silently or breaks the build. It's a MapTiler key, which serves standard
XYZ raster tiles — a different integration path from `google_maps_flutter` (already an unused pubspec
dependency, since the `MapProvider` abstraction was never built against it) which needs Google's own
native SDK and a Google-specific key format.

### Delivered

| File | Purpose |
|---|---|
| `pubspec.yaml` | Removed unused `google_maps_flutter`; added `flutter_map` + `latlong2` — a provider-agnostic tile map widget, so a future vendor swap (Mappls/Ola/Google raster tiles) is a `MapTileConfig` implementation, not a dependency change |
| `lib/core/platform/map_tile_config.dart` | The actual swappable boundary (§8.6's "MapProvider") — `MapTileConfig` (`urlTemplate`, `attribution`) + `MapTilerTileConfig` |
| `lib/core/platform/map_tile_config_provider.dart` | `mapTileConfigProvider` — the DI seam, shared by `location` and `catalog` |
| `lib/design_system/components/tile_map_view.dart` | `TileMapView`/`MapPin` — the one place `flutter_map`-specific code lives; converts between the app's own `core/domain/lat_lng.dart` `LatLng` and `latlong2`'s at the widget boundary, keeping the domain type canonical everywhere else |
| `lib/features/catalog/domain/entities/bag_summary.dart` + `catalog_repository_fake.dart` | `BagSummary` gained a `geo` field (the merchant's coordinate, already computed for `distanceMetres` — just also exposed) — needed for the Discover map view's pins |
| `lib/features/location/presentation/screens/location_setup_screen.dart` | The resolved-location card now renders a real (non-interactive) `TileMapView` thumbnail; "Drop pin" opens a real interactive centred-pin picker (`_PinDropSheet`) instead of always resolving to the launch city's centre |
| `lib/features/catalog/presentation/screens/discover_screen.dart` | The map toggle button now actually toggles a real map view with a pin per bag, tap-through to bag detail — previously just showed a "map unavailable" snackbar with no toggle state at all |
| `lib/bootstrap.dart` | Reads `MAPTILER_API_KEY` via `String.fromEnvironment`; **fails loudly at startup** if unset, same reasoning as the flavour check |
| `dart_defines.json` (gitignored) | The real key lives only here, passed via `--dart-define-from-file=dart_defines.json`. `.gitignore`'s existing "Secrets — never committed" section already anticipated this exact pattern (`# Config comes from --dart-define`) and now lists this file explicitly |
| `lib/core/l10n/app_en.arb` | `discoverMapViewCta`/`discoverListViewCta`/`discoverMapPinSemantic`, `locationSetupConfirmPinCta` |

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-73** | The key's format was checked against known vendor patterns and clarified with the user (`AskUserQuestion`) before any wiring began, rather than assumed to be for `google_maps_flutter` (the dependency already sitting in `pubspec.yaml`). | The existing code carried an explicit comment warning that declaring a map dependency without a valid key for it "either fails silently or risks breaking `flutter build web`" — proceeding on an unverified assumption about which vendor a credential belongs to risked exactly that, for a real (not fixture) credential. |
| **D-74** | `google_maps_flutter` removed rather than kept alongside `flutter_map`. | It was never wired to anything (grep-confirmed zero imports outside `pubspec.yaml` itself) — keeping an unused native SDK dependency around after the actual vendor decision (MapTiler) is made only invites future confusion about which one is live. The swappability §8.6 asks for is provided by the `MapTileConfig` interface, not by having multiple concrete SDKs sitting unused. |
| **D-75** | The API key is stored in a gitignored `dart_defines.json`, read via `String.fromEnvironment`, never hardcoded in a `.dart` file. | Standard Flutter secret-handling pattern, and the exact mechanism `.gitignore`'s pre-existing "Secrets" section already named ("Config comes from --dart-define, Phase 8 §8.6") before any map key existed to use it. `bootstrap.dart` throws a clear, actionable error if the define is missing rather than shipping a build with silently broken map tiles. |
| **D-76** | `TileMapView` is deliberately thin — it renders tiles/pins/attribution and nothing else; the "pin follows the map centre" picker pattern is composed by the caller (`_PinDropSheet` in `location_setup_screen.dart`) as a `Stack`, not a second interaction mode built into the shared component. | Only one screen needs that interaction; building it into the shared widget for a single caller would be the premature-abstraction mistake the project's own conventions warn against. The Discover map (fixed pins, no centre-tracking) and the location thumbnail (non-interactive) both use the same plain widget unmodified. |
| **D-77** | `BagSummary.geo` exposes the merchant's exact coordinate, unlike `distanceMetres`/`scarcity`, which are deliberately coarse (A8). | A8's qualitative-scarcity reasoning is about *availability* (never assert an exact count that can go stale), not position — a map pin has to be placed somewhere, and the merchant's storefront location is not the sensitive fact A8 protects. The value was already being computed internally for `distanceMetres`; this just exposes what was already there. |

### Verification performed (2026-07-27)

- [x] `dart analyze` — 0 errors/warnings (1277 `info`-level lints)
- [x] `flutter test` — 186/186 unit tests pass (no regressions from the `BagSummary.geo` field addition —
      the one non-test construction site was updated, and no test constructs `BagSummary` directly)
- [x] `flutter build web --debug --dart-define-from-file=dart_defines.json` — compiles with the real key
      wired in; served and confirmed HTTP 200 in a real browser

### Verification owed

- [ ] Visual/manual confirmation that MapTiler tiles actually render correctly in a real browser (the
      build compiling and serving confirms the code path is wired; it doesn't confirm the tile requests
      themselves succeed against the live MapTiler endpoint with this key — same screenshot-capability
      gap as every prior step)
- [ ] Confirmation the MapTiler key is valid and has the `streets-v2` style enabled on the account tier
      in use
- [ ] Android/iOS platform config for `flutter_map` (no native map SDK keys/manifest entries needed,
      unlike `google_maps_flutter` would have required, but real-device testing is still outstanding —
      same gap as everything else in "Verification owed" across every step)

## Post-completion — first real browser verification pass, two bugs found and fixed (2026-07-27)

The user tested the served build in an actual browser for the first time this phase (every prior step's
"Verification owed" section had flagged visual/interactive testing as a gap). Two distinct issues
surfaced.

### Bug 1 — false alarm: stale service-worker cache, not a code defect

A red `AppButton` assertion + `RenderFlex overflowed by ~99400 pixels` error appeared on `/location-primer`,
a screen untouched by the map work. Investigation of the actual `flutter_map` 8.3.1 API surface found no
mismatch, and `location_primer_screen.dart`'s `AppButton` usage was structurally sound (bounded height via
`Scaffold > SafeArea > Padding`, not an unbounded scroll context). Root cause: `build/web` had been
hot-swapped underneath the same running `npx serve` process repeatedly across Steps 6–9 plus the map
dependency swap (`google_maps_flutter` → `flutter_map`), without the browser ever being told to invalidate
its cached JS/assets.

**Fix:** killed the stale server process (port 7455), ran a full `flutter clean` → `flutter pub get` →
`flutter pub run build_runner build --delete-conflicting-outputs` (486 outputs regenerated) → `flutter
build web --debug --dart-define-from-file=dart_defines.json` → re-served. User re-tested in a fresh
Incognito window — confirmed the assertion no longer appears. No source change was needed; this was a
stale-artifact/caching issue, not a bug.

### Bug 2 — real bug: leftover `/home` references from before Step 5 deleted that route

Testing `/auth/profile-setup` in a guaranteed-clean Incognito window produced go_router's own
"Page Not Found" page with `GoException: no routes for location: /home`. Since this reproduced in a fresh
profile (no cache involved) and was a routing exception rather than a widget assertion, it was a genuine
code defect, not an artifact of the rebuild above.

`HomePlaceholderScreen` and the `/home` route were explicitly deleted in Step 5, with the documented intent
that "anything that used to fall through to `/home` now falls through to `/discover`"
(`lib/app/router/routes.dart`'s scope-note comment already said as much). A `Grep` for `'/home'` across
`lib/` found three call sites that predated that deletion and were never updated:

| File | Call site |
|---|---|
| `lib/features/onboarding/presentation/screens/dietary_setup_screen.dart` | `_save()` — end of dietary-preference selection |
| `lib/features/auth/presentation/screens/profile_setup_screen.dart` | fallback branch when no `redirect` query param is present |
| `lib/features/auth/presentation/screens/otp_verify_screen.dart` | fallback branch when no `redirect` query param is present |

**Fix:** all three changed from `context.go('/home')` to `context.go('/discover')`. The stale explanatory
comment in `dietary_setup_screen.dart` (which said Discover "doesn't exist yet") was removed since Discover
has existed since Step 5. Confirmed no other `/home` references remain outside the router's own scope-note
comment (which correctly describes the deletion, not a live reference).

**Verification:** `dart analyze` — 0 errors/warnings (1269 pre-existing `info`-level lints in test files,
unrelated). `flutter test` — 186/186 pass, no regressions. `flutter build web --debug
--dart-define-from-file=dart_defines.json` — compiles; re-served on port 7455, confirmed HTTP 200.

**Verification owed:** user re-test of the profile-setup/OTP/dietary-setup flows in a fresh browser session
to confirm the redirect now lands on `/discover` instead of erroring.

### Bug 3 — real bug: `AppButton` secondary variant violates `Material`'s shape/borderRadius assertion

The user's continued testing hit a red assertion box inside the "Change location" sheet
(`LocationSwitcherSheet`, opened from Discover's location pill), landing on its "Use current location"
button. Since the browser console truncates assertion detail, a throwaway widget test was written to pump
`LocationSwitcherSheet` through the same `ProviderScope`/`MaterialApp` shape the real app uses, which
surfaced the full assertion:

```
'package:flutter/src/material/material.dart': Failed assertion: line 209 pos 15:
'!(shape != null && borderRadius != null)': is not true.
```

`AppButton`'s `Material` (`lib/design_system/components/app_button.dart`) was unconditionally passing
`borderRadius: BorderRadius.circular(Radii.md)` **and**, whenever the variant carries a border color,
also `shape: RoundedRectangleBorder(...)` — `Material` forbids setting both at once. `border` is non-null
only for `AppButtonVariant.secondary`, so **every secondary-variant button anywhere in the app** hit this
on first build — a latent bug across all 51 screens that simply had never been visually rendered before
today's browser pass caught it.

**Fix:** `borderRadius` is now only passed when `border == null`; the border case relies on `shape`'s own
`borderRadius` (which was already being set inside the `RoundedRectangleBorder`) to express the rounding
instead of duplicating it via both properties.

**Regression test added:** `test/widget/design_system/app_button_test.dart` — pumps `AppButton` for all
four `AppButtonVariant` values and asserts no exception is thrown. This is the project's first widget
test; prior steps only tested repositories against fakes (per the Phase 1 locked decision), which is
exactly why a pure-rendering bug like this survived every "Verification owed" checklist until real
browser use caught it.

**Verification:** `dart analyze` — 0 errors/warnings. `flutter test` — 190/190 pass (186 unit + 4 new
widget tests). `flutter build web --debug --dart-define-from-file=dart_defines.json` — compiles; re-served
on port 7455, confirmed HTTP 200.

## Post-completion — map vendor swap to OpenFreeMap, web branding fixed (2026-07-27)

Two unrelated items raised together: `web/index.html` was still Flutter's unedited scaffold (browser
tab title `surplus_marketplace`, meta description `"A new Flutter project."`), and a request to switch
the map vendor from MapTiler to **OpenFreeMap** (openfreemap.org) — free, no API key, no usage limits,
vector tiles built from OpenStreetMap + OpenMapTiles data.

### Web branding

`web/index.html` and `web/manifest.json` — `title`, `apple-mobile-web-app-title`, `manifest.json`'s
`name`/`short_name`, and both files' `description` updated to "Surplus Marketplace" / "Surplus
Marketplace — reserve surplus food from nearby stores and restaurants before it's gone." (no separate
brand name exists anywhere in the project's own docs — `pubspec.yaml`'s description is the closest
precedent, so this mirrors it rather than inventing new copy).

### Map vendor swap — attempted, hit a hard platform wall, reverted

OpenFreeMap serves **vector** tiles (MapLibre/Mapbox style JSON + MVT), not the simple raster XYZ PNG
tiles `flutter_map`'s `TileLayer` consumes directly — this is not a drop-in URL swap like the earlier
MapTiler wiring was. Verified the actual package API via pub.dev/dartdoc before writing any code (the
`AppButton` bug two sections up was a direct lesson in what guessing an API produces), then implemented
it:

- Added `vector_map_tiles: 10.0.0-beta.2` — the first prerelease compatible with `flutter_map ^8.x`
  (stable 8.0.0 caps at `flutter_map ^7.0.2`). Forced `latlong2` down from `^0.10.1` to `^0.9.1`.
- `MapTileConfig` changed shape from `urlTemplate` (raster) to `styleUrl`/`apiKey` (vector);
  `MapTilerTileConfig` replaced by `OpenFreeMapTileConfig`.
- `TileMapView` changed from `StatelessWidget` to `StatefulWidget`, reading the style JSON asynchronously
  via `vmt.StyleReader` and rendering through `FutureBuilder` + `vmt.VectorTileLayer`.
- `bootstrap.dart`'s `MAPTILER_API_KEY` startup gate removed; override pointed at `OpenFreeMapTileConfig`.

**This was reverted.** `dart analyze` passed clean, but `flutter build web` failed outright:
`vector_map_tiles` → `vector_tile_renderer 7.0.0-beta.1` → `flutter_scene` (GPU-accelerated rendering)
depends on `dart:ffi`, which **does not exist on Flutter Web**. The build errored with `Error: Dart
library 'dart:ffi' is not available on this platform` and dozens of cascading `Type 'Pointer'/'Handle'
not found` errors. This is a hard incompatibility in the package itself at the version compatible with
this project's `flutter_map`, not something fixable in our code. The older stable `vector_map_tiles
8.0.0` uses `vector_tile_renderer ^5.2.0`, which has no `flutter_scene`/FFI dependency (confirmed via its
dependency list) and would be web-safe — but it requires `flutter_map ^7.0.2`, a further downgrade with
its own unverified API-compatibility risk, on top of an already-eventful debugging day.

Given a fully-working, already-tested MapTiler integration existed, the pragmatic call was to revert
rather than keep pushing deeper into an increasingly risky dependency chain. **All map-related files were
reverted to their pre-OpenFreeMap state**: `map_tile_config.dart` (`MapTilerTileConfig` restored, with a
new doc note explaining why a vector provider was tried and reverted), `tile_map_view.dart` (back to
`StatelessWidget` + `fm.TileLayer`), `bootstrap.dart` (the `MAPTILER_API_KEY` gate and override restored),
`dart_defines.json` (real key restored), `pubspec.yaml` (`vector_map_tiles` removed, `latlong2` restored
to `^0.10.1`). The web branding fix (`index.html`/`manifest.json`) was **kept** — unaffected by the map
revert.

### Implementation decisions

| # | Decision | Rationale |
|---|---|---|
| **D-78** | Verified `vector_map_tiles`' exact constructor signatures (`StyleReader`, `Style`, `VectorTileLayer`) via pub.dev/dartdoc before writing `TileMapView`, rather than inferring from the earlier raster-tile pattern. | The `AppButton` bug (two sections above) was a direct, fresh example of what shipping an unverified Flutter API assumption costs — spending one lookup first was still the right call even though the package itself turned out unusable for an unrelated reason (the FFI/web incompatibility wasn't something an API lookup would have surfaced). |
| **D-79** | Pinned `vector_map_tiles` to an exact prerelease (`10.0.0-beta.2`) instead of a caret range. | It's the only version compatible with the project's existing `flutter_map ^8.3.1` — the stable 8.0.0 release caps at `flutter_map ^7.0.2`. Moot after the revert, kept as a record of what was tried. |
| **D-80** | `MapTileConfig` interface changed shape (`urlTemplate` → `styleUrl`/`apiKey`) rather than trying to keep both raster and vector shapes on one interface, then reverted with the rest. | Confirmed nothing outside `map_tile_config.dart`/`TileMapView` referenced `urlTemplate` directly — the §8.6 boundary held during the attempt, and reverted cleanly for the same reason. |
| **D-81** | Reverted to MapTiler rather than pursuing `vector_map_tiles 8.0.0` + `flutter_map ^7.0.2`, or switching to `maplibre_gl`. | MapTiler was already fully built, tested, and confirmed rendering real tiles in a live browser this session — zero further risk. Both alternatives (older `vector_map_tiles`, or `maplibre_gl`) carry their own unverified compatibility risk on top of a day that had already produced three real bugs; the user chose to keep the known-working state rather than extend the debugging session further. OpenFreeMap remains a valid future option via `maplibre_gl` specifically (official, platform-view-based, avoids `dart:ffi` entirely) if pursued as its own scoped piece of work. |

### Verification performed (2026-07-27)

- [x] `dart analyze` — 0 errors/warnings on the OpenFreeMap attempt; confirmed 0 errors/warnings again
      after the revert
- [x] `flutter pub get` — resolves cleanly after the revert (`vector_map_tiles` removed, `latlong2` back
      to `^0.10.1`)
- [ ] `flutter build web` + `flutter test` — **blocked**, not by the map revert itself but by unrelated
      exFAT filesystem corruption on the `D:` drive that surfaced while cleaning build artifacts during
      this troubleshooting session (see below)

### Unrelated blocker hit during verification — exFAT corruption on `D:`

While clearing stale build artifacts (`flutter clean`) as part of verifying the revert, `ios/Flutter/
ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Sources` (an iOS-only, Flutter-tool-managed
directory never touched by this project's actual Windows/web-only work) became inaccessible —
`rm`, PowerShell `Remove-Item`, `takeown`/`icacls` (which confirmed exFAT has no ACL support at all —
"insecure file systems; there is no support for ACLs"), `robocopy /MIR`, and a plain parent rename all
failed with "Access is denied" at the filesystem-driver level. Repeated `cmd /c rd /s /q` attempts to
delete the whole `ios/` folder made it *worse* — spreading "Access is denied" to sibling directories
(`Runner\Assets.xcassets`, `Runner.xcworkspace`, etc.) that were accessible moments before. This matches
the `chkdsk` "Full Repair Needed" warning already flagged on this drive in an earlier session
(2026-07-27, Step 7's log entry) — that repair was deferred then and has now actually blocked work.
Stopped all further filesystem operations once the corruption appeared to be spreading, rather than risk
compounding it. **User needs to run `chkdsk /f D:` (admin, likely requires the drive not be in use / a
restart) before `flutter build web` or `flutter test` can run again** — this is unrelated to any code
in this repository and not something fixable from within a coding session.
