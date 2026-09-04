import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/models/prompter_model.dart';
import '../../../../core/services/audio_vad_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';
import 'prompter_countdown_overlay.dart';
import 'prompter_eye_line_marker.dart';
import 'prompter_hud_bar.dart';

/// Studio teleprompter view displayed on the talent phone display.
/// Integrates voice-activity auto-scrolling, speed tuning, optical mirror mode, and lens eye-line guide.
class TalentPrompterView extends StatefulWidget {
  final PrompterConfig config;
  final VoidCallback onToggleHud;

  const TalentPrompterView({
    super.key,
    required this.config,
    required this.onToggleHud,
  });

  @override
  State<TalentPrompterView> createState() => _TalentPrompterViewState();
}

class _TalentPrompterViewState extends State<TalentPrompterView>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final Ticker _ticker;

  int _countdown = 0;
  Timer? _countdownTimer;
  Duration _lastElapsed = Duration.zero;
  int _lastProgressUpdateMs = 0;

  AudioVadService? _vadService;
  StreamSubscription<VadEvent>? _vadSubscription;
  bool _isSpeaking = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick);

    if (widget.config.isVoiceActivated) {
      _startVad();
    }

    if (widget.config.isPlaying) {
      _ticker.start();
    }
  }

  Future<void> _startVad() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final requested = await Permission.microphone.request();
        if (!requested.isGranted) {
          debugPrint(
              '[TalentPrompterView] Microphone permission denied for VAD.');
          return;
        }
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
          });
        }
      });
    } catch (e) {
      debugPrint(
          '[TalentPrompterView] Failed to start VAD on talent device: $e');
    }
  }

  Future<void> _stopVad() async {
    await _vadSubscription?.cancel();
    _vadSubscription = null;
    await _vadService?.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant TalentPrompterView oldWidget) {
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
        _startWithCountdown();
      } else {
        _ticker.stop();
        _countdownTimer?.cancel();
        setState(() => _countdown = 0);
      }
    }

    // Remote rewind request
    if (widget.config.scrollProgress == 0.0 &&
        oldWidget.config.scrollProgress != 0.0 &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _startWithCountdown() {
    setState(() => _countdown = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _countdown = 0);
        _lastElapsed = Duration.zero;
        if (!_ticker.isActive) {
          _ticker.start();
        }
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (!mounted ||
        !_scrollController.hasClients ||
        !widget.config.isPlaying ||
        _countdown > 0) {
      _lastElapsed = elapsed;
      return;
    }

    if (widget.config.isVoiceActivated && !_isSpeaking) {
      _lastElapsed = elapsed;
      return;
    }

    final deltaSeconds = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (deltaSeconds <= 0 || deltaSeconds > 0.1) return;

    final pixelsPerSecond = widget.config.pixelsPerSecond;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    if (currentScroll >= maxScroll && maxScroll > 0) {
      _ticker.stop();
      context
          .read<SenderBloc>()
          .add(const SenderPrompterPlayPauseToggled());
      return;
    }

    final newOffset =
        (currentScroll + (pixelsPerSecond * deltaSeconds)).clamp(0.0, maxScroll);
    _scrollController.jumpTo(newOffset);

    // Throttle remote BLoC progress events (<= 4 updates per second)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastProgressUpdateMs > 250 && maxScroll > 0) {
      _lastProgressUpdateMs = nowMs;
      final progress = newOffset / maxScroll;
      context
          .read<SenderBloc>()
          .add(SenderPrompterProgressUpdated(progress));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ticker.dispose();
    _scrollController.dispose();
    _stopVad();
    _vadService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompterContent = Scaffold(
      backgroundColor: const Color(0xFF07090E), // Deep OLED studio black
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Text Scroller Layer
          Positioned.fill(
            child: _buildTextScroller(),
          ),

          // 2. Eye-Line Marker Guide
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            child: const PrompterEyeLineMarker(),
          ),

          // 3. Top HUD: Status Pill & View Switcher
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildTopStatusHeader(),
          ),

          // 4. Countdown 3-2-1 Overlay
          if (_countdown > 0)
            Positioned.fill(
              child: PrompterCountdownOverlay(countdown: _countdown),
            ),

          // 5. Bottom Floating Control Bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
            child: PrompterHudBar(
              config: widget.config,
              onRewind: () {
                _scrollController.jumpTo(0.0);
                context
                    .read<SenderBloc>()
                    .add(const SenderPrompterRewindRequested());
              },
            ),
          ),
        ],
      ),
    );

    // Apply horizontal flip for beam-splitter glass if enabled
    if (widget.config.isMirrored) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(pi),
        child: prompterContent,
      );
    }

    return prompterContent;
  }

  Widget _buildTopStatusHeader() {
    return Row(
      children: [
        // Camera switch button
        NeumorphicIconButton(
          size: 40,
          icon: Icons.flip_camera_ios_rounded,
          iconColor: Colors.white,
          onPressed: () => context
              .read<SenderBloc>()
              .add(const SenderCameraFacingToggled()),
        ),
        const SizedBox(width: 10),

        // Status pill
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.config.isPlaying
                    ? AppTheme.success
                    : Colors.white24,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.config.isPlaying
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 16,
                  color: widget.config.isPlaying
                      ? AppTheme.success
                      : Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.config.isPlaying
                        ? 'PROMPTER ROLLING • ${widget.config.scrollSpeedWpm.toInt()} WPM'
                        : 'PROMPTER PAUSED',
                    style: TextStyle(
                      color: widget.config.isPlaying
                          ? AppTheme.success
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Switch to Broadcast Telemetry HUD button
        NeumorphicIconButton(
          size: 40,
          icon: Icons.dashboard_rounded,
          iconColor: AppTheme.primary,
          tooltip: 'Broadcast HUD',
          onPressed: widget.onToggleHud,
        ),
      ],
    );
  }

  Widget _buildTextScroller() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = screenHeight * 0.28;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: screenHeight * 0.5,
        left: 28,
        right: 28,
      ),
      child: Text(
        widget.config.scriptText,
        style: TextStyle(
          color: const Color(0xFFF0F6FC),
          fontSize: widget.config.fontSize,
          fontWeight: FontWeight.w700,
          height: 1.55,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
