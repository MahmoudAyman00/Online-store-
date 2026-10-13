# Online Store — Flutter + Firebase

A full e-commerce app: role-based auth (user/admin), categories & products CRUD,
cart, atomic checkout, order receipts, feedback, transaction reports, and a
best-selling chart — with voice search and barcode search.

> Status: college project hardened toward production. See `PROJECT_REPORT.md`
> for the security/architecture audit and roadmap.

## Features

**Buyer**
- Email/password signup with verification, login, password reset, remember-me (email only — never stores passwords)
- Browse categories → products, text / voice / barcode search
- Cart (add, quantity +/-, checkout), order receipt with `orderId`
- Rate the order + comment (feedback linked to order)

**Admin**
- Guarded admin panel (UI guard + Firestore rules enforcement)
- Add / update / delete products & categories
- Transaction report by date, customer feedback browser, best-selling chart

**Security (already applied)**
- `firestore.rules` + `storage.rules`: public product read, admin-only writes,
  users read/write own docs only, `role` immutable by client, transactions append-only
  with anti-spam caps, storage client writes denied (app uses URL strings)
- Atomic checkout via `runTransaction`: server-verified prices, stock decrement,
  `soldCount` increment, cart clear — all-or-nothing
- No plaintext credentials, email verification enforced, strong-password + phone validators

## Tech stack

Flutter (Material) · Firebase Auth · Cloud Firestore · Firebase Storage (rules only) ·
`cached_network_image` · `speech_to_text` · `flutter_barcode_scanner` · `fl_chart` ·
`shared_preferences` · `intl`

## Getting started

### 1. Prerequisites
- Flutter SDK (see `pubspec.yaml` for Dart constraint)
- A Firebase project with Auth (Email/Password) + Firestore enabled

### 2. Install
```bash
flutter pub get
```

### 3. Configure Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure   # regenerates lib/firebase_options.dart
```

### 4. Deploy security rules + functions
```bash
firebase deploy --only firestore:rules,storage
cd functions && npm install && cd ..
firebase deploy --only functions
```

### 5. Bootstrap first admin
```bash
firebase functions:secrets:set SETUP_SECRET
# then call bootstrapFirstAdmin({secret, uid}) once from your app/CLI,
# afterwards manage admins via setAdminRole (caller must be admin)
```

### 6. Seed roles (transitional)
- Register a user from the app, then in Firestore Console set
  `Users Collection/<uid>.role = "admin"` for your admin account.
  (Client code can never escalate roles — rules reject `role` changes.)
- Enable Email verification templates in Firebase Console → Auth.

### 6. Run
```bash
flutter run
```

## Testing

Pure business logic lives in `lib/core/validators.dart` (no Firebase) so it
runs without mocks:

```bash
flutter test
```

- `test/validators_test.dart` — email / password / phone / role rules
- `test/cart_total_test.dart` — cart total math + negative rejection
- `test/widget_test.dart` — smoke test (full Firebase flows need
  `firebase_auth_mocks` / `fake_cloud_firestore` — planned)

## Project structure

```
lib/
  core/validators.dart      # pure logic (tested)
  screen/                   # UI screens (auth, home, products, cart, admin…)
  main.dart                 # Firebase init + theme
  firebase_options.dart     # generated (do not hand-edit)
firestore.rules             # least-privilege DB rules
storage.rules               # deny client writes (URLs only)
test/                       # unit + smoke tests
PROJECT_REPORT.md           # audit: strengths, gaps, roadmap
```

## Collections (Firestore)

| Collection | Access |
|---|---|
| `Users Collection/{uid}` | owner or admin; `role` immutable by client |
| `Users Collection/{uid}/Cart/*` | owner only |
| `Categories`, `products` | read public, write admin only |
| `Transactions` | create signed-in (caps: ≤50 items, ≤500k total), read owner/admin, no edit |
| `Feedbacks` | create signed-in (rating 1-5, comment ≤1000), read owner/admin |

> Note: `Users Collection` keeps its legacy name with a space. A future
> migration should rename to `users` (lowercase, no spaces) with a data migration.

## Roadmap to production

- [ ] Cloud Function `checkout()` — move price/stock logic fully server-side
- [ ] Custom Claims (`auth.token.admin`) instead of Firestore-role admin check
- [ ] App Check + rate limiting (abuse protection)
- [ ] Riverpod/Bloc + repositories, pagination, offline cache
- [ ] Payments, order tracking, FCM push, analytics
- [ ] CI (`analyze` + `test` + release build), flavors (dev/prod), golden tests

## Screenshots

_Add `docs/screenshots/*.png` (login, home, product, cart, receipt, admin panel) —
recommended before adding to a CV._
