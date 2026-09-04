import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/webrtc_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';
import '../../bloc/sender_state.dart';

/// Card for choosing stream input source: Studio Camera vs. Phone Screen Mirroring.
class StreamSourceCard extends StatelessWidget {
  final SenderState state;

  const StreamSourceCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return NeumorphicCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Stream Source',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: StreamSourceType.values.map((source) {
              final isSelected = state.streamSource == source;
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.read<SenderBloc>().add(
                    SenderStreamSourceChanged(source),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: source == StreamSourceType.screen ? 6 : 0,
                      left: source == StreamSourceType.studioCamera ? 6 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          source == StreamSourceType.studioCamera
                              ? Icons.videocam_rounded
                              : Icons.screen_share_rounded,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          source.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          source == StreamSourceType.studioCamera
                              ? '1080p 60 FPS + Prompter'
                              : 'Mirror Phone Screen',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
