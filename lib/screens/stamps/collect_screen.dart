import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/journal_store.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../security/app_lock.dart';
import '../../services/gallery.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/camera_view.dart';
import '../../widgets/stamp.dart';
import '../../widgets/ui.dart';
import 'stamp_screen.dart';

/// The stamp camera: frame a nice moment and press it into a stamp.
class CollectScreen extends StatefulWidget {
  const CollectScreen({super.key});

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> with WidgetsBindingObserver, CameraHost<CollectScreen> {
  final _caption = TextEditingController();
  StampShape _shape = StampShape.portrait;
  String? _setId;
  bool _flash = false;
  bool _busy = false;

  @override
  ResolutionPreset get resolution => ResolutionPreset.veryHigh;
  @override
  bool get withAudio => false;

  @override
  void initState() {
    super.initState();
    startCamera();
  }

  @override
  void dispose() {
    stopCamera();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final c = camera;
    if (c == null) return;
    _flash = !_flash;
    try {
      await c.setFlashMode(_flash ? FlashMode.always : FlashMode.off);
    } catch (_) {
      _flash = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _shoot() async {
    final c = camera;
    if (c == null || _busy || c.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final pic = await c.takePicture();
      if (SettingsStore.instance.saveToGallery) await Gallery.savePlainFile(pic.path, video: false);
      await _keep(pic.path);
    } catch (e) {
      debugPrint('Take picture: $e');
      if (mounted) toast(context, 'Couldn\'t take the photo. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromGallery() async {
    if (_busy) return;
    final picked = await AppLock.instance.stepOutside(
      () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 88),
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _keep(picked.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keep(String path) async {
    final stamp = await JournalStore.instance.addStamp(
      photo: path,
      shape: _shape,
      title: _caption.text,
      setId: _setId,
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StampScreen(stampId: stamp.id)));
  }

  Future<void> _chooseSet() async {
    final t = context.dt;
    final store = JournalStore.instance;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(Icons.calendar_view_month_outlined, color: t.text),
              title: Text('Only this month\'s sheet', style: Fonts.sans(15, t.text)),
              trailing: _setId == null ? Icon(Icons.check_rounded, color: t.accent) : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final set in store.sets)
              ListTile(
                leading: Icon(Icons.folder_outlined, color: t.text),
                title: Text(set.name, style: Fonts.sans(15, t.text)),
                trailing: _setId == set.id ? Icon(Icons.check_rounded, color: t.accent) : null,
                onTap: () => Navigator.pop(context, set.id),
              ),
            ListTile(
              leading: Icon(Icons.add_rounded, color: t.text),
              title: Text('New set…', style: Fonts.sans(15, t.text)),
              onTap: () => Navigator.pop(context, '+'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == '+') {
      final name = await askText(context, title: 'New set', hint: 'Coffee runs, Sky watch…', action: 'Create');
      if (name == null) return;
      final set = await store.addSet(name);
      setState(() => _setId = set.id);
    } else {
      setState(() => _setId = picked.isEmpty ? null : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final store = JournalStore.instance;
    final now = DateTime.now();
    final number = (store.stampsInMonth(now).length + 1).toString().padLeft(3, '0');
    final setName = store.setById(_setId)?.name ?? '${monthName(now)} sheet';
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleIconButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      children: [
                        Text('STAMP No. $number', style: Fonts.mono(11, t.muted, spacing: 1.4)),
                        const SizedBox(height: 2),
                        Text(shortDate(now), style: Fonts.serif(19, t.text)),
                      ],
                    ),
                  ),
                  CircleIconButton(
                    icon: _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    tooltip: _flash ? 'Flash on' : 'Flash off',
                    onTap: _toggleFlash,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // The viewfinder, shaped like the stamp you'll get.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: (_shape.aspect * 280 + 22) / 302, // photo shape plus the paper edge
                    child: StampFrame(
                      holeRadius: 5,
                      child: CameraFill(controller: camera, error: cameraError),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final s in StampShape.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: _shape == s,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _shape = s),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CardGroup(
                dividerIndent: 0,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    child: TextField(
                      controller: _caption,
                      textCapitalization: TextCapitalization.sentences,
                      style: Fonts.serif(18, t.text),
                      decoration: InputDecoration(
                        labelText: 'Caption (optional)',
                        labelStyle: Fonts.sans(12, t.muted),
                        hintText: 'One line about this place',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SettingsRow(
                    title: 'Add to collection',
                    trailing: Text(setName, style: Fonts.sans(14, t.text, weight: FontWeight.w600)),
                    onTap: _chooseSet,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                      icon: Icons.photo_library_outlined, tooltip: 'Choose from gallery', size: 52, onTap: _fromGallery),
                  Semantics(
                    button: true,
                    label: 'Press stamp',
                    child: GestureDetector(
                      onTap: _shoot,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.text, width: 4)),
                        alignment: Alignment.center,
                        child: _busy
                            ? SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: t.accent))
                            : Container(
                                width: 62, height: 62, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.cameraswitch_outlined,
                    tooltip: 'Switch camera',
                    size: 52,
                    onTap: cameras.length > 1 ? switchCamera : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
