import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/widgets/neumorphic_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Prompt for required permissions on initial launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionHelper.hasRequiredPermissions().then((granted) {
        if (!granted && mounted) {
          PermissionHelper.requestPermissions(context);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isTabletOrDesktop = screenWidth >= 640;
            final isCompact = screenWidth < 380;

            final horizontalPadding = isCompact
                ? 14.0
                : (isTabletOrDesktop ? 32.0 : 20.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(screenWidth, isCompact),
                      const SizedBox(height: 28),
                      if (isTabletOrDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildRoleCard(
                                context: context,
                                title: 'Receiver Mode',
                                subtitle: 'Director Viewfinder & Prompter Master',
                                description:
                                    'Acts as the master monitor. View camera feed, manage teleprompter, framing guides, and stream settings.',
                                icon: Icons.monitor_rounded,
                                accentColor: AppTheme.primary,
                                buttonLabel: 'Start Receiver',
                                isPrimary: true,
                                onTap: () => context.push('/receiver'),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildRoleCard(
                                context: context,
                                title: 'Sender Mode',
                                subtitle: 'Camera & Screen Transmitter',
                                description:
                                    'Silent, battery-efficient hardware video node. Streams 1080p 60fps camera feed to the Director monitor.',
                                icon: Icons.videocam_rounded,
                                accentColor: AppTheme.accent,
                                buttonLabel: 'Start Sender',
                                isPrimary: false,
                                onTap: () => context.push('/sender'),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildRoleCard(
                          context: context,
                          title: 'Receiver Mode',
                          subtitle: 'Director Viewfinder & Prompter Master',
                          description:
                              'Acts as the master monitor. View camera feed, manage teleprompter, framing guides, and stream settings.',
                          icon: Icons.monitor_rounded,
                          accentColor: AppTheme.primary,
                          buttonLabel: 'Start Receiver',
                          isPrimary: true,
                          onTap: () => context.push('/receiver'),
                        ),
                        const SizedBox(height: 18),
                        _buildRoleCard(
                          context: context,
                          title: 'Sender Mode',
                          subtitle: 'Camera & Screen Transmitter',
                          description:
                              'Silent, battery-efficient hardware video node. Streams 1080p 60fps camera feed to the Director monitor.',
                          icon: Icons.videocam_rounded,
                          accentColor: AppTheme.accent,
                          buttonLabel: 'Start Sender',
                          isPrimary: false,
                          onTap: () => context.push('/sender'),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _buildHowItWorksCard(isCompact),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isCompact ? 10 : 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.neumorphicShadowElevated,
              ),
              child: Icon(
                Icons.wifi_tethering_rounded,
                color: AppTheme.primary,
                size: isCompact ? 24 : 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hotspot Screen Cast',
                    style: TextStyle(
                      fontSize: isCompact ? 19 : 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Direct Offline P2P • Any Device • <25ms Latency',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Connect two devices over Wi-Fi Hotspot for ultra-low latency, real-time wireless screen sharing without internet.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String buttonLabel,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return NeumorphicCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: NeumorphicButton(
              onPressed: onTap,
              isPrimary: isPrimary,
              backgroundColor: isPrimary ? accentColor : AppTheme.surfaceElevated,
              textColor: isPrimary ? Colors.white : AppTheme.textPrimary,
              icon: Icons.arrow_forward_rounded,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard(bool isCompact) {
    return NeumorphicCard(
      borderRadius: 22,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppTheme.warning, size: 22),
              SizedBox(width: 10),
              Text(
                'Universal 3-Step Setup',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            number: '1',
            title: 'Enable Wi-Fi Hotspot on Either Device',
            subtitle: 'Turn on Portable Hotspot on either device, and connect the other device to its Wi-Fi network.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            number: '2',
            title: 'Start Receiver on Display Device',
            subtitle: 'Tap Start Receiver on the device acting as your monitor/viewfinder.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            number: '3',
            title: 'Start Sender on Source Device',
            subtitle: 'Tap Start Sender on the device sharing its screen to automatically pair and stream.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
