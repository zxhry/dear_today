import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/settings_store.dart';
import '../security/app_lock.dart';
import '../security/backup.dart';
import '../theme.dart';

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
    () => SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: 'Dear Today backup',
    )),
  );
  final saved = result.status != ShareResultStatus.dismissed;
  if (saved) await SettingsStore.instance.markBackedUp();
  messenger.showSnackBar(SnackBar(
    content: Text(saved
        ? 'Backup saved. Keep your password somewhere safe!'
        : 'Backup wasn\'t saved anywhere. Try again when you\'re ready.'),
  ));
}

/// Restore: pick a .dtb file, enter its password, and add its letters.
Future<void> restoreBackupFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await AppLock.instance.stepOutside(() => FilePicker.pickFile());
  if (picked == null || !context.mounted) return;

  final bytes = await picked.readAsBytes();
  if (!context.mounted) return;
  if (!Backup.looksLikeBackup(bytes)) {
    await _showProblem(context, 'This isn\'t a Dear Today backup file. Backup files end in .dtb.');
    return;
  }

  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _PasswordDialog(creating: false),
  );
  if (password == null || !context.mounted) return;

  final result = await _withProgress(context, 'Opening your backup…', () => Backup.restore(bytes, password));
  if (result == null) return;
  final (added, skipped) = result;
  messenger.showSnackBar(SnackBar(
    content: Text(added == 0
        ? 'All ${skipped == 1 ? 'that letter is' : 'those letters are'} already here.'
        : 'Restored $added ${added == 1 ? 'letter' : 'letters'}'
            '${skipped > 0 ? ' ($skipped already here)' : ''}.'),
  ));
}

/// Shows a "please wait" dialog while [work] runs. Returns null on failure
/// (after showing what went wrong).
Future<T?> _withProgress<T>(BuildContext context, String message, Future<T> Function() work) async {
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
            Expanded(child: Text(message, style: AppText.body(15))),
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
      await _showProblem(context, e is BackupException ? e.message : 'Something went wrong: $e');
    }
    return null;
  }
}

Future<void> _showProblem(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hmm…', style: AppText.hand(28)),
        content: Text(message, style: AppText.body(14, weight: FontWeight.w500)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );

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
      title: Text(widget.creating ? 'Lock your backup' : 'Open your backup', style: AppText.hand(28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.creating
                  ? 'Choose a password for this backup. You\'ll need it to restore your letters on any phone.'
                  : 'Enter the password you chose when you made this backup.',
              style: AppText.body(13, weight: FontWeight.w500),
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
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'If you forget this password, nobody can open the backup, not even you. '
                  'Write it down somewhere safe.',
                  style: AppText.body(12, weight: FontWeight.w700, color: AppColors.accent),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppText.body(13, color: AppColors.accent)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _submit,
          child: Text(widget.creating ? 'Create backup' : 'Restore'),
        ),
      ],
    );
  }
}
