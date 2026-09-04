import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/models/prompter_model.dart';
import '../../../../core/services/audio_vad_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/receiver_bloc.dart';
import '../../bloc/receiver_event.dart';
import 'director_prompter_sheet.dart';
import 'prompter_hud_toolbar.dart';

/// Floating live teleprompter monitor overlay for the Receiver screen.
/// Enables the director to freely drag text anywhere on screen, toggle transparent
/// background for floating text, monitor live scrolling, and run offline VAD auto-scrolling
/// directly using the tablet's microphone.
class DirectorPrompterOverlay extends StatefulWidget {
  final PrompterConfig config;
  final GestureDragUpdateCallback? onPanUpdate;
  final VoidCallback? onResetPosition;
  final bool isCustomPositioned;

  const DirectorPrompterOverlay({
    super.key,
    required this.config,
    this.onPanUpdate,
    this.onResetPosition,
    this.isCustomPositioned = false,
  });

  @override
  State<DirectorPrompterOverlay> createState() =>
      _DirectorPrompterOverlayState();
}

class _DirectorPrompterOverlayState extends State<DirectorPrompterOverlay>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // Receiver-Only Voice Activity Detection (VAD)
  AudioVadService? _vadService;
  StreamSubscription<VadEvent>? _vadSubscription;
  bool _isSpeaking = false;
  double _audioLevel = 0.0;

  // Visual Customization: Solid Slate Card vs Transparent Floating Text
  bool _isTransparentBackground = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollProgressChanged);
    _ticker = createTicker(_onTick);

    if (widget.config.isVoiceActivated) {
      _startVad();
    }

    if (widget.config.isPlaying) {
      _ticker.start();
    }
  }

  int _lastProgressUpdateMs = 0;

  void _onScrollProgressChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (progress == 0.0 ||
          progress == 1.0 ||
          (now - _lastProgressUpdateMs >= 250 &&
              (progress - widget.config.scrollProgress).abs() >= 0.02)) {
        _lastProgressUpdateMs = now;
        context
            .read<ReceiverBloc>()
            .add(ReceiverPrompterProgressUpdated(progress));
      }
    }
  }

  void _rewindScript() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    context
        .read<ReceiverBloc>()
        .add(const ReceiverPrompterProgressUpdated(0.0));
    context
        .read<ReceiverBloc>()
        .add(const ReceiverPrompterCommandDispatched('rewind'));
  }

  Future<void> _startVad() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint(
            '[DirectorPrompterOverlay] Microphone permission not granted');
        return;
      }
      _vadService ??= AudioVadService();
      await _vadService!.stop();
      await _vadService!.setThreshold(-50.0);
      await _vadService!.start();
      await _vadSubscription?.cancel();
      _vadSubscription = _vadService!.vadStream.listen((event) {
        if (mounted) {
          setState(() {
            _isSpeaking = event.isSpeaking;
            _audioLevel = event.audioLevel;
          });
        }
      });
    } catch (e) {
      debugPrint('[DirectorPrompterOverlay] Failed to start VAD on receiver: $e');
    }
  }

  Future<void> _stopVad() async {
    await _vadSubscription?.cancel();
    _vadSubscription = null;
    await _vadService?.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _audioLevel = 0.0;
      });
    }
  }

  @override
  void didUpdateWidget(covariant DirectorPrompterOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.config.isVoiceActivated != oldWidget.config.isVoiceActivated) {
      if (widget.config.isVoiceActivated) {
        _startVad();
      } else {
        _stopVad();
      }
    }

    if (widget.config.isPlaying != oldWidget.config.isPlaying) {
      if (widget.config.isPlaying) {
        _lastElapsed = Duration.zero;
        if (!_ticker.isActive) _ticker.start();
      } else {
        _ticker.stop();
      }
    }

    // Remote rewind, script update, or position jump
    if ((widget.config.scriptText != oldWidget.config.scriptText ||
            (widget.config.scrollProgress == 0.0 &&
                _scrollController.hasClients &&
                _scrollController.offset > 0)) &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) return;

    // Receiver-Only Voice-Activated auto-scroll:
    // When enabled, advance only when the speaker is speaking!
    if (widget.config.isVoiceActivated && !_isSpeaking) {
      _lastElapsed = elapsed;
      return; // Paused on breath / silence
    }

    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final deltaSeconds =
        (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
    _lastElapsed = elapsed;

    final pxPerSec = widget.config.pixelsPerSecond;
    final deltaPixels = pxPerSec * deltaSeconds;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final nextScroll = (currentScroll + deltaPixels).clamp(0.0, maxScroll);

    if (nextScroll != currentScroll) {
      _scrollController.jumpTo(nextScroll);
    } else if (currentScroll >= maxScroll && maxScroll > 0) {
      // Reached the end of script
      context
          .read<ReceiverBloc>()
          .add(const ReceiverPrompterCommandDispatched('pause'));
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollProgressChanged);
    _ticker.dispose();
    _scrollController.dispose();
    _stopVad();
    _vadService?.dispose();
    super.dispose();
  }

  void _openScriptEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<ReceiverBloc>(),
        child: const DirectorPrompterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReceiverBloc>();
    final isPlaying = widget.config.isPlaying;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 420;
    final isTablet = screenWidth >= 640;

    final fontSize = widget.config.fontSize * (isCompact ? 0.8 : 1.0);
    final viewportHeight = isTablet ? 160.0 : (isCompact ? 115.0 : 135.0);

    return Container(
      decoration: BoxDecoration(
        color: _isTransparentBackground
            ? Colors.transparent
            : const Color(0xDC0B0F19), // Deep semi-transparent OLED slate
        borderRadius: BorderRadius.circular(20),
        border: _isTransparentBackground
            ? null
            : Border.all(
                color: isPlaying
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              ),
        boxShadow: _isTransparentBackground
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Draggable Header Bar & Quick Transport Bar
            GestureDetector(
              onPanUpdate: widget.onPanUpdate,
              behavior: HitTestBehavior.opaque,
              child: PrompterHudToolbar(
                config: widget.config,
                isPlaying: isPlaying,
                isSpeaking: _isSpeaking,
                audioLevel: _audioLevel,
                isTransparentBackground: _isTransparentBackground,
                isCustomPositioned: widget.isCustomPositioned,
                isCompact: isCompact,
                onRewind: _rewindScript,
                onTogglePlay: () => bloc.add(
                  ReceiverPrompterCommandDispatched(
                    isPlaying ? 'pause' : 'play',
                  ),
                ),
                onSwitchCamera: () => bloc.add(
                  const ReceiverPrompterCommandDispatched('switch_camera'),
                ),
                onToggleBackground: () => setState(
                  () => _isTransparentBackground = !_isTransparentBackground,
                ),
                onResetPosition: widget.onResetPosition,
                onOpenEditor: () => _openScriptEditor(context),
                onCloseOverlay: () =>
                    bloc.add(const ReceiverPrompterOverlayToggled()),
              ),
            ),

            // Live Micro Reading Progress Line
            LinearProgressIndicator(
              value: widget.config.scrollProgress,
              backgroundColor: Colors.white10,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 2,
            ),

            // Live Scrolling Text Viewport
            SizedBox(
              height: viewportHeight,
              child: Stack(
                children: [
                  // Scrolling Text
                  SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 16 : 24,
                      vertical: 36,
                    ),
                    child: Text(
                      widget.config.scriptText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        height: 1.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        shadows: _isTransparentBackground
                            ? const [
                                Shadow(blurRadius: 4.0, color: Colors.black, offset: Offset(1, 1)),
                                Shadow(blurRadius: 10.0, color: Colors.black, offset: Offset(-1, -1)),
                                Shadow(blurRadius: 20.0, color: Colors.black, offset: Offset(0, 2)),
                                Shadow(blurRadius: 30.0, color: Colors.black, offset: Offset(0, 4)),
                              ]
                            : null,
                      ),
                    ),
                  ),

                  // Top Gradient Mask (Only shown when not transparent)
                  if (!_isTransparentBackground)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xDC0B0F19),
                              const Color(0xDC0B0F19).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bottom Gradient Mask (Only shown when not transparent)
                  if (!_isTransparentBackground)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xDC0B0F19),
                              const Color(0xDC0B0F19).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Center Reading Guide Line (Golden Eye-Line)
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFFFBBF24).withValues(alpha: 0.7),
                              const Color(0xFFFBBF24),
                              const Color(0xFFFBBF24).withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
