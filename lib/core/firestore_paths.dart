/// Single source of truth for Firestore collection names.
/// WARNING: 'Users Collection' keeps its legacy name (with a space).
/// Do NOT rename it without a data migration — rules, functions, and client
/// all reference this exact string.
library;

class FirestorePaths {
  const FirestorePaths._();

  static const users = 'Users Collection';
  static const categories = 'Categories';
  static const products = 'products';
  static const transactions = 'Transactions';
  static const feedbacks = 'Feedbacks';

  static String cart(String uid) => '$users/$uid/Cart';
}

class Roles {
  const Roles._();
  static const admin = 'admin';
  static const user = 'user';
}
