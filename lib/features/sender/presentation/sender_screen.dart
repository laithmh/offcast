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

    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted && mounted) {
      final granted = await PermissionHelper.requestPermissions(context);
      if (!granted) return;
    }

    if (!mounted) return;
    final bloc = context.read<SenderBloc>();
    bloc.add(
      SenderStartSharingRequested(
        targetHost: _ipController.text.trim(),
        targetPort: int.tryParse(_portController.text.trim()) ?? 8080,
        preset: bloc.state.preset,
        codecEngine: bloc.state.codecEngine,
      ),
    );
  }

  void _stopSharing() {
    context.read<SenderBloc>().add(const SenderStopSharingRequested());
  }

  @override
  Widget build(BuildContext context) {
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
      body: BlocConsumer<SenderBloc, SenderState>(
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
          return LayoutBuilder(
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
                      child: state.isStreaming
                          ? _buildLiveBroadcastHud(state)
                          : _buildConfigurationView(state, isWide),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Live Broadcast Dashboard shown during active streaming
  Widget _buildLiveBroadcastHud(SenderState state) {
    final webrtcService = context.read<SenderWebRTCService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        NeumorphicCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE SCREEN CAST',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Streaming to ${state.targetHost}:${state.targetPort}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              StreamBuilder<StreamPerformanceStats>(
                stream: webrtcService.statsStream,
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? const StreamPerformanceStats();
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryTile(
                          icon: Icons.speed_rounded,
                          title: 'Framerate',
                          value: '${stats.fps.toStringAsFixed(0)} FPS',
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryTile(
                          icon: Icons.timer_outlined,
                          title: 'Latency',
                          value: '${stats.latencyMs} ms',
                          color: stats.latencyMs < 30 ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryTile(
                          icon: Icons.data_usage_rounded,
                          title: 'Bitrate',
                          value: '${stats.bitrateMbps.toStringAsFixed(1)} Mbps',
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: NeumorphicButton(
                  onPressed: _stopSharing,
                  backgroundColor: AppTheme.error,
                  textColor: Colors.white,
                  borderRadius: 18,
                  icon: Icons.stop_rounded,
                  child: const Text('Stop Screen Sharing'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
        _buildQualityPresetCard(state, isWide),
        const SizedBox(height: 24),
        _buildActionButtons(state),
        const SizedBox(height: 16),
        _buildManualOverrideSection(state),
      ],
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
      icon: hasWifi ? Icons.play_arrow_rounded : Icons.wifi_off_rounded,
      child: Text(
        hasWifi ? 'Start Screen Mirroring' : 'Connect to Hotspot to Stream',
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
