import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/receiver_bloc.dart';
import '../../bloc/receiver_event.dart';
import '../../bloc/receiver_state.dart';

/// Standby / Waiting placeholder screen for the Receiver display when no stream is active.
/// Features a calm breathing radar pulse animation indicating the server is listening.
class ReceiverWaitingView extends StatelessWidget {
  final ReceiverState state;
  final Animation<double> pulseAnimation;

  const ReceiverWaitingView({
    super.key,
    required this.state,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final hasNetwork = state.localIp != null;
    final wsUrl = 'ws://${state.localIp ?? "192.168.43.1"}:${state.port}';

    return Container(
      color: AppTheme.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!hasNetwork) ...[
                  NeumorphicCard(
                    borderRadius: 20,
                    color: AppTheme.warningLight,
                    padding: const EdgeInsets.all(20),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: AppTheme.warning,
                          size: 28,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wi-Fi / Hotspot Offline',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Turn on Portable Hotspot or connect to Wi-Fi to start broadcasting.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Breathing Pulsing Icon Container
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (context, child) {
                    final scale = 1.0 + (pulseAnimation.value * 0.08);
                    final blur = 10.0 + (pulseAnimation.value * 12.0);
                    final spread = 1.0 + (pulseAnimation.value * 4.0);

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.shadowLight,
                              offset: const Offset(-6, -6),
                              blurRadius: blur,
                              spreadRadius: spread,
                            ),
                            BoxShadow(
                              color:
                                  (hasNetwork
                                          ? AppTheme.primary
                                          : AppTheme.warning)
                                      .withValues(
                                        alpha:
                                            0.25 + (pulseAnimation.value * 0.2),
                                      ),
                              offset: const Offset(6, 6),
                              blurRadius: blur,
                              spreadRadius: spread,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    hasNetwork
                        ? Icons.wifi_tethering_rounded
                        : Icons.wifi_off_rounded,
                    color: hasNetwork ? AppTheme.primary : AppTheme.warning,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  !hasNetwork
                      ? 'Waiting for Wi-Fi / Hotspot...'
                      : (state.isClientConnected
                            ? 'Sender Connected. Negotiating...'
                            : 'Waiting for Incoming Stream...'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  !hasNetwork
                      ? 'Turn on Portable Hotspot in device settings. The screen will automatically start listening the moment it is turned on.'
                      : 'Keep this monitor open. On your camera phone, tap Start Viewfinder to connect.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                if (hasNetwork) ...[
                  if (state.pairingPin.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    NeumorphicCard(
                      borderRadius: 22,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppTheme.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Pairing Security PIN',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                tooltip: 'Regenerate PIN',
                                onPressed: () {
                                  context.read<ReceiverBloc>().add(
                                    const ReceiverRegeneratePinRequested(),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                tooltip: 'Copy PIN',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: state.pairingPin),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('PIN copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: state.pairingPin.split('').map((digit) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                width: 44,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: AppTheme.neumorphicShadowSunken,
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    digit,
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Enter this 4-digit PIN on the sender phone to authorize connection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  NeumorphicCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lan_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        SelectableText(
                          wsUrl,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          tooltip: 'Copy WebSocket URL',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: wsUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeumorphicCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.wifi_tethering_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Base Station Mode Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Connect your camera phone to this device’s Hotspot, then launch Sender Mode.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '⚡ Pro Tip: Set Hotspot band to 5 GHz in Android Settings for 2–5ms ultra-low latency & zero stutter.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
