import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart'; // ChangeNotifier + AppLifecycleListener
import 'package:path_provider/path_provider.dart';

import '../models/future_letter.dart';
import '../security/vault.dart';
import '../utils/dates.dart';

/// Letters to tomorrow, saved encrypted in tomorrow.dt.
///
/// The "lock until tomorrow" follows the phone's date. It's about the fun of
/// waiting, not secrecy: the letter itself is still encrypted like the rest.
class TomorrowStore extends ChangeNotifier {
  TomorrowStore._();
  static final instance = TomorrowStore._();

  final List<FutureLetter> _items = [];

  DateTime get _today => dayOnly(DateTime.now());
  bool isLocked(FutureLetter f) => DateTime.now().isBefore(f.arrivesAt);

  Timer? _arrival;
  AppLifecycleListener? _life;

  /// Refresh the mailbox the moment the next letter arrives, and whenever
  /// you come back to the app (in case it arrived while you were away).
  void _watchArrivals() {
    _life ??= AppLifecycleListener(onResume: notifyListeners);
    _arrival?.cancel();
    final next = waiting.isEmpty ? null : waiting.first.arrivesAt;
    if (next == null) return;
    _arrival = Timer(next.difference(DateTime.now()) + const Duration(seconds: 1), () {
      notifyListeners();
      _watchArrivals();
    });
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _watchArrivals();
  }

  /// Still sealed, soonest first.
  List<FutureLetter> get waiting =>
      // (A letter you've already read never counts as waiting.)
      _items.where((f) => isLocked(f) && !f.opened).toList()..sort((a, b) => a.openOn.compareTo(b.openOn));

  /// Unlocked but not read yet: "you've got mail".
  List<FutureLetter> get arrived =>
      _items.where((f) => !isLocked(f) && !f.opened).toList()..sort((a, b) => a.openOn.compareTo(b.openOn));

  /// Already read, newest first.
  List<FutureLetter> get read =>
      _items.where((f) => f.opened).toList()..sort((a, b) => b.openOn.compareTo(a.openOn));

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/tomorrow.dt');

  Future<void> load() async {
    final file = await _file();
    if (!await file.exists()) return;
    try {
      final clear = await Vault.instance.unseal(await file.readAsBytes());
      final list = jsonDecode(utf8.decode(clear)) as List;
      _items
        ..clear()
        ..addAll(list.map((e) => FutureLetter.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      await file.rename('${file.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}');
      debugPrint('tomorrow.dt could not be read and was set aside: $e');
    }
    notifyListeners();
  }

  Future<void> add(String body) async {
    final t = _today;
    _items.add(FutureLetter(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      writtenAt: DateTime.now(),
      openOn: DateTime(t.year, t.month, t.day + 1),
      body: body.trim(),
    ));
    await _save();
    notifyListeners();
  }

  Future<FutureLetter> markOpened(FutureLetter f) async {
    final updated = f.markOpened();
    final i = _items.indexWhere((x) => x.id == f.id);
    if (i >= 0) _items[i] = updated;
    await _save();
    notifyListeners();
    return updated;
  }

  Future<void> delete(FutureLetter f) async {
    _items.removeWhere((x) => x.id == f.id);
    await _save();
    notifyListeners();
  }

  // ---- backup support ----
  List<Map<String, dynamic>> toJsonList() => _items.map((f) => f.toJson()).toList();

  /// Adds tomorrow-letters from a backup, skipping ones already here.
  Future<int> importFrom(List<Map<String, dynamic>> entries) async {
    var added = 0;
    for (final j in entries) {
      final f = FutureLetter.fromJson(j);
      if (_items.any((x) => x.id == f.id)) continue;
      _items.add(f);
      added++;
    }
    if (added > 0) {
      await _save();
      notifyListeners();
    }
    return added;
  }

  Future<void> _save() async {
    final file = await _file();
    final sealed = await Vault.instance.seal(utf8.encode(jsonEncode(toJsonList())));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(file.path);
  }
}
