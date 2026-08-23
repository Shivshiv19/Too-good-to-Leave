import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';
import 'package:too_good_to_leave_shop/screens/admin/admin_shell_screen.dart';
import 'package:too_good_to_leave_shop/screens/login_or_register_screen.dart';
import 'package:too_good_to_leave_shop/screens/login_screen.dart';
import 'package:too_good_to_leave_shop/screens/pending_approval_screen.dart';
import 'package:too_good_to_leave_shop/screens/registration_screen.dart';
import 'package:too_good_to_leave_shop/screens/shop_shell_screen.dart';

/// The same Supabase project the customer app connects to — see
/// ../supabase/schema.sql at the repo root. Same secrets-file convention
/// as the customer app's MAPTILER_API_KEY.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// The same MapTiler project/key the customer app's own map screens use —
/// see `core/platform/map_tile_config.dart`. Deliberately not a startup
/// guard like the two keys above: the registration screen's map picker is
/// additive (device geolocation still works without it), never
/// load-bearing, so a missing key degrades that one feature instead of
/// blocking the whole app.
const _mapTilerApiKey = String.fromEnvironment('MAPTILER_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `Fmt`'s date formatters (core/utils/formatters.dart) use `intl`'s
  // locale-aware DateFormat, which throws LocaleDataException until its
  // locale data has been loaded — unlike NumberFormat, which works without
  // this. Must happen before any screen that formats a date/time runs.
  await initializeDateFormatting('en_IN');

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw UnimplementedError(
      'No SUPABASE_URL/SUPABASE_ANON_KEY configured. Run with '
      '--dart-define-from-file=dart_defines.json (see .gitignore\'s '
      '"Secrets" section — the real values live only in that local file).',
    );
  }
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );

  runApp(const ShopAppLoader());
}

/// Awaits [ShopRepository.load] (reads `shared_preferences`, which is
/// itself async) before the real app can render — a shop's registration
/// and listings must survive a browser refresh, so this can't just start
/// from an empty in-memory repository the way earlier iterations did.
class ShopAppLoader extends StatelessWidget {
  const ShopAppLoader({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<ShopRepository>(
    future: ShopRepository.load(),
    builder: (context, snapshot) {
      final repository = snapshot.data;
      if (repository == null) {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      return ShopApp(repository: repository);
    },
  );
}

/// The pre-registration choice this app currently shows — landing (log in
/// vs register), the login form itself, or the registration form. Only
/// meaningful while [ShopRepository.profile] is null; once a shop exists,
/// [ShopApp]'s builder ignores this entirely.
enum _EntryStep { landing, login, register }

class ShopApp extends StatefulWidget {
  const ShopApp({required this.repository, super.key});

  final ShopRepository repository;

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  _EntryStep _step = _EntryStep.landing;
  late bool _wasRegistered = widget.repository.isRegistered;
  late bool _wasAdmin = widget.repository.isAdmin;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_handleRepositoryChange);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_handleRepositoryChange);
    super.dispose();
  }

  void _handleRepositoryChange() {
    final isRegistered = widget.repository.isRegistered;
    final isAdmin = widget.repository.isAdmin;
    if ((_wasRegistered && !isRegistered) || (_wasAdmin && !isAdmin)) {
      // A shop or admin log-out just happened — the next session should
      // start back at the landing choice, not wherever this one happened
      // to leave off.
      setState(() => _step = _EntryStep.landing);
    }
    _wasRegistered = isRegistered;
    _wasAdmin = isAdmin;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Too Good To Leave — Shop',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    // No in-app theme toggle exists for this seller dashboard (unlike the
    // customer app's Account > App settings control) — following the
    // system preference blindly means a merchant on a dark-mode OS never
    // sees the light palette this app is designed and verified against.
    themeMode: ThemeMode.light,
    home: ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        if (widget.repository.isAdmin) {
          return AdminShellScreen(repository: widget.repository);
        }
        final profile = widget.repository.profile;
        if (profile == null) {
          return switch (_step) {
            _EntryStep.landing => LoginOrRegisterScreen(
              onChooseLogin: () => setState(() => _step = _EntryStep.login),
              onChooseRegister: () =>
                  setState(() => _step = _EntryStep.register),
            ),
            _EntryStep.login => LoginScreen(
              repository: widget.repository,
              onRegisterInstead: () =>
                  setState(() => _step = _EntryStep.register),
            ),
            _EntryStep.register => RegistrationScreen(
              repository: widget.repository,
              onLoginInstead: () => setState(() => _step = _EntryStep.login),
              mapTilerApiKey: _mapTilerApiKey,
            ),
          };
        }
        if (profile.status != ShopApprovalStatus.verified) {
          return PendingApprovalScreen(repository: widget.repository);
        }
        return ShopShellScreen(repository: widget.repository);
      },
    ),
  );
}
