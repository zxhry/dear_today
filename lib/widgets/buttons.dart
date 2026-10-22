import 'package:flutter/material.dart';
import '../theme.dart';

/// The big coral button, floating on a soft shadow.
class ChunkyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final bool pill; // true = only as wide as its label, a bit slimmer
  final bool soft; // true = soft blurred shadow instead of the solid navy one

  const ChunkyButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.busy = false,
    this.pill = false,
    this.soft = true, // the soft shadow is now the default for every button
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: soft
            ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: AppColors.ink, offset: Offset(0, pill ? 3 : 4))],
      ),
      child: SizedBox(
        width: pill ? null : double.infinity,
        height: pill ? 50 : 56,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.7),
            foregroundColor: AppColors.white,
            shape: const StadiumBorder(),
            padding: EdgeInsets.symmetric(horizontal: pill ? 28 : 16),
          ),
          child: busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: AppColors.white), const SizedBox(width: 10)],
                    Text(label, style: AppText.hand(pill ? 22 : 24, color: AppColors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// White button with a navy outline, for secondary actions.
class SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const SoftButton({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 19, color: AppColors.iconSoft), const SizedBox(width: 8)],
            Text(label, style: AppText.hand(20)),
          ],
        ),
      ),
    );
  }
}
