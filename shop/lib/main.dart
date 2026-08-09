import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';
import 'package:too_good_to_leave_shop/screens/pending_approval_screen.dart';
import 'package:too_good_to_leave_shop/screens/registration_screen.dart';
import 'package:too_good_to_leave_shop/screens/shop_shell_screen.dart';

void main() {
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

class ShopApp extends StatelessWidget {
  const ShopApp({required this.repository, super.key});

  final ShopRepository repository;

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
      listenable: repository,
      builder: (context, _) {
        final profile = repository.profile;
        if (profile == null) {
          return RegistrationScreen(repository: repository);
        }
        if (profile.status != ShopApprovalStatus.verified) {
          return PendingApprovalScreen(repository: repository);
        }
        return ShopShellScreen(repository: repository);
      },
    ),
  );
}
