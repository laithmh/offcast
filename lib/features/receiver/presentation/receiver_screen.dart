import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/services/foreground_service_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/exit_confirmation_dialog.dart';
import '../bloc/receiver_bloc.dart';
import '../bloc/receiver_event.dart';
import '../bloc/receiver_state.dart';
import '../data/embedded_signaling_server.dart';
import '../data/receiver_webrtc_service.dart';
import 'widgets/director_prompter_overlay.dart';
import 'widgets/receiver_in_stream_toolbar.dart';
import 'widgets/receiver_top_bar.dart';
import 'widgets/receiver_waiting_view.dart';
import 'widgets/social_framing_overlay.dart';

/// Entry screen for the Receiver / Director Monitor role.
/// Orchestrates signaling server lifecycle, WebRTC video renderer, and director overlays.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EmbeddedSignalingServer>.value(
          value: _signalingServer,
        ),
        RepositoryProvider<ReceiverWebRTCService>.value(value: _webrtcService),
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

class _ReceiverViewState extends State<_ReceiverView>
    with SingleTickerProviderStateMixin {
  bool _showOverlay = true;
  bool _isMirrored = false;
  int _quarterTurns = 0;
  RTCVideoViewObjectFit _objectFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
  Offset? _prompterOffset;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ForegroundServiceHelper.setKeepScreenOn(true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ForegroundServiceHelper.setKeepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  void _cycleQuarterTurns() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  void _toggleMirror() {
    setState(() => _isMirrored = !_isMirrored);
  }

  void _toggleFit() {
    setState(() {
      _objectFit =
          _objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
    });
  }

  void _onPrompterPanUpdate(
    DragUpdateDetails details,
    Size screenSize,
    EdgeInsets safeArea,
  ) {
    setState(() {
      final isTablet = screenSize.width >= 640;
      final overlayWidth = (isTablet ? 700.0 : screenSize.width - 24.0).clamp(
        280.0,
        screenSize.width,
      );
      final overlayHeight = isTablet ? 230.0 : 190.0;

      final defaultX = (screenSize.width - overlayWidth) / 2.0;
      final defaultY =
          screenSize.height - overlayHeight - (_showOverlay ? 90.0 : 36.0);

      final current = _prompterOffset ?? Offset(defaultX, defaultY);
      final newX = (current.dx + details.delta.dx).clamp(
        4.0,
        (screenSize.width - overlayWidth - 4.0).clamp(4.0, screenSize.width),
      );
      final newY = (current.dy + details.delta.dy).clamp(
        safeArea.top + 8.0,
        (screenSize.height - overlayHeight - 8.0).clamp(
          safeArea.top + 8.0,
          screenSize.height,
        ),
      );

      _prompterOffset = Offset(newX, newY);
    });
  }

  void _resetPrompterPosition() {
    setState(() => _prompterOffset = null);
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return ExitConfirmationDialog.show(
      context,
      title: 'Disconnect Stream?',
      message: 'An active broadcast session is currently playing. Leaving will terminate the live display view.',
      cancelLabel: 'Keep Viewing',
      confirmLabel: 'Exit & Disconnect',
    );
  }

  @override
  Widget build(BuildContext context) {
    final webrtcService = context.read<ReceiverWebRTCService>();

    return BlocConsumer<ReceiverBloc, ReceiverState>(
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
        return PopScope(
          canPop: !state.isStreaming,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _showExitConfirmation(context);
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleOverlay,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video rendering or standby waiting placeholder
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: state.isStreaming
                          ? _buildVideoView(webrtcService)
                          : ReceiverWaitingView(
                              state: state,
                              pulseAnimation: _pulseController,
                            ),
                    ),
                  ),

                  // Social Framing Guides Layer
                  if (state.isStreaming &&
                      state.framingMode != SocialFramingMode.none)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SocialFramingOverlay(mode: state.framingMode),
                      ),
                    ),

                  // Live Draggable Director Prompter Monitor Layer
                  if (state.isStreaming && state.isPrompterOverlayVisible)
                    _buildDraggablePrompter(state),

                  // Overlay Controls Layer
                  if (_showOverlay)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: ReceiverTopBar(state: state),
                            ),
                            if (state.isStreaming)
                              Positioned(
                                right: 16,
                                top: MediaQuery.of(context).padding.top + 70,
                                child: ReceiverInStreamToolbar(
                                  state: state,
                                  objectFit: _objectFit,
                                  isMirrored: _isMirrored,
                                  onToggleFit: _toggleFit,
                                  onCycleTurns: _cycleQuarterTurns,
                                  onToggleMirror: _toggleMirror,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoView(ReceiverWebRTCService webrtcService) {
    final video = RTCVideoView(
      webrtcService.renderer,
      mirror: _isMirrored,
      objectFit: _objectFit,
      filterQuality: FilterQuality.low,
    );

    if (_quarterTurns != 0) {
      return RotatedBox(quarterTurns: _quarterTurns, child: video);
    }
    return video;
  }

  Widget _buildDraggablePrompter(ReceiverState state) {
    return Builder(
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final safeArea = MediaQuery.of(context).padding;
        final isTablet = screenSize.width >= 640;
        final overlayWidth = (isTablet ? 700.0 : screenSize.width - 24.0).clamp(
          280.0,
          screenSize.width,
        );
        final overlayHeight = isTablet ? 230.0 : 190.0;

        final defaultX = (screenSize.width - overlayWidth) / 2.0;
        final defaultY =
            screenSize.height - overlayHeight - (_showOverlay ? 90.0 : 36.0);

        final leftPos = (_prompterOffset?.dx ?? defaultX).clamp(
          4.0,
          (screenSize.width - overlayWidth - 4.0).clamp(4.0, screenSize.width),
        );
        final topPos = (_prompterOffset?.dy ?? defaultY).clamp(
          safeArea.top + 8.0,
          (screenSize.height - overlayHeight - 8.0).clamp(
            safeArea.top + 8.0,
            screenSize.height,
          ),
        );

        return Positioned(
          left: leftPos,
          top: topPos,
          width: overlayWidth,
          child: DirectorPrompterOverlay(
            config: state.prompterConfig,
            onPanUpdate: (details) =>
                _onPrompterPanUpdate(details, screenSize, safeArea),
            onResetPosition: _resetPrompterPosition,
            isCustomPositioned: _prompterOffset != null,
          ),
        );
      },
    );
  }
}
