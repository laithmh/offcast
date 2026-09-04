import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/webrtc_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';
import '../../bloc/sender_state.dart';
import '../../data/sender_webrtc_service.dart';

/// Minimal, power-saving connected screen during active broadcast.
/// Uses a true OLED black background to minimize battery drain and thermal output.
class ConnectedSenderView extends StatelessWidget {
  final SenderState state;
  final VoidCallback onDisconnect;

  const ConnectedSenderView({
    super.key,
    required this.state,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final webrtcService = context.read<SenderWebRTCService>();
    final isCamera = state.streamSource == StreamSourceType.studioCamera;

    return Scaffold(
      backgroundColor: const Color(0xFF07090E), // Deep OLED black
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active Status Pill
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isCamera
                                ? 'CAMERA TRANSMITTER ACTIVE'
                                : 'SCREEN MIRRORING ACTIVE',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Main Status & Telemetry Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isCamera
                              ? Icons.videocam_rounded
                              : Icons.screen_share_rounded,
                          color: AppTheme.primary,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isCamera
                              ? 'Direct Studio Camera Feed'
                              : 'Connected to Viewer Monitor',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Target: ${state.targetHost}:${state.targetPort}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Active Stream Specs Badges
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildSpecBadge(
                              icon: Icons.high_quality_rounded,
                              text: state.preset.label.split('(').first.trim(),
                            ),
                            _buildSpecBadge(
                              icon: Icons.memory_rounded,
                              text: state.codecEngine == CodecEngine.h264
                                  ? 'H.264 Turbo'
                                  : 'VP8 Safe',
                            ),
                            if (isCamera)
                              _buildSpecBadge(
                                icon:
                                    state.cameraFacing ==
                                        CameraFacingMode.environment
                                    ? Icons.camera_rear_rounded
                                    : Icons.camera_front_rounded,
                                text:
                                    state.cameraFacing ==
                                        CameraFacingMode.environment
                                    ? 'Rear Sensor'
                                    : 'Front Sensor',
                                color: AppTheme.accent,
                              ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),

                        // Glanceable telemetry stream
                        StreamBuilder<StreamPerformanceStats>(
                          stream: webrtcService.statsStream,
                          builder: (context, snapshot) {
                            final stats =
                                snapshot.data ?? const StreamPerformanceStats();
                            final phoneTemp = stats.senderTemperatureC;
                            final tempColor = phoneTemp != null
                                ? (phoneTemp >= 44.0
                                      ? AppTheme.error
                                      : (phoneTemp >= 40.0
                                            ? AppTheme.warning
                                            : AppTheme.success))
                                : AppTheme.textMuted;

                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildGlanceablePill(
                                      label: 'FPS',
                                      value: stats.fps > 0
                                          ? stats.fps.toStringAsFixed(0)
                                          : '60',
                                      color: AppTheme.primary,
                                    ),
                                    _buildGlanceablePill(
                                      label: 'Bitrate',
                                      value: stats.bitrateMbps > 0
                                          ? '${stats.bitrateMbps.toStringAsFixed(1)}M'
                                          : '3.5M',
                                      color: AppTheme.accent,
                                    ),
                                    _buildGlanceablePill(
                                      label: 'Latency',
                                      value: '${stats.latencyMs} ms',
                                      color: stats.latencyMs < 35
                                          ? AppTheme.success
                                          : AppTheme.warning,
                                    ),
                                    if (phoneTemp != null)
                                      _buildGlanceablePill(
                                        label: 'Temp',
                                        value:
                                            '${phoneTemp.toStringAsFixed(0)}°C',
                                        color: tempColor,
                                      ),
                                    if (isCamera)
                                      _buildGlanceablePill(
                                        label: 'Camera',
                                        value:
                                            state.cameraFacing ==
                                                CameraFacingMode.environment
                                            ? 'Rear'
                                            : 'Front',
                                        color: AppTheme.accent,
                                      ),
                                  ],
                                ),
                                if (phoneTemp != null && phoneTemp >= 44.0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.error.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department_rounded,
                                          color: AppTheme.error,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Device temperature is high. Consider 720p preset.',
                                          style: TextStyle(
                                            color: AppTheme.error,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions: Flip Camera & Disconnect
                  Row(
                    children: [
                      if (isCamera) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.white12),
                              ),
                            ),
                            icon: Icon(
                              state.cameraFacing == CameraFacingMode.environment
                                  ? Icons.camera_front_rounded
                                  : Icons.camera_rear_rounded,
                              size: 20,
                              color: AppTheme.accent,
                            ),
                            label: Text(
                              state.cameraFacing == CameraFacingMode.environment
                                  ? 'Switch to Front'
                                  : 'Switch to Rear',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => context.read<SenderBloc>().add(
                              const SenderCameraFacingToggled(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.stop_rounded, size: 20),
                          label: const Text(
                            'Disconnect',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: onDisconnect,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Optional Talent Prompter Glass toggle
                  if (isCamera)
                    Center(
                      child: TextButton.icon(
                        icon: Icon(
                          state.isPrompterOverlay
                              ? Icons.visibility_off_rounded
                              : Icons.subtitles_rounded,
                          size: 18,
                          color: state.isPrompterOverlay
                              ? AppTheme.accent
                              : Colors.white60,
                        ),
                        label: Text(
                          state.isPrompterOverlay
                              ? 'Hide Teleprompter overlay'
                              : 'Show Teleprompter on this display',
                          style: TextStyle(
                            color: state.isPrompterOverlay
                                ? AppTheme.accent
                                : Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => context.read<SenderBloc>().add(
                          const SenderPrompterOverlayToggled(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecBadge({
    required IconData icon,
    required String text,
    Color color = Colors.white70,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlanceablePill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
