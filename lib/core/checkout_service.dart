import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Calls the server-side `checkout` function.
/// Throws [CheckoutException] with a user-friendly message on failure.
class CheckoutService {
  CheckoutService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<CheckoutResult> checkout(
      List<Map<String, dynamic>> cartItems) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const CheckoutException('Please login first.');
    if (cartItems.isEmpty) throw const CheckoutException('Cart is empty.');

    try {
      final callable = _functions.httpsCallable('checkout');
      final res = await callable.call({
        'items': cartItems
            .map((e) => {
                  'productId': e['productId'].toString(),
                  'quantity': (e['quantity'] as num).toInt(),
                })
            .toList(),
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final items = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return CheckoutResult(
        orderId: data['orderId'].toString(),
        totalPrice: (data['totalPrice'] as num).toDouble(),
        items: items,
      );
    } on FirebaseFunctionsException catch (e) {
      throw CheckoutException(_friendly(e), code: e.code);
    }
  }

  String _friendly(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please login first.';
      case 'permission-denied':
        return 'Please verify your email first.';
      case 'failed-precondition':
      case 'not-found':
      case 'invalid-argument':
        return e.message ?? 'Checkout failed.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network error. Try again.';
      default:
        return e.message ?? 'Checkout failed. Try again.';
    }
  }
}

class CheckoutResult {
  const CheckoutResult(
      {required this.orderId, required this.totalPrice, required this.items});
  final String orderId;
  final double totalPrice;
  final List<Map<String, dynamic>> items;
}

class CheckoutException implements Exception {
  const CheckoutException(this.message, {this.code = ''});
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// Admin check: Custom Claims first, Firestore role as transitional fallback.
Future<bool> isCurrentUserAdmin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  try {
    final token = await user.getIdTokenResult(true);
    if (token.claims?['admin'] == true) return true;
  } catch (_) {}
  return false; // caller falls back to Firestore role check if needed
}
