import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/prompter_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/sender_bloc.dart';
import '../../bloc/sender_event.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _ticker = createTicker(_onTick);

    if (widget.config.isPlaying) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant TalentPrompterView oldWidget) {
    super.didUpdateWidget(oldWidget);

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
        if (!_ticker.isActive && widget.config.isPlaying) {
          _ticker.start();
        }
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) return;

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
      if (maxScroll > 0) {
        final progress = (nextScroll / maxScroll).clamp(0.0, 1.0);
        context
            .read<SenderBloc>()
            .add(SenderPrompterProgressUpdated(progress));
      }
    } else if (currentScroll >= maxScroll && maxScroll > 0) {
      // Reached the end of script
      context
          .read<SenderBloc>()
          .add(const SenderPrompterPlayPauseToggled());
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ticker.dispose();
    _scrollController.dispose();
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

          // 2. Eye-Line Marker Guide (aligned at top 28% near camera sensor)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            child: _buildEyeLineMarker(),
          ),

          // 3. Top HUD: VAD Voice Status Pill & Mode Toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildTopStatusHeader(),
          ),

          // 4. Countdown 3-2-1 Overlay
          if (_countdown > 0)
            Positioned.fill(
              child: _buildCountdownOverlay(),
            ),

          // 5. Bottom Floating Control Bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
            child: _buildBottomControlBar(),
          ),
        ],
      ),
    );

    // Apply horizontal flip for beam-splitter prompter glass if enabled
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

  Widget _buildEyeLineMarker() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.12),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFFFB300).withValues(alpha: 0.6),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: const Color(0xFFFFB300).withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.arrow_right_rounded,
              color: Color(0xFFFFB300),
              size: 22,
            ),
            SizedBox(width: 4),
            Text(
              'EYE LINE — KEEP GAZE HERE FOR LENS CONTACT',
              style: TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_left_rounded,
              color: Color(0xFFFFB300),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextScroller() {
    final screenHeight = MediaQuery.of(context).size.height;
    // Buffer top padding so first line starts right at the eye-line guide
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
          color: const Color(0xFFF0F6FC), // High contrast crisp prompter white
          fontSize: widget.config.fontSize,
          fontWeight: FontWeight.w700,
          height: 1.55,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Text(
          '$_countdown',
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 130,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: AppTheme.primary,
                blurRadius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed and Font Size Row
          Row(
            children: [
              // WPM Indicator
              const Icon(Icons.speed_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '${widget.config.scrollSpeedWpm.round()} WPM',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Slider(
                  value: widget.config.scrollSpeedWpm,
                  min: 60.0,
                  max: 300.0,
                  divisions: 24,
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    context
                        .read<SenderBloc>()
                        .add(SenderPrompterSpeedChanged(val));
                  },
                ),
              ),

              // Font Size Controls
              IconButton(
                icon: const Icon(Icons.text_decrease_rounded, size: 20),
                color: Colors.white70,
                onPressed: () {
                  final newSize = (widget.config.fontSize - 4).clamp(18.0, 56.0);
                  context
                      .read<SenderBloc>()
                      .add(SenderPrompterFontSizeChanged(newSize));
                },
              ),
              Text(
                '${widget.config.fontSize.round()}pt',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase_rounded, size: 20),
                color: Colors.white70,
                onPressed: () {
                  final newSize = (widget.config.fontSize + 4).clamp(18.0, 56.0);
                  context
                      .read<SenderBloc>()
                      .add(SenderPrompterFontSizeChanged(newSize));
                },
              ),
            ],
          ),

          const Divider(height: 8, color: Colors.white12),

          // Primary Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind to top
              IconButton(
                icon: const Icon(Icons.replay_rounded, size: 24),
                color: Colors.white,
                tooltip: 'Rewind to Top',
                onPressed: () {
                  _scrollController.jumpTo(0.0);
                  context
                      .read<SenderBloc>()
                      .add(const SenderPrompterRewindRequested());
                },
              ),

              // Horizontal mirror toggle
              IconButton(
                icon: Icon(
                  widget.config.isMirrored
                      ? Icons.flip_rounded
                      : Icons.flip_camera_android_rounded,
                  size: 22,
                ),
                color: widget.config.isMirrored
                    ? AppTheme.accent
                    : Colors.white70,
                tooltip: 'Flip for Glass Beam-Splitter',
                onPressed: () {
                  context
                      .read<SenderBloc>()
                      .add(const SenderPrompterMirrorToggled());
                },
              ),

              // Big Play/Pause Button
              GestureDetector(
                onTap: () {
                  context
                      .read<SenderBloc>()
                      .add(const SenderPrompterPlayPauseToggled());
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.config.isPlaying
                        ? AppTheme.warning
                        : AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.config.isPlaying
                                ? AppTheme.warning
                                : AppTheme.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.config.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              // Voice-Activated Auto-Scroll Toggle
              IconButton(
                icon: Icon(
                  widget.config.isVoiceActivated
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  size: 24,
                ),
                color: widget.config.isVoiceActivated
                    ? AppTheme.success
                    : Colors.white70,
                tooltip: 'Voice-Activated Auto-Scroll',
                onPressed: () {
                  context
                      .read<SenderBloc>()
                      .add(const SenderPrompterVoiceActivationToggled());
                },
              ),

              // Quick Script Edit Dialog
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 26),
                color: Colors.white70,
                tooltip: 'Edit Script',
                onPressed: () => _showEditScriptDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditScriptDialog(BuildContext context) {
    final textController =
        TextEditingController(text: widget.config.scriptText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Edit Talent Script',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: textController,
            maxLines: 12,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Enter teleprompter script...',
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final newText = textController.text.trim();
              if (newText.isNotEmpty) {
                context
                    .read<SenderBloc>()
                    .add(SenderPrompterScriptUpdated(newText));
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save & Sync'),
          ),
        ],
      ),
    );
  }
}
