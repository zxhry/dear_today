import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/dates.dart';

/// Small building blocks shared by every screen, so they all look the same.

/// A round 44px button with an outline (back, settings, switch camera...).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  const CircleIconButton({super.key, required this.icon, required this.tooltip, this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.surf,
        shape: CircleBorder(side: BorderSide(color: t.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, size: 19, color: t.text)),
        ),
      ),
    );
  }
}

/// The filled main button (Save, Share, Play all, + New set).
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  const PrimaryButton({super.key, required this.label, this.icon, this.onTap, this.height = 50});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: t.fabBg,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: t.fabFg), const SizedBox(width: 6)],
                Flexible(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.sans(15, t.fabFg, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined second button (Edit, Export backup).
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  const SecondaryButton({super.key, required this.label, this.icon, this.onTap, this.height = 50});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Material(
      color: t.surf,
      shape: StadiumBorder(side: BorderSide(color: t.dim)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: t.text), const SizedBox(width: 6)],
              Flexible(
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "DEAR TODAY", "EARLIER", "MILESTONES"...
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Fonts.label(context.dt.muted));
}

/// Space above every page's first line, so headers sit at the same height
/// on every page. Tabs start a little lower; pages with a back button use
/// that row instead.
double pageTop(BuildContext context, {bool pushed = false}) =>
    MediaQuery.paddingOf(context).top + (pushed ? 10 : 18);

/// The gap between a header and the page below it.
const double headerGap = 18;

/// The row at the top of a page you opened: back on the left, actions right.
class TopBar extends StatelessWidget {
  final List<Widget> actions;
  const TopBar({super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
            const Spacer(),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        ),
      );
}

/// The header every page uses: a small capitals line, the serif title, and
/// anything that belongs to the page on the right (chips, a settings button).
class PageHeader extends StatelessWidget {
  final String label;
  final String title;
  final List<Widget> actions;
  const PageHeader({super.key, required this.label, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.label(t.muted)),
              const SizedBox(height: 6),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Fonts.serif(32, t.text)),
            ],
          ),
        ),
        for (final a in actions) ...[
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 2), child: a),
        ],
      ],
    );
  }
}

/// A small rounded chip for page headers ("18 days", "0:24", "+ New set").
class HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;
  const HeaderChip({super.key, required this.icon, required this.label, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final chip = Material(
      color: t.surf2,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: t.text),
              const SizedBox(width: 6),
              Text(label, style: Fonts.mono(12, t.text)),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// A big serif page title with a small line under it.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double size;
  const PageTitle(this.title, {super.key, this.subtitle, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Fonts.serif(size, t.text)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Fonts.sans(14, t.muted)),
        ],
      ],
    );
  }
}

/// A rounded chip with an icon ("Home", "November 2026", "Encrypted").
class MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const MetaChip({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Material(
      color: t.surf,
      shape: StadiumBorder(side: BorderSide(color: t.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: t.muted),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Fonts.sans(13, t.text))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tabs with an underline (Timeline / Photos).
class UnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  const UnderlineTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: i == selected ? t.accent : Colors.transparent, width: 3)),
                  ),
                  child: Text(labels[i],
                      style: Fonts.sans(15, i == selected ? t.text : t.muted, weight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small segmented choice (Light / Dark / System, 720p / 1080p).
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool mono;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options)
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == value ? t.surf : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: mono
                      ? Fonts.mono(12, v == value ? t.text : t.muted)
                      : Fonts.sans(12, v == value ? t.text : t.muted, weight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded card holding rows separated by thin lines (used in Settings).
class CardGroup extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  const CardGroup({super.key, required this.children, this.dividerIndent = 60});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Container(
      decoration: BoxDecoration(
        color: t.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: dividerIndent, color: t.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row in a [CardGroup]: icon tile, title, small line, something on the right.
class SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const SettingsRow({super.key, this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 17, color: t.text),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Fonts.sans(15, t.text, weight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!, style: Fonts.sans(12, t.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              if (trailing == null && onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round ink postmark: "DEAR TODAY / 14 NOV 26 / 6:42 PM".
class Postmark extends StatelessWidget {
  final DateTime when;
  final double size;
  const Postmark({super.key, required this.when, this.size = 92});

  @override
  Widget build(BuildContext context) {
    final ink = context.dt.ink;
    final k = size / 92;
    return Opacity(
      opacity: 0.85,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ink, width: 2 * k)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('DEAR TODAY', style: Fonts.mono(8.5 * k, ink, spacing: 1)),
            Container(
              margin: EdgeInsets.symmetric(vertical: 2 * k),
              padding: EdgeInsets.symmetric(horizontal: 4 * k, vertical: 1),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: ink, width: 1.5 * k)),
              ),
              child: Text(postmarkDate(when), style: Fonts.mono(12.5 * k, ink)),
            ),
            Text(clockTime(when), style: Fonts.mono(8.5 * k, ink, spacing: 1)),
          ],
        ),
      ),
    );
  }
}

/// A quiet message for empty pages.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyNote({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 34, color: t.dim),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: Fonts.sans(14, t.muted, height: 1.45)),
        ],
      ),
    );
  }
}

// ---------- dialogs ----------

/// Asks for one line of text (a set's name). Returns null when cancelled.
Future<String?> askText(BuildContext context,
    {required String title, String initial = '', String hint = '', String action = 'Save'}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(title: title, initial: initial, hint: hint, action: action),
  );
}

class _TextDialog extends StatefulWidget {
  final String title, initial, hint, action;
  const _TextDialog({required this.title, required this.initial, required this.hint, required this.action});

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() {
    if (_c.text.trim().isEmpty) return;
    Navigator.pop(context, _c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return AlertDialog(
      title: Text(widget.title, style: Fonts.serif(24, t.text)),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 40,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: Fonts.sans(14, t.muted))),
        TextButton(
            onPressed: _done, child: Text(widget.action, style: Fonts.sans(14, t.text, weight: FontWeight.w700))),
      ],
    );
  }
}

/// "Are you sure?" Returns true when confirmed.
Future<bool> confirm(BuildContext context,
    {required String title, required String message, String action = 'Delete'}) async {
  final t = context.dt;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: Fonts.serif(24, t.text)),
      content: Text(message, style: Fonts.sans(14, t.muted, height: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: Fonts.sans(14, t.muted))),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action, style: Fonts.sans(14, t.accent, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
