import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';
import '../../bloc/sender_state.dart';

/// Card displaying local Wi-Fi IP, subnet scan status, and verified target receiver.
class TargetHostCard extends StatelessWidget {
  final SenderState state;
  final AnimationController scanPulseController;

  const TargetHostCard({
    super.key,
    required this.state,
    required this.scanPulseController,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'My IP: ${state.clientIp ?? "No Wi-Fi"}',
                style: TextStyle(
                  color: state.clientIp != null
                      ? AppTheme.textSecondary
                      : AppTheme.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (state.isScanning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => context.read<SenderBloc>().add(
                    const SenderScanSubnetRequested(),
                  ),
                  child: const Text(
                    'Rescan',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.shadowDark),
          Row(
            children: [
              AnimatedBuilder(
                animation: scanPulseController,
                builder: (context, child) {
                  final scale = state.isScanning
                      ? 1.0 + (scanPulseController.value * 0.2)
                      : 1.0;
                  final opacity = state.isScanning
                      ? 0.7 + (scanPulseController.value * 0.3)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Icon(
                  state.isVerified
                      ? Icons.check_circle_rounded
                      : (state.isScanning
                            ? Icons.radar_rounded
                            : Icons.router_rounded),
                  color: state.isVerified ? AppTheme.success : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.isVerified
                      ? 'Target Receiver Verified (${state.targetHost})'
                      : (state.isScanning
                            ? 'Scanning local Hotspot subnet...'
                            : 'Target Receiver: ${state.targetHost}'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (state.clientIp != null
                      ? AppTheme.primary
                      : AppTheme.warning)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (state.clientIp != null
                        ? AppTheme.primary
                        : AppTheme.warning)
                    .withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.clientIp != null
                      ? Icons.info_outline_rounded
                      : Icons.wifi_off_rounded,
                  size: 15,
                  color: state.clientIp != null
                      ? AppTheme.primary
                      : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.clientIp != null
                        ? 'Ensure Receiver is hosting the Hotspot (192.168.43.1) for zero-config pairing.'
                        : 'Please connect this phone to the Receiver device\'s Wi-Fi Hotspot.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: state.clientIp != null
                          ? AppTheme.textSecondary
                          : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
