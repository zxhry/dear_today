import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/settings_store.dart';
import '../../security/app_lock.dart';
import '../../security/backup.dart';
import '../../theme.dart';

/// Create a backup: choose a password, seal everything, then share the file
/// to wherever you keep it (Google Drive, Telegram, your laptop...).
Future<void> createBackupFlow(BuildContext context) async {
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _PasswordDialog(creating: true),
  );
  if (password == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final file = await _withProgress(context, 'Sealing your backup…', () => Backup.create(password));
  if (file == null || !context.mounted) return;

  final result = await AppLock.instance.stepOutside(
    () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Dear Today backup')),
  );
  final saved = result.status != ShareResultStatus.dismissed;
  if (saved) await SettingsStore.instance.markBackedUp();
  messenger.showSnackBar(SnackBar(
    content: Text(saved
        ? 'Backup saved. Keep your password somewhere safe!'
        : 'Backup wasn\'t saved anywhere. Try again when you\'re ready.'),
  ));
}

/// Restore: pick a .dtb file, enter its password, and add what's in it.
Future<void> restoreBackupFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await AppLock.instance.stepOutside(() => FilePicker.pickFile());
  if (picked == null || !context.mounted) return;
  // (The picker's result type differs between file_picker versions; both have a path.)
  final path = (picked as dynamic).path as String?;
  if (path == null) return;

  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _PasswordDialog(creating: false),
  );
  if (password == null || !context.mounted) return;

  final added = await _withProgress(context, 'Opening your backup…', () => Backup.restore(File(path), password));
  if (added == null) return;
  messenger.showSnackBar(SnackBar(
    content: Text(added == 0 ? 'Everything in that backup is already here.' : 'Restored $added ${added == 1 ? 'item' : 'items'}.'),
  ));
}

/// Shows a "please wait" dialog while [work] runs. Returns null on failure
/// (after showing what went wrong).
Future<T?> _withProgress<T>(BuildContext context, String message, Future<T> Function() work) async {
  final t = context.dt;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 18),
            Expanded(child: Text(message, style: Fonts.sans(15, t.text))),
          ],
        ),
      ),
    ),
  );
  var open = true;
  void close() {
    if (open) {
      open = false;
      nav.pop(); // closes only the "please wait" dialog
    }
  }

  try {
    final result = await work();
    close();
    return result;
  } catch (e) {
    close();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Hmm…', style: Fonts.serif(24, t.text)),
          content: Text(e is BackupException ? e.message : 'Something went wrong: $e',
              style: Fonts.sans(14, t.muted, height: 1.45)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
    return null;
  }
}

class _PasswordDialog extends StatefulWidget {
  final bool creating; // true = choose a new password (typed twice)
  const _PasswordDialog({required this.creating});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _pw = TextEditingController();
  final _again = TextEditingController();
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    final pw = _pw.text;
    if (widget.creating) {
      if (pw.length < Backup.minPasswordLength) {
        setState(() => _error = 'Use at least ${Backup.minPasswordLength} characters.');
        return;
      }
      if (pw != _again.text) {
        setState(() => _error = 'The two passwords don\'t match.');
        return;
      }
    } else if (pw.isEmpty) {
      setState(() => _error = 'Enter the backup\'s password.');
      return;
    }
    Navigator.pop(context, pw);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        );

    return AlertDialog(
      title: Text(widget.creating ? 'Lock your backup' : 'Open your backup', style: Fonts.serif(24, t.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.creating
                  ? 'Choose a password for this backup. You\'ll need it to restore your stamps, diary and vlog on any phone.'
                  : 'Enter the password you chose when you made this backup.',
              style: Fonts.sans(13, t.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pw,
              obscureText: _hidden,
              autofocus: true,
              decoration: deco('Backup password'),
              onSubmitted: (_) => widget.creating ? null : _submit(),
            ),
            if (widget.creating) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _again,
                obscureText: _hidden,
                decoration: deco('Type it again'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'If you forget this password, nobody can open the backup, not even you. '
                  'Write it down somewhere safe.',
                  style: Fonts.sans(12, t.text, weight: FontWeight.w600, height: 1.4),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: Fonts.sans(13, t.accent, weight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: Fonts.sans(14, t.muted))),
        TextButton(
          onPressed: _submit,
          child: Text(widget.creating ? 'Create backup' : 'Restore', style: Fonts.sans(14, t.text, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}
