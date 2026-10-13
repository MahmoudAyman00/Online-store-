import 'package:flutter_test/flutter_test.dart';
import 'package:onlineshoppingapp/core/validators.dart';

void main() {
  group('email', () {
    test('accepts valid emails', () {
      expect(isValidEmail('user@mail.com'), isTrue);
      expect(isValidEmail('a.b-c@mail.co'), isTrue);
      expect(isValidEmail('  user@mail.com  '), isTrue);
    });
    test('rejects invalid emails', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('user'), isFalse);
      expect(isValidEmail('user@'), isFalse);
      expect(isValidEmail('user@mail'), isFalse);
      expect(isValidEmail('user@@mail.com'), isFalse);
    });
  });

  group('password', () {
    test('accepts strong passwords', () {
      expect(isStrongPassword('abc12345'), isTrue);
      expect(isStrongPassword('Passw0rd!'), isTrue);
    });
    test('rejects weak passwords', () {
      expect(isStrongPassword(''), isFalse);
      expect(isStrongPassword('short1'), isFalse); // < 8
      expect(isStrongPassword('abcdefgh'), isFalse); // no digit
      expect(isStrongPassword('12345678'), isFalse); // no letter
    });
  });

  group('phone', () {
    test('accepts valid phones', () {
      expect(isValidPhone('01012345678'), isTrue);
      expect(isValidPhone('+201012345678'), isTrue);
      expect(isValidPhone('010 1234 5678'), isTrue);
    });
    test('rejects invalid phones', () {
      expect(isValidPhone(''), isFalse);
      expect(isValidPhone('123'), isFalse);
      expect(isValidPhone('abc123456'), isFalse);
    });
  });

  group('role', () {
    test('normalizes roles', () {
      expect(normalizeRole('admin'), 'admin');
      expect(normalizeRole(' Admin '), 'admin');
      expect(normalizeRole('USER'), 'user');
      expect(normalizeRole(null), '');
      expect(normalizeRole('superadmin'), '');
      expect(normalizeRole(123), '');
    });
    test('isAdminRole', () {
      expect(isAdminRole('admin'), isTrue);
      expect(isAdminRole('user'), isFalse);
      expect(isAdminRole(null), isFalse);
    });
  });
}
