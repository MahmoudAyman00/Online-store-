import 'package:flutter_test/flutter_test.dart';
import 'package:onlineshoppingapp/core/validators.dart';

void main() {
  group('calculateCartTotal', () {
    test('sums price * quantity', () {
      final items = [
        {'price': 10.0, 'quantity': 2},
        {'price': 5.5, 'quantity': 3},
      ];
      expect(calculateCartTotal(items), closeTo(36.5, 0.001));
    });

    test('accepts int prices from Firestore', () {
      final items = [
        {'price': 10, 'quantity': 1},
        {'price': 20, 'quantity': 2},
      ];
      expect(calculateCartTotal(items), 50.0);
    });

    test('empty cart = 0', () {
      expect(calculateCartTotal([]), 0.0);
    });

    test('rejects negative values', () {
      expect(
        () => calculateCartTotal([
          {'price': -5, 'quantity': 1}
        ]),
        throwsArgumentError,
      );
    });
  });
}
