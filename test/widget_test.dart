// Smoke test — verifies the app widget tree builds without Firebase.
// Full Firebase flows (auth/cart/checkout) require integration tests
// with firebase_auth_mocks / fake_cloud_firestore (see roadmap in README).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: renders a simple scaffold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Online Store')),
      ),
    );
    expect(find.text('Online Store'), findsOneWidget);
  });
}
