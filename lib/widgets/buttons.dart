import 'package:flutter/material.dart';
import '../theme.dart';

/// The big coral button with a solid navy shadow underneath.
class ChunkyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;

  const ChunkyButton({super.key, required this.label, this.icon, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.7),
            foregroundColor: AppColors.white,
            shape: const StadiumBorder(),
          ),
          child: busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: AppColors.white), const SizedBox(width: 10)],
                    Text(label, style: AppText.hand(24, color: AppColors.white)),
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
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 2),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Text(label, style: AppText.hand(22)),
          ],
        ),
      ),
    );
  }
}
