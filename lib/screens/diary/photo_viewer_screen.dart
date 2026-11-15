import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/vault_image.dart';
import 'note_screen.dart';

/// A diary photo, full size, with the note it belongs to underneath.
/// Swipe left or right for the other photos; pinch to zoom.
class PhotoViewerScreen extends StatefulWidget {
  final List<(DiaryEntry, String)> photos; // newest first
  final int initial;
  const PhotoViewerScreen({super.key, required this.photos, required this.initial});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (entry, _) = widget.photos[_i];
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(child: _FullPhoto(path: widget.photos[i].$2)),
            ),
          ),
          // Top bar: back, when it was taken, edit.
          Positioned(
            left: 12,
            right: 12,
            top: pad.top + 8,
            child: Row(
              children: [
                _RoundButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
                Expanded(
                  child: Text(
                    '${shortDate(entry.at)} · ${clockTime(entry.at)}',
                    textAlign: TextAlign.center,
                    style: Fonts.mono(12, Colors.white, spacing: 0.6),
                  ),
                ),
                _RoundButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit note',
                  onTap: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => NoteScreen(editing: entry))),
                ),
              ],
            ),
          ),
          // The note, under the photo.
          if (entry.text.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 28, 20, pad.bottom + 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
                  child: SingleChildScrollView(
                    child: Text(entry.text, style: Fonts.mono(15, Colors.white, height: 1.55)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FullPhoto extends StatelessWidget {
  final String path;
  const _FullPhoto({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PhotoCache.load(path),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54));
        }
        return Image.memory(snap.data!, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: Colors.white)),
          ),
        ),
      );
}
