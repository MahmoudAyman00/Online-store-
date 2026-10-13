/// Pure validation + business logic (no Firebase/Flutter dependencies)
/// so it can be unit-tested with `flutter test` without mocks.
library;

double calculateCartTotal(List<Map<String, dynamic>> items) {
  double sum = 0;
  for (final item in items) {
    final price = (item['price'] as num).toDouble();
    final qty = (item['quantity'] as num).toInt();
    if (price < 0 || qty < 0) {
      throw ArgumentError('Negative price/quantity');
    }
    sum += price * qty;
  }
  return sum;
}

bool isValidEmail(String value) {
  final v = value.trim();
  if (v.isEmpty || v.length > 254) return false;
  return RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[A-Za-z]{2,}$').hasMatch(v);
}

bool isStrongPassword(String value) {
  return value.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(value) &&
      RegExp(r'[0-9]').hasMatch(value);
}

bool isValidPhone(String value) {
  return RegExp(r'^\+?[0-9\s\-]{8,15}$').hasMatch(value.trim());
}

/// Normalizes Firestore `role` field: trim + lowercase.
/// Returns 'admin', 'user', or '' for missing/invalid.
String normalizeRole(Object? raw) {
  if (raw is! String) return '';
  final r = raw.trim().toLowerCase();
  if (r == 'admin' || r == 'user') return r;
  return '';
}

bool isAdminRole(Object? raw) => normalizeRole(raw) == 'admin';
