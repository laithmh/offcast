import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/constants/webrtc_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/receiver_bloc.dart';
import '../../bloc/receiver_event.dart';
import '../../bloc/receiver_state.dart';
import 'director_prompter_sheet.dart';

/// Floating vertical toolbar overlay providing in-stream controls for the director.
class ReceiverInStreamToolbar extends StatelessWidget {
  final ReceiverState state;
  final RTCVideoViewObjectFit objectFit;
  final bool isMirrored;
  final VoidCallback onToggleFit;
  final VoidCallback onCycleTurns;
  final VoidCallback onToggleMirror;

  const ReceiverInStreamToolbar({
    super.key,
    required this.state,
    required this.objectFit,
    required this.isMirrored,
    required this.onToggleFit,
    required this.onCycleTurns,
    required this.onToggleMirror,
  });

  void _openDirectorPrompterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<ReceiverBloc>(),
        child: const DirectorPrompterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCover =
        objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - 140,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.neumorphicShadowElevated,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIconButton(
              size: 40,
              tooltip: isCover ? 'Fit to Screen' : 'Fill Screen',
              icon: isCover
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              iconColor: isCover ? AppTheme.primary : AppTheme.textPrimary,
              onPressed: onToggleFit,
            ),
            const SizedBox(height: 8),
            NeumorphicIconButton(
              size: 40,
              tooltip: 'Rotate 90°',
              icon: Icons.rotate_right_rounded,
              onPressed: onCycleTurns,
            ),
            const SizedBox(height: 8),
            NeumorphicIconButton(
              size: 40,
              tooltip: 'Mirror Video',
              icon: Icons.flip_rounded,
              iconColor: isMirrored ? AppTheme.accent : AppTheme.textPrimary,
              onPressed: onToggleMirror,
            ),
            const SizedBox(height: 8),
            NeumorphicIconButton(
              size: 40,
              tooltip: 'Cycle Social Framing Guides',
              icon: Icons.aspect_ratio_rounded,
              iconColor: state.framingMode != SocialFramingMode.none
                  ? AppTheme.primary
                  : AppTheme.textPrimary,
              onPressed: () => context.read<ReceiverBloc>().add(
                const ReceiverFramingModeCycled(),
              ),
            ),
            if (state.streamSource == StreamSourceType.studioCamera) ...[
              const SizedBox(height: 8),
              NeumorphicIconButton(
                size: 40,
                tooltip: 'Switch Remote Camera',
                icon: Icons.cameraswitch_rounded,
                iconColor: AppTheme.accent,
                onPressed: () => context.read<ReceiverBloc>().add(
                  const ReceiverPrompterCommandDispatched('switch_camera'),
                ),
              ),
              const SizedBox(height: 8),
              NeumorphicIconButton(
                size: 40,
                tooltip: state.isPrompterOverlayVisible
                    ? 'Hide Prompter Monitor'
                    : 'Show Prompter Monitor',
                icon: state.isPrompterOverlayVisible
                    ? Icons.subtitles_rounded
                    : Icons.subtitles_off_rounded,
                iconColor: state.isPrompterOverlayVisible
                    ? AppTheme.accent
                    : AppTheme.textPrimary,
                onPressed: () => context.read<ReceiverBloc>().add(
                  const ReceiverPrompterOverlayToggled(),
                ),
              ),
              const SizedBox(height: 8),
              NeumorphicIconButton(
                size: 40,
                tooltip: 'Director Script Remote',
                icon: Icons.edit_note_rounded,
                iconColor: AppTheme.primary,
                onPressed: () => _openDirectorPrompterSheet(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
