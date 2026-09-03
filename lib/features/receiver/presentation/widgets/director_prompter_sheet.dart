import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neumorphic_widgets.dart';
import '../../bloc/receiver_bloc.dart';
import '../../bloc/receiver_event.dart';
import '../../bloc/receiver_state.dart';

class DirectorPrompterSheet extends StatefulWidget {
  const DirectorPrompterSheet({super.key});

  @override
  State<DirectorPrompterSheet> createState() => _DirectorPrompterSheetState();
}

class _DirectorPrompterSheetState extends State<DirectorPrompterSheet> {
  late final TextEditingController _scriptController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final prompter = context.read<ReceiverBloc>().state.prompterConfig;
    _scriptController = TextEditingController(text: prompter.scriptText);
  }

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  void _pushScript() {
    final text = _scriptController.text.trim();
    if (text.isNotEmpty) {
      context
          .read<ReceiverBloc>()
          .add(ReceiverPrompterScriptDispatched(text));
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script pushed to Talent display!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceiverBloc, ReceiverState>(
      listenWhen: (prev, curr) =>
          prev.prompterConfig.scriptText != curr.prompterConfig.scriptText,
      listener: (context, state) {
        if (!_isEditing) {
          _scriptController.text = state.prompterConfig.scriptText;
        }
      },
      builder: (context, state) {
        final prompter = state.prompterConfig;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF13171F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 30,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // 1. Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.subtitles_rounded,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Director Prompter Remote',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white12),

              // 3. Scrollable Controls Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Reading Progress Bar
                      _buildProgressIndicator(prompter.scrollProgress),
                      const SizedBox(height: 16),

                      // Quick Transport Controls
                      _buildTransportControls(prompter),
                      const SizedBox(height: 20),

                      // Speed and Font Size Sliders
                      _buildParameterSliders(prompter),
                      const SizedBox(height: 20),

                      // Live Script Editor Section
                      _buildScriptEditorSection(),
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

  Widget _buildProgressIndicator(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TALENT READING PROGRESS',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            color: AppTheme.primary,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls(dynamic prompter) {
    final bloc = context.read<ReceiverBloc>();
    final isPlaying = prompter.isPlaying as bool;
    final isVoice = prompter.isVoiceActivated as bool;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rewind to top
          IconButton(
            icon: const Icon(Icons.replay_rounded, size: 26),
            color: Colors.white,
            tooltip: 'Rewind Script to Top',
            onPressed: () {
              bloc.add(const ReceiverPrompterProgressUpdated(0.0));
              bloc.add(const ReceiverPrompterCommandDispatched('rewind'));
            },
          ),

          // Big Play/Pause
          GestureDetector(
            onTap: () {
              bloc.add(
                ReceiverPrompterCommandDispatched(
                    isPlaying ? 'pause' : 'play'),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isPlaying ? AppTheme.warning : AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isPlaying ? AppTheme.warning : AppTheme.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),

          // Toggle Voice-Activated Auto-Scroll
          IconButton(
            icon: Icon(
              isVoice
                  ? Icons.record_voice_over_rounded
                  : Icons.voice_over_off_rounded,
              size: 26,
            ),
            color: isVoice ? AppTheme.success : Colors.white60,
            tooltip: 'Toggle Voice Activation',
            onPressed: () {
              bloc.add(
                ReceiverPrompterCommandDispatched('set_voice_activated', {
                  'isVoiceActivated': !isVoice,
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSliders(dynamic prompter) {
    final bloc = context.read<ReceiverBloc>();
    final speed = (prompter.scrollSpeedWpm as num).toDouble();
    final font = (prompter.fontSize as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // WPM Speed
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Speed: ${speed.round()} WPM',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Slider(
                  value: speed,
                  min: 60.0,
                  max: 300.0,
                  divisions: 24,
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.white12,
                  onChanged: (val) {
                    bloc.add(
                      ReceiverPrompterCommandDispatched(
                          'set_speed', {'speedWpm': val}),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Font Size
          Row(
            children: [
              const Icon(Icons.format_size_rounded,
                  color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Font: ${font.round()}pt',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Slider(
                  value: font,
                  min: 18.0,
                  max: 56.0,
                  divisions: 19,
                  activeColor: AppTheme.accent,
                  inactiveColor: Colors.white12,
                  onChanged: (val) {
                    bloc.add(
                      ReceiverPrompterCommandDispatched(
                          'set_font_size', {'fontSize': val}),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScriptEditorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE SCRIPT CONTENT',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            NeumorphicButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              backgroundColor: AppTheme.primary,
              textColor: Colors.white,
              borderRadius: 12,
              icon: Icons.send_rounded,
              onPressed: _pushScript,
              child: const Text('Push to Talent'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _scriptController,
          maxLines: 8,
          style: const TextStyle(
            color: Color(0xFFF0F6FC),
            fontSize: 13,
            height: 1.5,
          ),
          onChanged: (text) {
            if (!_isEditing) setState(() => _isEditing = true);
            context
                .read<ReceiverBloc>()
                .add(ReceiverPrompterScriptDispatched(text));
          },
          decoration: InputDecoration(
            hintText: 'Type or edit teleprompter script...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF0D1117),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
