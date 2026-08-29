import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// # LAYER 2 — Semantic type tokens
///
/// Roles, not sizes (Phase 6 §6.3.2). Access via `context.type`.
///
/// ## Devanagari-derived line heights
///
/// Line heights are derived from **Devanagari** metrics, not Latin (§6.3.1).
/// Devanagari needs more vertical room for the shirorekha and stacked matras;
/// sizing to Latin metrics clips them.
///
/// The second benefit is structural: because both scripts share the taller
/// line box, **text does not reflow when the script changes**, so a Devanagari
/// merchant name cannot break a card's layout. This matters in V1 despite the
/// English-only launch (assumption A12) — merchant names, localities, and
/// landmark strings carry Devanagari regardless of UI language.
///
/// ## Fonts
///
/// **One typeface everywhere** (Starbucks-inspired rebrand) — **Inter**
/// across every display/heading/body role, rather than the previous
/// Sora-for-headings/Inter-for-body split. The reference palette's own
/// system uses a single proprietary corporate typeface universally (with
/// tight negative tracking) and reserves alternate typefaces for two
/// narrow, unrelated contexts this app has no equivalent of — Inter is the
/// open-source substitute recommended for exactly this "one confident
/// voice" role. Fetched via `google_fonts` rather than bundled binaries —
/// no `assets/fonts/` files to manage, and the fallback-to-system-font gap
/// the original bundled-font plan left open (see the commented `fonts:`
/// block in `pubspec.yaml`) never opens in the first place.
/// `NotoSansDevanagari` and `JetBrainsMono` remain unbundled system-font
/// fallbacks — this rebrand didn't touch either.
///
/// **Tight tracking** (`-0.01em`, roughly `-fontSize * 0.01` in logical
/// pixels) is applied to every role below except [codeMono] — pickup/order
/// codes keep their deliberately *wide* spacing (see that field's own doc),
/// since tightening a code meant to be read aloud across a shop counter
/// would work against the reason it's wide in the first place.
@immutable
final class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.titleSmall,
    required this.bodyLarge,
    required this.body,
    required this.caption,
    required this.label,
    required this.labelSmall,
    required this.priceLarge,
    required this.priceMedium,
    required this.codeMono,
    required this.countdown,
  });

  /// The single type scale. Colour is applied by the consuming widget from
  /// `AppColors`; these styles carry no colour.
  ///
  /// Not `const` — `GoogleFonts.*` resolves/loads the font at call time.
  factory AppTypography.standard() => AppTypography(
    display: _inter(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.w700,
    ),
    headline: _inter(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w700,
    ),
    title: _inter(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
    titleSmall: _inter(
      fontSize: 18,
      height: 26 / 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: _inter(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
    ),
    body: _inter(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400),
    caption: _inter(
      fontSize: 12,
      height: 18 / 12,
      fontWeight: FontWeight.w400,
    ),
    label: _inter(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),

    // Small all-caps "eyebrow" labels — stat-card headers ("MEALS SAVED"),
    // info-row labels ("PICKUP CODE", "COLLECTION TIME"). Positive tracking
    // (the opposite of every other role's tight `-0.01em`) is deliberate:
    // wide-set capitals read as a label, not a sentence, at this size.
    labelSmall: _inter(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.12,
    ),
    priceLarge: _inter(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    priceMedium: _inter(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    ),

    // Order code and pickup fallback code (§5d.3, §5c.8).
    //
    // Wide letter-spacing because the code is transcribed by a stranger at
    // arm's length across a shop counter. Monospace for unambiguous 0/O and
    // 1/l/I — and the code alphabet itself already excludes the ambiguous
    // characters (§2.1).
    codeMono: const TextStyle(
      fontFamily: _mono,
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w500,
      letterSpacing: 3.6,
    ),

    // Countdown (§6.3.2).
    //
    // **Tabular figures are not a detail.** Proportional digits change
    // width as they tick, so a countdown visibly jitters and reflows its
    // container — on a screen the user stares at while standing in a shop.
    countdown: _inter(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  static const _mono = 'JetBrainsMono';
  static const _fallback = ['NotoSansDevanagari'];

  /// `GoogleFonts.inter(...)` has no `fontFamilyFallback` parameter — it's
  /// applied via `copyWith` on the `TextStyle` it returns instead.
  ///
  /// Every role routes through here, so the tight `-0.01em` tracking (see
  /// the class doc) is applied in exactly one place rather than repeated at
  /// every call site.
  static TextStyle _inter({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    List<FontFeature>? fontFeatures,
    double? letterSpacing,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing ?? fontSize * -0.01,
    fontFeatures: fontFeatures,
  ).copyWith(fontFamilyFallback: _fallback);

  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle label;
  final TextStyle labelSmall;
  final TextStyle priceLarge;
  final TextStyle priceMedium;
  final TextStyle codeMono;
  final TextStyle countdown;

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? label,
    TextStyle? labelSmall,
    TextStyle? priceLarge,
    TextStyle? priceMedium,
    TextStyle? codeMono,
    TextStyle? countdown,
  }) => AppTypography(
    display: display ?? this.display,
    headline: headline ?? this.headline,
    title: title ?? this.title,
    titleSmall: titleSmall ?? this.titleSmall,
    bodyLarge: bodyLarge ?? this.bodyLarge,
    body: body ?? this.body,
    caption: caption ?? this.caption,
    label: label ?? this.label,
    labelSmall: labelSmall ?? this.labelSmall,
    priceLarge: priceLarge ?? this.priceLarge,
    priceMedium: priceMedium ?? this.priceMedium,
    codeMono: codeMono ?? this.codeMono,
    countdown: countdown ?? this.countdown,
  );

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
      priceLarge: TextStyle.lerp(priceLarge, other.priceLarge, t)!,
      priceMedium: TextStyle.lerp(priceMedium, other.priceMedium, t)!,
      codeMono: TextStyle.lerp(codeMono, other.codeMono, t)!,
      countdown: TextStyle.lerp(countdown, other.countdown, t)!,
    );
  }
}
