# AWTAD Mobile

Flutter Android client for the reconstructed `awtad_retail` Dart baseline.

This environment does not include Flutter, a JDK, or the Android SDK, and must not install them. No local APK can be produced here. Build the APK on CI or on a machine that already has the Flutter Android toolchain.

## Layout

- `lib/main.dart` — Arabic RTL app entry
- `lib/core/database` — SQLite schema v1 and transactional cash/credit UoWs
- `lib/presentation` — splash, six destinations, settings seeds
- `android/` — Gradle application id `com.awtad.retail`

Sales UI calls `CompleteSaleService` and `CreditSaleService` only. SQLite commits inventory, sale, and optional ledger entry in one `BEGIN`/`COMMIT`. Decrement batches use `SAVEPOINT decrement_batch`.

## External APK

```bash
cd apps/awtad_mobile
flutter pub get
flutter test
flutter build apk --release
```

Copy the artifact to the repository root (CI does this automatically):

```bash
cp build/app/outputs/flutter-apk/app-release.apk ../../awtad-retail.apk
```

GitHub Actions workflow: `.github/workflows/android-apk.yml`.
