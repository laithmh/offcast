import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/webrtc_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';
import '../../bloc/sender_state.dart';

/// Card for configuring streaming quality presets and video codec engines.
class QualityPresetCard extends StatelessWidget {
  final SenderState state;
  final bool isWide;

  const QualityPresetCard({
    super.key,
    required this.state,
    required this.isWide,
  });

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
              Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Quality & Performance Preset',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: StreamingQualityPreset.values.map((preset) {
              final isSelected = state.preset == preset;
              return GestureDetector(
                onTap: () => context.read<SenderBloc>().add(
                  SenderQualityPresetChanged(preset),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          preset == StreamingQualityPreset.hd720p30
                              ? Icons.hd_rounded
                              : Icons.bolt_rounded,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    preset.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppTheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${preset.targetFps} FPS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preset.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 28, color: AppTheme.surfaceElevated),
          const Row(
            children: [
              Icon(Icons.memory_rounded, color: AppTheme.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Video Codec Engine',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: CodecEngine.values.map((engine) {
              final isSelected = state.codecEngine == engine;
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.read<SenderBloc>().add(
                    SenderCodecEngineChanged(engine),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: engine == CodecEngine.vp8 ? 6 : 0,
                      left: engine == CodecEngine.h264 ? 6 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
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
                          engine == CodecEngine.vp8
                              ? Icons.verified_user_rounded
                              : Icons.bolt_rounded,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 18,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          engine.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          engine == CodecEngine.vp8
                              ? 'Zero-Glitch Universal'
                              : 'Snapdragon Silicon',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
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
