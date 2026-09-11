import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/webrtc_constants.dart';
import '../../../../core/theme/app_theme.dart';
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
                          const Text(
                            'SCREEN MIRRORING ACTIVE',
                            style: TextStyle(
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
                        const Icon(
                          Icons.screen_share_rounded,
                          color: AppTheme.primary,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Broadcasting Viewfinder',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                                          : '30',
                                      color: AppTheme.primary,
                                    ),
                                    _buildGlanceablePill(
                                      label: 'Bitrate',
                                      value: stats.bitrateMbps > 0
                                          ? '${stats.bitrateMbps.toStringAsFixed(1)}M'
                                          : '${(state.preset.bitrateKbps / 1000).toStringAsFixed(1)}M',
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
                                          'Device temperature is high. Consider Cool 540p preset.',
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

                  // Actions: Stop Broadcast
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text(
                      'Stop Broadcast',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: onDisconnect,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_rounded,
                          color: AppTheme.accent,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tip: Dim screen to keep phone cool. Set hotspot to 5 GHz band for 2–5ms ultra-low latency.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      ],
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
