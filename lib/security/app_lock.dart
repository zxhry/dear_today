import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../data/settings_store.dart';
import '../theme.dart';
import '../widgets/buttons.dart';

/// Decides when Dear Today is locked, and unlocks it with the phone's own
/// fingerprint / face / PIN screen. The app never sees the fingerprint or
/// PIN itself: Android just answers "yes, it's the owner" or "no".
class AppLock extends ChangeNotifier {
  AppLock._();
  static final instance = AppLock._();

  /// Coming back after this long away locks the app again.
  static const grace = Duration(seconds: 30);

  final _auth = LocalAuthentication();
  bool _locked = false;
  bool _busy = false; // the PIN screen can briefly send us to the background
  int _tripsOutside = 0; // our own trips to the camera or gallery
  DateTime? _leftAt;
  String? lastError;

  bool get locked => _locked;

  void lockIfEnabled() {
    if (SettingsStore.instance.lockEnabled && !_locked) {
      _locked = true;
      lastError = null; // a fresh lock page starts without old messages
      notifyListeners();
    }
  }

  /// Does this phone have a fingerprint, face or screen lock set up?
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows Android's fingerprint / face / PIN prompt. True if it was the owner.
  Future<bool> verify(String reason) async {
    if (_busy) return false;
    _busy = true;
    lastError = null;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // allow the phone PIN/pattern as a backup
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      lastError = (e.code == LocalAuthExceptionCode.temporaryLockout ||
              e.code == LocalAuthExceptionCode.biometricLockout)
          ? 'Too many tries. Wait a moment, then use your phone PIN.'
          : 'Not unlocked. Tap Unlock to try again.';
      debugPrint('App lock: $e');
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> unlock() async {
    if (await verify('Unlock your letters')) _locked = false;
    notifyListeners();
  }

  /// For actions that leave the app on purpose (camera, gallery), so coming
  /// back from them doesn't lock you out mid-letter.
  Future<T> stepOutside<T>(Future<T> Function() action) async {
    _tripsOutside++;
    try {
      return await action();
    } finally {
      _tripsOutside--;
    }
  }

  void _onLeft() {
    if (_busy || _tripsOutside > 0) return;
    _leftAt = DateTime.now();
  }

  void _onReturned() {
    final left = _leftAt;
    _leftAt = null;
    if (left != null && DateTime.now().difference(left) >= grace) lockIfEnabled();
  }
}

/// Wraps the whole app: shows the lock screen on top while locked, and
/// watches for the app going to the background.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: AppLock.instance._onLeft,
      onShow: AppLock.instance._onReturned,
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLock.instance,
      builder: (context, _) {
        final locked = AppLock.instance.locked;
        return Stack(
          children: [
            // The app stays alive underneath (so an unfinished letter isn't
            // lost), but hidden and silent while locked.
            Offstage(offstage: locked, child: ExcludeSemantics(excluding: locked, child: widget.child)),
            if (locked) const _LockScreen(),
          ],
        );
      },
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  // The lock page waits for a tap on "Unlock" before asking for the PIN.
  @override
  Widget build(BuildContext context) {
    // Listen to AppLock so an error message appears after a failed try.
    return ListenableBuilder(listenable: AppLock.instance, builder: (context, _) => _content());
  }

  Widget _content() {
    final error = AppLock.instance.lastError;
    return Material(
      color: AppColors.paper,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Sealed envelope.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 96, color: AppColors.ink),
                  Positioned(
                    right: -6,
                    bottom: 8,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), spreadRadius: 3)],
                      ),
                      child: const Icon(Icons.lock_outline, size: 20, color: AppColors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Dear Today,', style: AppText.hand(40)),
              const SizedBox(height: 8),
              Text('Your letters are sealed.', style: AppText.body(15, color: AppColors.inkSoft)),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error, textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.accent)),
              ],
              const Spacer(flex: 4),
              // A neutral lock icon, since it may ask for a PIN, fingerprint or face.
              ChunkyButton(label: 'Unlock', icon: Icons.lock_open_rounded, onTap: AppLock.instance.unlock),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
