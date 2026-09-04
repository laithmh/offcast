import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/prompter_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';

/// Floating bottom control panel for live teleprompter adjustments.
/// Controls speed (WPM), font size, voice activation, optical mirror mode, and playback.
class PrompterHudBar extends StatelessWidget {
  final PrompterConfig config;
  final VoidCallback onRewind;

  const PrompterHudBar({
    super.key,
    required this.config,
    required this.onRewind,
  });

  void _showEditScriptDialog(BuildContext context) {
    final textController = TextEditingController(text: config.scriptText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Edit Talent Script',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: textController,
            maxLines: 12,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter speech or presentation script here...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SenderBloc>().add(
                SenderPrompterScriptUpdated(textController.text.trim()),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply Script'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed and Font Size Row
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${config.scrollSpeedWpm.round()} WPM',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Slider(
                  value: config.scrollSpeedWpm,
                  min: 60.0,
                  max: 300.0,
                  divisions: 24,
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    context.read<SenderBloc>().add(
                      SenderPrompterSpeedChanged(val),
                    );
                  },
                ),
              ),

              // Font Size Controls
              IconButton(
                icon: const Icon(Icons.text_decrease_rounded, size: 20),
                color: Colors.white70,
                onPressed: () {
                  final newSize = (config.fontSize - 4).clamp(18.0, 56.0);
                  context.read<SenderBloc>().add(
                    SenderPrompterFontSizeChanged(newSize),
                  );
                },
              ),
              Text(
                '${config.fontSize.round()}pt',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase_rounded, size: 20),
                color: Colors.white70,
                onPressed: () {
                  final newSize = (config.fontSize + 4).clamp(18.0, 56.0);
                  context.read<SenderBloc>().add(
                    SenderPrompterFontSizeChanged(newSize),
                  );
                },
              ),
            ],
          ),

          const Divider(height: 8, color: Colors.white12),

          // Primary Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind to top
              IconButton(
                icon: const Icon(Icons.replay_rounded, size: 24),
                color: Colors.white,
                tooltip: 'Rewind to Top',
                onPressed: onRewind,
              ),

              // Horizontal mirror toggle
              IconButton(
                icon: Icon(
                  config.isMirrored
                      ? Icons.flip_rounded
                      : Icons.flip_camera_android_rounded,
                  size: 22,
                ),
                color: config.isMirrored ? AppTheme.accent : Colors.white70,
                tooltip: 'Flip for Glass Beam-Splitter',
                onPressed: () {
                  context.read<SenderBloc>().add(
                    const SenderPrompterMirrorToggled(),
                  );
                },
              ),

              // Big Play/Pause Button
              GestureDetector(
                onTap: () {
                  context.read<SenderBloc>().add(
                    const SenderPrompterPlayPauseToggled(),
                  );
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: config.isPlaying
                        ? AppTheme.warning
                        : AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (config.isPlaying
                                    ? AppTheme.warning
                                    : AppTheme.primary)
                                .withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    config.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              // Voice-Activated Auto-Scroll Toggle
              IconButton(
                icon: Icon(
                  config.isVoiceActivated
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  size: 24,
                ),
                color: config.isVoiceActivated
                    ? AppTheme.success
                    : Colors.white70,
                tooltip: 'Voice-Activated Auto-Scroll',
                onPressed: () {
                  context.read<SenderBloc>().add(
                    const SenderPrompterVoiceActivationToggled(),
                  );
                },
              ),

              // Quick Script Edit Dialog
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 26),
                color: Colors.white70,
                tooltip: 'Edit Script',
                onPressed: () => _showEditScriptDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
