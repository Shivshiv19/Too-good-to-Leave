import 'package:flutter_test/flutter_test.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';
import 'package:too_good_to_leave_shop/main.dart';

ShopRepository _verifiedRepository() {
  final repo = ShopRepository();
  repo.register(
    ShopProfile(
      businessName: 'Test Bakery',
      ownerName: 'Test Owner',
      phone: '9999999999',
      email: 'owner@test.com',
      category: ShopCategory.bakery,
      addressLine: '1 Test Street',
      locality: 'Test Locality',
      fssai: FssaiLicense(
        licenseNumber: 'FSSAI123',
        expiresAt: DateTime.now().add(const Duration(days: 365)),
      ),
      bankDetails: const BankDetails(
        accountHolderName: 'Test Owner',
        accountNumber: '000111222',
        ifscCode: 'TEST0001',
      ),
    ),
  );
  repo.simulateApproval();
  return repo;
}

void main() {
  testWidgets('unregistered shop sees the registration form first', (
    tester,
  ) async {
    await tester.pumpWidget(ShopApp(repository: ShopRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Register your shop'), findsOneWidget);
  });

  testWidgets('submitting registration moves to the pending-review screen', (
    tester,
  ) async {
    final repository = ShopRepository();
    await tester.pumpWidget(ShopApp(repository: repository));
    await tester.pumpAndSettle();

    repository.register(
      ShopProfile(
        businessName: 'Test Bakery',
        ownerName: 'Test Owner',
        phone: '9999999999',
        email: 'owner@test.com',
        category: ShopCategory.bakery,
        addressLine: '1 Test Street',
        locality: 'Test Locality',
        fssai: FssaiLicense(
          licenseNumber: 'FSSAI123',
          expiresAt: DateTime.now().add(const Duration(days: 365)),
        ),
        bankDetails: const BankDetails(
          accountHolderName: 'Test Owner',
          accountNumber: '000111222',
          ifscCode: 'TEST0001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Under review'), findsOneWidget);

    await tester.tap(find.text('Simulate approval'));
    await tester.pumpAndSettle();

    expect(find.text('Your bags'), findsOneWidget);
  });

  testWidgets('a verified shop launches to the bag list with seeded fixtures', (
    tester,
  ) async {
    await tester.pumpWidget(ShopApp(repository: _verifiedRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Your bags'), findsOneWidget);
    expect(find.text('Bakery Surprise Bag'), findsOneWidget);
  });

  testWidgets('Orders tab shows seeded orders', (tester) async {
    await tester.pumpWidget(ShopApp(repository: _verifiedRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsWidgets);
    expect(find.text('For Aditi'), findsOneWidget);
  });
}
