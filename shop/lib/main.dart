import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/screens/shop_shell_screen.dart';

void main() {
  runApp(ShopApp(repository: ShopRepository()));
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
    home: ShopShellScreen(repository: repository),
  );
}
