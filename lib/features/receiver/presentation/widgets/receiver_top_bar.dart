import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/webrtc_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/exit_confirmation_dialog.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/receiver_bloc.dart';
import '../../bloc/receiver_event.dart';
import '../../bloc/receiver_state.dart';
import '../../data/receiver_webrtc_service.dart';

/// Top bar header for the Receiver Viewfinder.
/// Displays back button, active IP / telemetry badge, and server reset button.
class ReceiverTopBar extends StatelessWidget {
  final ReceiverState state;

  const ReceiverTopBar({super.key, required this.state});

  Future<void> _handleBack(BuildContext context) async {
    if (state.isStreaming) {
      final shouldPop = await ExitConfirmationDialog.show(
        context,
        title: 'Disconnect Stream?',
        message: 'An active broadcast session is currently playing. Leaving will terminate the live display view.',
        cancelLabel: 'Keep Viewing',
        confirmLabel: 'Exit & Disconnect',
      );
      if (shouldPop == true && context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: state.isStreaming
            ? AppTheme.surface.withValues(alpha: 0.92)
            : AppTheme.background,
        boxShadow: state.isStreaming ? AppTheme.neumorphicShadowElevated : null,
      ),
      child: Row(
        children: [
          NeumorphicIconButton(
            size: 40,
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () => _handleBack(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Display Viewfinder',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                if (state.isStreaming)
                  const ReceiverTelemetryDisplay()
                else
                  Text(
                    state.localIp != null
                        ? 'ws://${state.localIp}:${state.port}'
                        : 'No Hotspot / Wi-Fi Active',
                    style: TextStyle(
                      color: state.localIp != null
                          ? AppTheme.textSecondary
                          : AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          NeumorphicButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            backgroundColor: state.isStreaming
                ? AppTheme.error
                : AppTheme.primary,
            textColor: Colors.white,
            borderRadius: 12,
            onPressed: () => context.read<ReceiverBloc>().add(
              const ReceiverStartServerRequested(),
            ),
            child: Text(state.isStreaming ? 'Reset' : 'Restart'),
          ),
        ],
      ),
    );
  }
}

/// Dual-device thermal telemetry display in the receiver top bar.
class ReceiverTelemetryDisplay extends StatelessWidget {
  const ReceiverTelemetryDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final webrtcService = context.read<ReceiverWebRTCService>();

    return StreamBuilder<StreamPerformanceStats>(
      stream: webrtcService.statsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text(
            'Live Stream Active',
            style: TextStyle(
              color: AppTheme.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        final stats = snapshot.data!;
        final phoneTemp = stats.senderTemperatureC;
        final tabletTemp = stats.receiverTemperatureC;

        final phoneColor = phoneTemp != null
            ? (phoneTemp >= 44.0
                  ? AppTheme.error
                  : (phoneTemp >= 40.0 ? AppTheme.warning : AppTheme.success))
            : AppTheme.textMuted;

        final tabletColor = tabletTemp != null
            ? (tabletTemp >= 44.0
                  ? AppTheme.error
                  : (tabletTemp >= 40.0 ? AppTheme.warning : AppTheme.success))
            : AppTheme.textMuted;

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.fps} FPS • ${stats.bitrateMbps} Mbps • ${stats.latencyMs}ms',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (phoneTemp != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: phoneColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: phoneColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      phoneTemp >= 42.0
                          ? Icons.local_fire_department_rounded
                          : Icons.thermostat_rounded,
                      size: 11,
                      color: phoneColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${stats.senderDeviceName ?? 'Sender'} ${phoneTemp.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        color: phoneColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            if (tabletTemp != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tabletColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: tabletColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabletTemp >= 42.0
                          ? Icons.local_fire_department_rounded
                          : Icons.thermostat_rounded,
                      size: 11,
                      color: tabletColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${stats.receiverDeviceName ?? 'Receiver'} ${tabletTemp.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        color: tabletColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
