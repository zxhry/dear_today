import 'package:flutter/material.dart';
import '../theme.dart';

/// "Write to today" title with three little progress dots.
class StepHeader extends StatelessWidget {
  final int step; // 1, 2 or 3
  final String title;
  final IconData? leadingIcon;
  final String leadingTooltip;
  final VoidCallback? onLeading;

  const StepHeader({
    super.key,
    required this.step,
    this.title = 'Write to today',
    this.leadingIcon,
    this.leadingTooltip = 'Back',
    this.onLeading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: leadingIcon == null
                ? null
                : IconButton(
                    tooltip: leadingTooltip,
                    onPressed: onLeading,
                    icon: Icon(leadingIcon, color: AppColors.ink),
                  ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(title, style: AppText.hand(24)),
                const SizedBox(height: 6),
                Semantics(
                  label: 'Step $step of 3',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 3; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == step ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == step ? AppColors.accent : const Color(0xFFB8C1D6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
