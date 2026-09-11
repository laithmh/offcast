import 'package:flutter/material.dart';

import '../../../../core/models/prompter_model.dart';
import '../../../../core/theme/app_theme.dart';

/// Top floating control toolbar for the Director Prompter Overlay.
/// Contains play/pause, reading progress, VAD mic indicator, camera switch, and opacity toggle.
class PrompterHudToolbar extends StatelessWidget {
  final PrompterConfig config;
  final bool isPlaying;
  final bool isSpeaking;
  final double audioLevel;
  final bool isTransparentBackground;
  final bool isCustomPositioned;
  final bool isCompact;
  final VoidCallback onRewind;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleBackground;
  final VoidCallback? onResetPosition;
  final VoidCallback onOpenEditor;
  final VoidCallback onCloseOverlay;

  const PrompterHudToolbar({
    super.key,
    required this.config,
    required this.isPlaying,
    required this.isSpeaking,
    required this.audioLevel,
    required this.isTransparentBackground,
    required this.isCustomPositioned,
    required this.isCompact,
    required this.onRewind,
    required this.onTogglePlay,
    required this.onToggleBackground,
    this.onResetPosition,
    required this.onOpenEditor,
    required this.onCloseOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isTransparentBackground
            ? Colors.black.withValues(alpha: 0.5)
            : const Color(0xFF1E2430),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Drag Grip Handle
          Icon(
            Icons.drag_indicator_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),

          // Status Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? AppTheme.success : AppTheme.warning,
              boxShadow: [
                BoxShadow(
                  color: (isPlaying ? AppTheme.success : AppTheme.warning)
                      .withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isCompact ? 'PROMPTER' : 'PROMPTER MONITOR',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white70,
            ),
          ),

          // Live VAD Microphone Pill
          if (config.isVoiceActivated) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSpeaking
                    ? AppTheme.success.withValues(alpha: 0.25)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSpeaking ? AppTheme.success : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 12,
                    color: isSpeaking ? AppTheme.success : Colors.white54,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isSpeaking ? 'SPEAKING' : 'VAD ON',
                    style: TextStyle(
                      color: isSpeaking ? AppTheme.success : Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: audioLevel.clamp(0.1, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSpeaking ? AppTheme.success : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Reading Progress % Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${(config.scrollProgress * 100).round()}%',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // WPM Speed Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${config.scrollSpeedWpm.toInt()} WPM',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Rewind / Reset Script to Top Button
          IconButton(
            icon: const Icon(
              Icons.replay_rounded,
              color: Colors.white70,
              size: 19,
            ),
            tooltip: 'Reset Script to Top',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: onRewind,
          ),

          // Play / Pause Button
          IconButton(
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: isPlaying ? AppTheme.warning : AppTheme.success,
              size: 24,
            ),
            tooltip: isPlaying ? 'Pause Prompter' : 'Play Prompter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: onTogglePlay,
          ),

          // Transparent Background Toggle Button
          IconButton(
            icon: Icon(
              isTransparentBackground
                  ? Icons.layers_rounded
                  : Icons.opacity_rounded,
              color: isTransparentBackground ? AppTheme.accent : Colors.white70,
              size: 19,
            ),
            tooltip: isTransparentBackground
                ? 'Restore Solid Background'
                : 'Remove Background (Transparent Floating Text)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: onToggleBackground,
          ),

          // Reset Position Button
          if (isCustomPositioned)
            IconButton(
              icon: const Icon(
                Icons.restart_alt_rounded,
                color: AppTheme.warning,
                size: 20,
              ),
              tooltip: 'Reset Overlay Position to Bottom Center',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: onResetPosition,
            ),

          // Edit Script Button
          IconButton(
            icon: const Icon(
              Icons.edit_note_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
            tooltip: 'Edit Script & Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: onOpenEditor,
          ),

          // Close / Hide Overlay Button
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 18,
            ),
            tooltip: 'Hide Prompter Monitor',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: onCloseOverlay,
          ),
        ],
      ),
    );
  }
}
