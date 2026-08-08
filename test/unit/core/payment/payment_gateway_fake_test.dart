import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/payment/payment_gateway_fake.dart';

void main() {
  group('PaymentGatewayFake', () {
    test('launch completes without throwing', () async {
      const gateway = PaymentGatewayFake();
      await expectLater(gateway.launch('payload_abc'), completes);
    });
  });
}
