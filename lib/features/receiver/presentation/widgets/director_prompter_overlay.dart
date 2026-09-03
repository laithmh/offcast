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

  void _onScrollProgressChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
      if ((progress - widget.config.scrollProgress).abs() > 0.005 ||
          progress == 0.0 ||
          progress == 1.0) {
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
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isTransparentBackground
                      ? Colors.black.withValues(alpha: 0.65)
                      : Colors.black.withValues(alpha: 0.35),
                  borderRadius: _isTransparentBackground
                      ? BorderRadius.circular(16)
                      : null,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Draggable Grip Indicator
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),

                    // Status Dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaying ? AppTheme.success : AppTheme.warning,
                        boxShadow: [
                          BoxShadow(
                            color: (isPlaying ? AppTheme.success : AppTheme.warning)
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCompact ? 'PROMPTER' : 'PROMPTER MONITOR',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white70,
                      ),
                    ),

                    // Live VAD Microphone Pill
                    if (widget.config.isVoiceActivated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isSpeaking
                              ? AppTheme.success.withValues(alpha: 0.25)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isSpeaking ? AppTheme.success : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              size: 12,
                              color: _isSpeaking ? AppTheme.success : Colors.white54,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _isSpeaking ? 'SPEAKING' : 'VAD ON',
                              style: TextStyle(
                                color: _isSpeaking ? AppTheme.success : Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 18,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _audioLevel.clamp(0.1, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isSpeaking ? AppTheme.success : Colors.white30,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Reading Progress % Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${(widget.config.scrollProgress * 100).round()}%',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // WPM Speed Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${widget.config.scrollSpeedWpm.toInt()} WPM',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Rewind / Reset Script to Top Button
                    IconButton(
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: Colors.white70,
                        size: 19,
                      ),
                      tooltip: 'Reset Script to Top',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: _rewindScript,
                    ),

                    // Play / Pause Button
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: isPlaying ? AppTheme.warning : AppTheme.success,
                        size: 24,
                      ),
                      tooltip: isPlaying ? 'Pause Prompter' : 'Play Prompter',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => bloc.add(
                        ReceiverPrompterCommandDispatched(
                          isPlaying ? 'pause' : 'play',
                        ),
                      ),
                    ),

                    // Remote Flip Camera Button
                    IconButton(
                      icon: const Icon(
                        Icons.cameraswitch_rounded,
                        color: AppTheme.accent,
                        size: 19,
                      ),
                      tooltip: 'Remote Flip Camera',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => bloc.add(
                        const ReceiverPrompterCommandDispatched(
                            'switch_camera'),
                      ),
                    ),

                    // Transparent Background Toggle Button
                    IconButton(
                      icon: Icon(
                        _isTransparentBackground
                            ? Icons.layers_rounded
                            : Icons.opacity_rounded,
                        color: _isTransparentBackground
                            ? AppTheme.accent
                            : Colors.white70,
                        size: 19,
                      ),
                      tooltip: _isTransparentBackground
                          ? 'Restore Solid Background'
                          : 'Remove Background (Transparent Floating Text)',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => setState(() =>
                          _isTransparentBackground =
                              !_isTransparentBackground),
                    ),

                    // Reset Position Button (shown if dragged away from center)
                    if (widget.isCustomPositioned)
                      IconButton(
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                          color: AppTheme.warning,
                          size: 20,
                        ),
                        tooltip: 'Reset Overlay Position to Bottom Center',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        onPressed: widget.onResetPosition,
                      ),

                    // Edit Script Button
                    IconButton(
                      icon: const Icon(
                        Icons.edit_note_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      tooltip: 'Edit Script & Settings',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => _openScriptEditor(context),
                    ),

                    // Close / Hide Overlay Button
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      tooltip: 'Hide Prompter Monitor',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () =>
                          bloc.add(const ReceiverPrompterOverlayToggled()),
                    ),
                  ],
                ),
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
