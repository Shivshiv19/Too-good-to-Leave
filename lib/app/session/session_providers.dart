import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/app/session/session_state.dart';

part 'session_providers.g.dart';

/// The single [SessionState] instance for this app session (§4.1).
///
/// Kept alive for the app's lifetime rather than autodisposed: the router is
/// built once against this exact instance (`refreshListenable:`), so a new
/// instance appearing mid-session would desynchronise the two.
@Riverpod(keepAlive: true)
SessionState sessionState(Ref ref) => SessionState();
