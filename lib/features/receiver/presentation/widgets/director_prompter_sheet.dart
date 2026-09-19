import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/saved_script_model.dart';
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

  void _applyScript({bool showFeedback = false}) {
    final text = _scriptController.text.trim();
    context.read<ReceiverBloc>().add(ReceiverPrompterScriptDispatched(text));
    setState(() => _isEditing = false);
    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script updated on Prompter!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  int get _wordCount {
    final text = _scriptController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String _formatEstReadTime(double speedWpm) {
    final words = _wordCount;
    if (words == 0 || speedWpm <= 0) return '0s';
    final totalSeconds = (words / speedWpm * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.subtitles_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Teleprompter Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
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
                        horizontal: 20,
                        vertical: 16,
                      ),
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
                          _buildScriptEditorSection(state),
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
              'READING PROGRESS',
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
                ReceiverPrompterCommandDispatched(isPlaying ? 'pause' : 'play'),
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
              const Icon(
                Icons.speed_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
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
                      ReceiverPrompterCommandDispatched('set_speed', {
                        'speedWpm': val,
                      }),
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
              const Icon(
                Icons.format_size_rounded,
                color: AppTheme.accent,
                size: 18,
              ),
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
                      ReceiverPrompterCommandDispatched('set_font_size', {
                        'fontSize': val,
                      }),
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

  void _showSaveScriptDialog(BuildContext context, ReceiverState state) {
    final activeScript = state.savedScripts
        .where((s) => s.id == state.activeScriptId)
        .firstOrNull;

    // Smart title suggestion:
    // If active script exists, use its title.
    // Otherwise derive from first non-empty line of text, or fallback to 'Script N'
    String initialTitle;
    if (activeScript != null) {
      initialTitle = activeScript.title;
    } else {
      final lines = _scriptController.text
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      if (lines.isNotEmpty) {
        final firstLine = lines.first;
        initialTitle = firstLine.length > 28
            ? '${firstLine.substring(0, 28).trim()}...'
            : firstLine;
      } else {
        initialTitle = 'Script ${state.savedScripts.length + 1}';
      }
    }

    final titleController = TextEditingController(text: initialTitle);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          activeScript != null
              ? 'Update / Save Script'
              : 'Save to Script Library',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeScript != null
                  ? 'Update current script or save with a new name:'
                  : 'Enter a title for this teleprompter script:',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          if (activeScript != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final newScript = SavedScript(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    content: _scriptController.text,
                    scrollSpeedWpm: state.prompterConfig.scrollSpeedWpm,
                    fontSize: state.prompterConfig.fontSize,
                    updatedAt: DateTime.now(),
                  );
                  context.read<ReceiverBloc>().add(
                    ReceiverPrompterScriptSaved(newScript),
                  );
                  _applyScript();
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved as new script: "$title"'),
                      backgroundColor: AppTheme.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Save as New'),
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
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final scriptToSave = SavedScript(
                  id:
                      activeScript?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  content: _scriptController.text,
                  scrollSpeedWpm: state.prompterConfig.scrollSpeedWpm,
                  fontSize: state.prompterConfig.fontSize,
                  updatedAt: DateTime.now(),
                );
                context.read<ReceiverBloc>().add(
                  ReceiverPrompterScriptSaved(scriptToSave),
                );
                _applyScript();
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      activeScript != null
                          ? 'Updated "$title"!'
                          : 'Saved "$title" to Script Library!',
                    ),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(activeScript != null ? 'Update' : 'Save Script'),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptEditorSection(ReceiverState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'TELEPROMPTER SCRIPT',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                NeumorphicButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  backgroundColor: Colors.white10,
                  textColor: Colors.white70,
                  borderRadius: 10,
                  icon: Icons.note_add_rounded,
                  onPressed: () {
                    _scriptController.clear();
                    _applyScript();
                  },
                  child: const Text('New', style: TextStyle(fontSize: 12)),
                ),
                NeumorphicButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  backgroundColor: const Color(0xFF21262D),
                  textColor: Colors.white,
                  borderRadius: 10,
                  icon: Icons.bookmark_add_rounded,
                  onPressed: () => _showSaveScriptDialog(context, state),
                  child: const Text('Save', style: TextStyle(fontSize: 12)),
                ),
                NeumorphicButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: AppTheme.primary,
                  textColor: Colors.white,
                  borderRadius: 10,
                  icon: Icons.check_rounded,
                  onPressed: () {
                    _applyScript(showFeedback: true);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Script library carousel
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.savedScripts.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                // "+ New Script" button
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _scriptController.clear();
                    _applyScript();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: AppTheme.accent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'New',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final script = state.savedScripts[index - 1];
              final isSelected = script.id == state.activeScriptId;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.read<ReceiverBloc>().add(
                    ReceiverPrompterScriptSelected(script),
                  );
                  _scriptController.text = script.content;
                  setState(() => _isEditing = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.25)
                        : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_rounded,
                        size: 14,
                        color: isSelected ? AppTheme.primary : Colors.white60,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        script.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            context.read<ReceiverBloc>().add(
                              ReceiverPrompterScriptDeleted(script.id),
                            );
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
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
            context.read<ReceiverBloc>().add(
              ReceiverPrompterScriptDispatched(text),
            );
            setState(() {});
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
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_wordCount words',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Est. read time: ${_formatEstReadTime(state.prompterConfig.scrollSpeedWpm)} (${state.prompterConfig.scrollSpeedWpm.round()} WPM)',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
