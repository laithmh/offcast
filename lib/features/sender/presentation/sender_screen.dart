import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/widgets/neumorphic_widgets.dart';
import '../bloc/sender_bloc.dart';
import '../bloc/sender_event.dart';
import '../bloc/sender_state.dart';
import '../data/sender_webrtc_service.dart';
import 'widgets/talent_prompter_view.dart';

class SenderScreen extends StatelessWidget {
  const SenderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<SenderWebRTCService>(
      create: (_) => SenderWebRTCService(),
      child: Builder(
        builder: (context) {
          final webrtcService = context.read<SenderWebRTCService>();
          return BlocProvider<SenderBloc>(
            create: (_) => SenderBloc(webrtcService: webrtcService),
            child: const _SenderView(),
          );
        },
      ),
    );
  }
}

class _SenderView extends StatefulWidget {
  const _SenderView();

  @override
  State<_SenderView> createState() => _SenderViewState();
}

class _SenderViewState extends State<_SenderView> with WidgetsBindingObserver {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  final _formKey = GlobalKey<FormState>();
  bool _showAdvancedSettings = false;
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ipController = TextEditingController();
    _portController = TextEditingController(text: '8080');
    _checkPermissionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionState();
    }
  }

  Future<void> _checkPermissionState() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _hasNotificationPermission = status.isGranted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _startSharing() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bloc = context.read<SenderBloc>();
    if (bloc.state.streamSource == StreamSourceType.studioCamera) {
      final camGranted =
          await PermissionHelper.requestCameraAndMicPermissions(context);
      if (!camGranted) return;
    } else {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted && mounted) {
        final granted = await PermissionHelper.requestPermissions(context);
        if (!granted) return;
      }
    }

    if (!mounted) return;
    bloc.add(
      SenderStartSharingRequested(
        targetHost: _ipController.text.trim(),
        targetPort: int.tryParse(_portController.text.trim()) ?? 8080,
        preset: bloc.state.preset,
        codecEngine: bloc.state.codecEngine,
        streamSource: bloc.state.streamSource,
        cameraFacing: bloc.state.cameraFacing,
      ),
    );
  }

  void _stopSharing() {
    context.read<SenderBloc>().add(const SenderStopSharingRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SenderBloc, SenderState>(
      listener: (context, state) {
        if (state.isAutoDiscovered || state.discoveredDevice != null) {
          _ipController.text = state.targetHost;
          _portController.text = state.targetPort.toString();
        }

        if (state.status == SenderConnectionState.failed &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        // True Fullscreen OLED Prompter on Phone Display (if explicitly enabled)
        if (state.isStreaming &&
            state.streamSource == StreamSourceType.studioCamera &&
            state.isPrompterOverlay) {
          return TalentPrompterView(
            config: state.prompterConfig,
            onToggleHud: () => context
                .read<SenderBloc>()
                .add(const SenderPrompterOverlayToggled()),
          );
        }

        // Lightweight, zero-interaction power-saving view during active streaming
        if (state.isStreaming) {
          return _buildConnectedSenderView(state);
        }

        // Configuration View before streaming
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Sender Mode'),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Center(
                child: NeumorphicIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 40,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final horizontalPadding = constraints.maxWidth < 380 ? 14.0 : 20.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Form(
                      key: _formKey,
                      child: _buildConfigurationView(state, isWide),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Minimal, power-saving connected screen during active broadcast
  Widget _buildConnectedSenderView(SenderState state) {
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
                  // Studio Status Pill
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

                  // Main Status Card
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
                        const Text(
                          'Connected to Viewer Monitor',
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
                        const SizedBox(height: 18),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),
                        // Glanceable telemetry row
                        StreamBuilder<StreamPerformanceStats>(
                          stream: webrtcService.statsStream,
                          builder: (context, snapshot) {
                            final stats = snapshot.data ?? const StreamPerformanceStats();
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildGlanceablePill(
                                  label: 'FPS',
                                  value: stats.fps > 0 ? stats.fps.toStringAsFixed(0) : '60',
                                  color: AppTheme.primary,
                                ),
                                _buildGlanceablePill(
                                  label: 'Latency',
                                  value: '${stats.latencyMs} ms',
                                  color: stats.latencyMs < 35
                                      ? AppTheme.success
                                      : AppTheme.warning,
                                ),
                                if (isCamera)
                                  _buildGlanceablePill(
                                    label: 'Camera',
                                    value: state.cameraFacing == CameraFacingMode.environment
                                        ? 'Rear'
                                        : 'Front',
                                    color: AppTheme.accent,
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions: Flip Camera & Stop
                  Row(
                    children: [
                      if (isCamera)
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
                            icon: const Icon(Icons.cameraswitch_rounded, size: 20),
                            label: const Text(
                              'Flip Camera',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => webrtcService.switchCamera(),
                          ),
                        ),
                      if (isCamera) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
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
                            'Disconnect',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _stopSharing,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Optional Talent Prompter Glass toggle
                  if (isCamera)
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.subtitles_rounded,
                          size: 16,
                          color: Colors.white54,
                        ),
                        label: const Text(
                          'Show Teleprompter on this display',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        onPressed: () => context
                            .read<SenderBloc>()
                            .add(const SenderPrompterOverlayToggled()),
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Configuration View shown before streaming starts
  Widget _buildConfigurationView(SenderState state, bool isWide) {
    final hasWifi = state.clientIp != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_hasNotificationPermission) ...[
          _buildPermissionBanner(),
          const SizedBox(height: 16),
        ],
        if (!hasWifi) ...[
          _buildNoWifiBanner(),
          const SizedBox(height: 16),
        ],
        _buildDiscoveryCard(state),
        const SizedBox(height: 18),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStreamSourceCard(state, isWide)),
              const SizedBox(width: 16),
              Expanded(child: _buildQualityPresetCard(state, isWide)),
            ],
          )
        else ...[
          _buildStreamSourceCard(state, isWide),
          const SizedBox(height: 18),
          _buildQualityPresetCard(state, isWide),
        ],
        const SizedBox(height: 24),
        _buildActionButtons(state),
        const SizedBox(height: 16),
        _buildManualOverrideSection(state),
      ],
    );
  }

  Widget _buildStreamSourceCard(SenderState state, bool isWide) {
    return NeumorphicCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.video_settings_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Broadcast Stream Source',
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
                  onTap: () => context
                      .read<SenderBloc>()
                      .add(SenderStreamSourceChanged(source)),
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
                        color: isSelected ? AppTheme.primary : Colors.transparent,
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

  Widget _buildNoWifiBanner() {
    return NeumorphicCard(
      borderRadius: 16,
      color: AppTheme.warningLight,
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.warning,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wi-Fi Not Connected',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Please connect to the Receiver’s Wi-Fi Hotspot to stream.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return NeumorphicCard(
      borderRadius: 16,
      color: AppTheme.warningLight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notification permission required for background screen projection.',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          NeumorphicButton(
            onPressed: () => PermissionHelper.requestPermissions(context),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            backgroundColor: AppTheme.warning,
            textColor: Colors.white,
            borderRadius: 12,
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryCard(SenderState state) {
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
                  color: state.clientIp != null ? AppTheme.textSecondary : AppTheme.warning,
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
                  onTap: () => context
                      .read<SenderBloc>()
                      .add(const SenderScanSubnetRequested()),
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
              Icon(
                state.isVerified
                    ? Icons.check_circle_rounded
                    : (state.isScanning ? Icons.sync_rounded : Icons.router_rounded),
                color: state.isVerified ? AppTheme.success : AppTheme.primary,
                size: 20,
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
        ],
      ),
    );
  }

  Widget _buildQualityPresetCard(SenderState state, bool isWide) {
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
                onTap: () => context
                    .read<SenderBloc>()
                    .add(SenderQualityPresetChanged(preset)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
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
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
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
              Icon(
                Icons.memory_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
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
                  onTap: () => context
                      .read<SenderBloc>()
                      .add(SenderCodecEngineChanged(engine)),
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

  Widget _buildActionButtons(SenderState state) {
    final hasWifi = state.clientIp != null;
    final isCamera = state.streamSource == StreamSourceType.studioCamera;

    return NeumorphicButton(
      onPressed: hasWifi ? _startSharing : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect to the Receiver’s Wi-Fi Hotspot first.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      },
      isPrimary: true,
      backgroundColor: hasWifi ? AppTheme.primary : AppTheme.surfaceElevated,
      textColor: hasWifi ? Colors.white : AppTheme.textMuted,
      borderRadius: 18,
      icon: !hasWifi
          ? Icons.wifi_off_rounded
          : (isCamera ? Icons.videocam_rounded : Icons.play_arrow_rounded),
      child: Text(
        !hasWifi
            ? 'Connect to Hotspot to Stream'
            : (isCamera
                ? 'Start Studio Camera & Prompter'
                : 'Start Screen Mirroring'),
      ),
    );
  }

  Widget _buildManualOverrideSection(SenderState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TextButton.icon(
            onPressed: () => setState(
              () => _showAdvancedSettings = !_showAdvancedSettings,
            ),
            icon: Icon(
              _showAdvancedSettings
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary,
              size: 18,
            ),
            label: Text(
              _showAdvancedSettings
                  ? 'Hide Manual IP Settings'
                  : 'Manual Target IP Override',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_showAdvancedSettings) ...[
          const SizedBox(height: 10),
          NeumorphicCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual IP Configuration',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Receiver IP Address',
                    hintText: '192.168.43.1',
                    prefixIcon: Icon(Icons.lan_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'IP address required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Signaling Port',
                    hintText: '8080',
                    prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
