# Dear Today 💌

A small, private photo diary for Android, written as letters.

Each day you write yourself a letter, attach a photo, and seal it with wax. Sealed letters become perforated stamps in your album. You can also write a letter to *tomorrow*, which arrives in your mailbox at 7am the next morning, and each month's letters get bundled together.

I built this for myself and use it every day. It's shared here as a portfolio project.

<!-- Screenshots: take these with dummy entries, not real ones -->
<!--
<p align="center">
  <img src="docs/screenshots/album.png" width="220">
  <img src="docs/screenshots/write.png" width="220">
  <img src="docs/screenshots/mailbox.png" width="220">
</p>
-->

## Features

- **Letters with photos**: write, attach a photo, seal with a wax stamp; edit or delete afterwards
- **Album** of perforated stamps, a **monthly calendar**, and a day view
- **Mailbox**: letters to tomorrow (delivered at 7am with a notification) and monthly bundles
- **Me tab**: profile picture, daily reminder, replayable first-time tour
- **App lock** with fingerprint / device credential

## Privacy and security

Everything stays on the device. There are no accounts, no servers, and no analytics.

- **At rest:** letters and photos are encrypted with AES-256-GCM. The key is randomly generated on first launch and kept in Android Keystore-backed secure storage (`flutter_secure_storage`). Every encryption uses a fresh random nonce.
- **Backups:** exported as a single file encrypted with a key derived from a password you choose (PBKDF2-HMAC-SHA256, 600,000 iterations, 16-byte random salt, then AES-256-GCM). The iteration count is stored in the file header so it can be raised later without breaking old backups.
- **Android:** `allowBackup="false"`, so diary data isn't copied into Google's cloud backups.

**There is no password recovery.** If you forget your backup password, that backup cannot be opened. That's by design.

Backup file format:

```
"DTB1" | iterations (uint32) | salt (16 bytes) | nonce | ciphertext | GCM tag
```

## Project structure

```
lib/
├── data/       # stores for letters, settings, letters-to-tomorrow
├── models/     # Letter, FutureLetter
├── screens/    # one file per screen, plus backup flows
├── security/   # vault (at-rest encryption), backup, app lock
├── services/   # day rollover clock, notifications/reminders
├── widgets/    # stamp, postmark, wax seal, ruled paper, tour overlay…
├── utils/      # date formatting
└── theme.dart
```

## Building

Requires Flutter (Dart SDK ^3.13) and an Android device or emulator (min SDK 24).

```bash
flutter pub get
flutter run            # debug
flutter build apk      # release APK
flutter test
```

Only Android is tested. The app relies on Android notifications and biometrics.

## Built with

[Flutter](https://flutter.dev) · [cryptography](https://pub.dev/packages/cryptography) · [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) · [local_auth](https://pub.dev/packages/local_auth) · [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) · [google_fonts](https://pub.dev/packages/google_fonts)

---

Made by [myokohi](https://github.com/zxhry) · [MIT License](LICENSE)
