import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/journal_store.dart';
import '../../models/models.dart';
import '../../security/app_lock.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui.dart';
import '../../widgets/vault_image.dart';

/// Write a new diary note, or change one you wrote earlier.
class NoteScreen extends StatefulWidget {
  final DiaryEntry? editing;
  final String prompt; // today's question, when writing from the prompt card
  const NoteScreen({super.key, this.editing, this.prompt = ''});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  late final _text = TextEditingController(text: widget.editing?.text ?? '');
  late final List<String> _kept = [...?widget.editing?.photos]; // encrypted photos already saved
  final List<String> _picked = []; // new photos, not saved yet
  late final DateTime _at = widget.editing?.at ?? DateTime.now();
  late String _mood = widget.editing?.mood ?? '';
  late final String _prompt = widget.editing?.prompt ?? widget.prompt;
  bool _alsoStamp = false;
  bool _busy = false;

  bool get _editing => widget.editing != null;
  bool get _changed =>
      _text.text.trim() != (widget.editing?.text ?? '') ||
      _picked.isNotEmpty ||
      _mood != (widget.editing?.mood ?? '') ||
      _kept.length != (widget.editing?.photos.length ?? 0);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhotos(ImageSource source) async {
    final picker = ImagePicker();
    final files = await AppLock.instance.stepOutside(() async {
      if (source == ImageSource.camera) {
        final one = await picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
        return one == null ? <XFile>[] : [one];
      }
      return picker.pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
    });
    if (files.isEmpty || !mounted) return;
    setState(() => _picked.addAll(files.map((f) => f.path)));
  }

  Future<void> _save() async {
    if (_busy) return;
    final text = _text.text.trim();
    if (text.isEmpty && _kept.isEmpty && _picked.isEmpty) {
      toast(context, 'Write something or add a photo first.');
      return;
    }
    setState(() => _busy = true);
    final store = JournalStore.instance;
    try {
      if (_alsoStamp && _picked.isNotEmpty) {
        final firstLine = text.split('\n').first;
        await store.addStamp(
          photo: _picked.first,
          shape: StampShape.portrait,
          title: firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine,
          deleteSource: false, // the note below still needs this photo
        );
      }
      await store.saveEntry(
        editing: widget.editing,
        text: text,
        keptPhotos: _kept,
        newPhotos: _picked,
        mood: _mood,
        prompt: _prompt,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save note: $e');
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Couldn\'t save the note. Try again.');
      }
    }
  }

  Future<void> _cancel() async {
    if (_changed) {
      final leave = await confirm(context,
          title: 'Leave without saving?', message: 'What you wrote here won\'t be kept.', action: 'Leave');
      if (!leave) return;
    }
    for (final p in _picked) {
      await JournalStore.deleteQuietly(p); // the picker's temporary copies
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'Delete this note?', message: 'The note and its photos will be gone for good.');
    if (!ok) return;
    await JournalStore.instance.deleteEntry(widget.editing!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final thumbs = <Widget>[
      for (final p in _kept)
        _Thumb(
          image: VaultImage(path: p, decodeWidth: 240, fallback: Container(color: t.surf2)),
          onRemove: () => setState(() => _kept.remove(p)),
        ),
      for (final p in _picked)
        _Thumb(
          image: Image.file(File(p), fit: BoxFit.cover, cacheWidth: 240),
          onRemove: () {
            setState(() => _picked.remove(p));
            JournalStore.deleteQuietly(p);
          },
        ),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton(onPressed: _cancel, child: Text('Cancel', style: Fonts.sans(15, t.muted))),
                    Expanded(
                      child: Text(_editing ? 'Edit note' : 'New note',
                          textAlign: TextAlign.center, style: Fonts.serif(19, t.text)),
                    ),
                    PrimaryButton(label: _busy ? 'Saving…' : 'Save', height: 40, onTap: _busy ? null : _save),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MetaChip(
                      icon: Icons.schedule_rounded,
                      label: '${shortWeekday(_at).toUpperCase()} ${_at.day} ${shortMonth(_at).toUpperCase()} · ${clockTime(_at)}',
                    ),
                    const MetaChip(icon: Icons.menu_book_outlined, label: 'My days'),
                  ],
                ),
                const SizedBox(height: 4),
                // Everything you write or add scrolls, so a tall keyboard
                // (like the emoji one) never squeezes the page.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    children: [
                      if (thumbs.isNotEmpty) ...[
                        SizedBox(
                          height: 104,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(top: 8, right: 8, bottom: 4),
                            itemCount: thumbs.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => thumbs[i],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_prompt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(_prompt, style: Fonts.serif(18, t.accent).copyWith(height: 1.3)),
                      ],
                      TextField(
                        controller: _text,
                        autofocus: !_editing,
                        minLines: 3,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: Fonts.sans(15.5, t.text, height: 1.6),
                        decoration: InputDecoration(
                          hintText: _prompt.isEmpty ? 'what happened just now? add #tags if you like' : 'write your answer…',
                          hintStyle: Fonts.sans(15.5, t.muted.withValues(alpha: 0.7), height: 1.6),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Text('HOW DID IT FEEL?', style: Fonts.label(t.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in moods)
                            ChoiceChip(
                              label: Text(m),
                              selected: _mood == m,
                              showCheckmark: false,
                              labelStyle: Fonts.sans(13, _mood == m ? t.fabFg : t.text, weight: FontWeight.w500),
                              selectedColor: t.fabBg,
                              backgroundColor: t.surf,
                              side: BorderSide(color: _mood == m ? t.fabBg : t.border),
                              shape: const StadiumBorder(),
                              onSelected: (on) => setState(() => _mood = on ? m : ''),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_picked.isNotEmpty)
                        CardGroup(
                          children: [
                            SettingsRow(
                              title: 'Also keep photo as a stamp',
                              subtitle: 'Adds it to your stamp collection too',
                              trailing: Switch(value: _alsoStamp, onChanged: (v) => setState(() => _alsoStamp = v)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleIconButton(
                        icon: Icons.photo_camera_outlined,
                        tooltip: 'Take photo',
                        onTap: () => _addPhotos(ImageSource.camera)),
                    const SizedBox(width: 10),
                    CircleIconButton(
                        icon: Icons.photo_library_outlined,
                        tooltip: 'Choose from gallery',
                        onTap: () => _addPhotos(ImageSource.gallery)),
                    const Spacer(),
                    if (_editing)
                      TextButton.icon(
                        onPressed: _delete,
                        icon: Icon(Icons.delete_outline_rounded, color: t.accent, size: 18),
                        label: Text('Delete note', style: Fonts.sans(14, t.accent, weight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget image;
  final VoidCallback onRemove;
  const _Thumb({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 90, height: 90, child: image)),
        Positioned(
          right: -6,
          top: -6,
          child: Semantics(
            button: true,
            label: 'Remove photo',
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: t.fabBg, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                child: Icon(Icons.close_rounded, size: 14, color: t.fabFg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
