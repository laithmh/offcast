import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Fullscreen 3-2-1 countdown overlay displayed before prompter rolling begins.
class PrompterCountdownOverlay extends StatelessWidget {
  final int countdown;

  const PrompterCountdownOverlay({super.key, required this.countdown});

  @override
  Widget build(BuildContext context) {
    if (countdown <= 0) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Text(
          '$countdown',
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 130,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: AppTheme.primary, blurRadius: 30)],
          ),
        ),
      ),
    );
  }
}
