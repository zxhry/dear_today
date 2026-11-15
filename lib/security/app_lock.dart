import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../data/settings_store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

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
  int _tripsOutside = 0; // our own trips to the camera, gallery or share sheet
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
    if (await verify('Unlock Dear Today')) _locked = false;
    notifyListeners();
  }

  /// For actions that leave the app on purpose (gallery, share sheet), so
  /// coming back from them doesn't lock you out halfway.
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
            // The app stays alive underneath (so an unfinished note isn't
            // lost), but hidden and silent while locked.
            Offstage(offstage: locked, child: ExcludeSemantics(excluding: locked, child: widget.child)),
            if (locked) const _LockScreen(),
          ],
        );
      },
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen();

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return ListenableBuilder(
      listenable: AppLock.instance,
      builder: (context, _) {
        final error = AppLock.instance.lastError;
        return Material(
          color: t.bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: t.surf2, shape: BoxShape.circle),
                    child: Icon(Icons.lock_outline_rounded, size: 36, color: t.text),
                  ),
                  const SizedBox(height: 24),
                  Text('Dear Today,', style: Fonts.serif(38, t.text)),
                  const SizedBox(height: 8),
                  Text('Your days are locked.', style: Fonts.sans(15, t.muted)),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(error, textAlign: TextAlign.center, style: Fonts.sans(13, t.accent, weight: FontWeight.w600)),
                  ],
                  const Spacer(flex: 4),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(label: 'Unlock', icon: Icons.lock_open_rounded, onTap: AppLock.instance.unlock),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
