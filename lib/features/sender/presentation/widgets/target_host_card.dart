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
  final TextEditingController? pinController;

  const TargetHostCard({
    super.key,
    required this.state,
    required this.scanPulseController,
    this.pinController,
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.neumorphicShadowSunken,
              border: Border.all(
                color: state.pairingPin.isNotEmpty
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : AppTheme.shadowDark.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'PIN:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: pinController,
                    initialValue: pinController == null ? state.pairingPin : null,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: AppTheme.primary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 4829',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      context.read<SenderBloc>().add(
                        SenderPinChanged(val.trim()),
                      );
                    },
                  ),
                ),
                if (state.discoveredDevice?.pin != null &&
                    state.discoveredDevice!.pin!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Auto-Paired',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.success,
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
