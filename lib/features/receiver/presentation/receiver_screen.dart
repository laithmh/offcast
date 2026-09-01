import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/constants/webrtc_constants.dart';
import '../../../core/services/foreground_service_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/neumorphic_widgets.dart';
import '../bloc/receiver_bloc.dart';
import '../bloc/receiver_event.dart';
import '../bloc/receiver_state.dart';
import '../data/embedded_signaling_server.dart';
import '../data/receiver_webrtc_service.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  late final EmbeddedSignalingServer _signalingServer;
  late final ReceiverWebRTCService _webrtcService;
  late final ReceiverBloc _receiverBloc;

  @override
  void initState() {
    super.initState();
    _signalingServer = EmbeddedSignalingServer();
    _webrtcService = ReceiverWebRTCService(signalingServer: _signalingServer);
    _receiverBloc = ReceiverBloc(
      signalingServer: _signalingServer,
      webrtcService: _webrtcService,
    )..add(const ReceiverStartServerRequested());
  }

  @override
  void dispose() {
    _receiverBloc.close();
    _webrtcService.dispose();
    _signalingServer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EmbeddedSignalingServer>.value(
          value: _signalingServer,
        ),
        RepositoryProvider<ReceiverWebRTCService>.value(
          value: _webrtcService,
        ),
      ],
      child: BlocProvider<ReceiverBloc>.value(
        value: _receiverBloc,
        child: const _ReceiverView(),
      ),
    );
  }
}

class _ReceiverView extends StatefulWidget {
  const _ReceiverView();

  @override
  State<_ReceiverView> createState() => _ReceiverViewState();
}

class _ReceiverViewState extends State<_ReceiverView> {
  bool _showOverlay = true;
  bool _isMirrored = false;
  int _quarterTurns = 0;
  Timer? _autoHideTimer;
  RTCVideoViewObjectFit _objectFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ForegroundServiceHelper.setKeepScreenOn(true);
    _resetAutoHideTimer();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    ForegroundServiceHelper.setKeepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showOverlay) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
      if (_showOverlay) {
        _resetAutoHideTimer();
      }
    });
  }

  void _cycleQuarterTurns() {
    _resetAutoHideTimer();
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  void _toggleMirror() {
    _resetAutoHideTimer();
    setState(() => _isMirrored = !_isMirrored);
  }

  void _toggleFit() {
    _resetAutoHideTimer();
    setState(() {
      _objectFit =
          _objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
    });
  }

  @override
  Widget build(BuildContext context) {
    final webrtcService = context.read<ReceiverWebRTCService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<ReceiverBloc, ReceiverState>(
        listener: (context, state) {
          if (state.status == ReceiverStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOverlay,
            child: Stack(
              children: [
                Positioned.fill(
                  child: state.isStreaming
                      ? Transform.scale(
                          scaleX: _isMirrored ? -1.0 : 1.0,
                          child: RotatedBox(
                            quarterTurns: _quarterTurns,
                            child: RTCVideoView(
                              webrtcService.renderer,
                              objectFit: _objectFit,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        )
                      : _buildWaitingPlaceholder(state),
                ),
                if (_showOverlay) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(context, state),
                  ),
                  if (state.isStreaming)
                    Positioned(
                      right: 16,
                      top: MediaQuery.of(context).padding.top + 70,
                      child: _buildInStreamToolbar(),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInStreamToolbar() {
    final isCover =
        _objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.neumorphicShadowElevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeumorphicIconButton(
            size: 40,
            tooltip: 'Rotate (${_quarterTurns * 90}°)',
            icon: Icons.rotate_90_degrees_cw_rounded,
            iconColor: AppTheme.primary,
            onPressed: _cycleQuarterTurns,
          ),
          const SizedBox(height: 8),
          NeumorphicIconButton(
            size: 40,
            tooltip: _isMirrored ? 'Disable Mirror' : 'Mirror Feed (Selfie)',
            icon: Icons.flip_rounded,
            iconColor: _isMirrored ? AppTheme.accent : AppTheme.textPrimary,
            onPressed: _toggleMirror,
          ),
          const SizedBox(height: 8),
          NeumorphicIconButton(
            size: 40,
            tooltip: isCover ? 'Fit View' : 'Fill View',
            icon: isCover
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            iconColor: AppTheme.textPrimary,
            onPressed: _toggleFit,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ReceiverState state) {
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
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Receiver Viewfinder',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                if (state.isStreaming)
                  StreamBuilder<StreamPerformanceStats>(
                    stream: context.read<ReceiverWebRTCService>().statsStream,
                    builder: (context, snapshot) {
                      final stats = snapshot.data ?? const StreamPerformanceStats();
                      return Text(
                        '${stats.fps.toStringAsFixed(0)} FPS • ${stats.latencyMs}ms • ${stats.bitrateMbps} Mbps',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  )
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
            backgroundColor: state.isStreaming ? AppTheme.error : AppTheme.primary,
            textColor: Colors.white,
            borderRadius: 12,
            onPressed: () => context
                .read<ReceiverBloc>()
                .add(const ReceiverStartServerRequested()),
            child: Text(state.isStreaming ? 'Reset' : 'Restart'),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingPlaceholder(ReceiverState state) {
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
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: AppTheme.warning,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.shadowLight,
                        offset: Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: AppTheme.shadowDark,
                        offset: Offset(6, 6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    hasNetwork ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
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
                    : 'Keep this screen open on your display device. On the casting device, tap Start Screen Mirroring.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (hasNetwork) ...[
                  const SizedBox(height: 24),
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
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          color: AppTheme.textSecondary,
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
                  const NeumorphicBadge(
                    label: 'Zero-Touch Beacon Active',
                    icon: Icons.sensors_rounded,
                    color: AppTheme.success,
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
