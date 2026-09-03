import 'package:equatable/equatable.dart';

class PrompterConfig extends Equatable {
  static const String defaultScript = '''Welcome to the live studio broadcast!

Keep your eye line aligned with the golden marker at the top third of your display. Looking directly at the guide keeps you looking right down the camera lens!

When Voice-Activated mode is enabled, the prompter will scroll smoothly as you speak and freeze the instant you pause to breathe.

The director on the tablet can remotely edit this script, adjust your reading speed, and pause or rewind at any time.

Have a great take!''';

  final String scriptText;
  final double scrollSpeedWpm;
  final double fontSize;
  final bool isMirrored;
  final bool isVoiceActivated;
  final bool isPlaying;
  final double scrollProgress;
  final int countdown;

  const PrompterConfig({
    this.scriptText = defaultScript,
    this.scrollSpeedWpm = 140.0,
    this.fontSize = 32.0,
    this.isMirrored = false,
    this.isVoiceActivated = false,
    this.isPlaying = false,
    this.scrollProgress = 0.0,
    this.countdown = 0,
  });

  PrompterConfig copyWith({
    String? scriptText,
    double? scrollSpeedWpm,
    double? fontSize,
    bool? isMirrored,
    bool? isVoiceActivated,
    bool? isPlaying,
    double? scrollProgress,
    int? countdown,
  }) {
    return PrompterConfig(
      scriptText: scriptText ?? this.scriptText,
      scrollSpeedWpm: scrollSpeedWpm ?? this.scrollSpeedWpm,
      fontSize: fontSize ?? this.fontSize,
      isMirrored: isMirrored ?? this.isMirrored,
      isVoiceActivated: isVoiceActivated ?? this.isVoiceActivated,
      isPlaying: isPlaying ?? this.isPlaying,
      scrollProgress: scrollProgress ?? this.scrollProgress,
      countdown: countdown ?? this.countdown,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scriptText': scriptText,
      'scrollSpeedWpm': scrollSpeedWpm,
      'fontSize': fontSize,
      'isMirrored': isMirrored,
      'isVoiceActivated': isVoiceActivated,
      'isPlaying': isPlaying,
      'scrollProgress': scrollProgress,
      'countdown': countdown,
    };
  }

  factory PrompterConfig.fromJson(Map<String, dynamic> json) {
    return PrompterConfig(
      scriptText: json['scriptText'] as String? ?? defaultScript,
      scrollSpeedWpm: (json['scrollSpeedWpm'] as num?)?.toDouble() ?? 140.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 32.0,
      isMirrored: json['isMirrored'] as bool? ?? false,
      isVoiceActivated: json['isVoiceActivated'] as bool? ?? false,
      isPlaying: json['isPlaying'] as bool? ?? false,
      scrollProgress: (json['scrollProgress'] as num?)?.toDouble() ?? 0.0,
      countdown: (json['countdown'] as num?)?.toInt() ?? 0,
    );
  }

  /// Calculates scroll velocity in pixels per second based on WPM and estimated line height
  double get pixelsPerSecond {
    // Standard reading line has approx 8-10 words on mobile/tablet screen.
    // Line height is approximately fontSize * 1.5.
    // Velocity (px/s) = (WPM / 60) * (LineHeight / WordsPerLine)
    final lineHeight = fontSize * 1.5;
    const wordsPerLine = 8.0;
    final pixelsPerWord = lineHeight / wordsPerLine;
    return (scrollSpeedWpm / 60.0) * pixelsPerWord * 1.8;
  }

  @override
  List<Object?> get props => [
        scriptText,
        scrollSpeedWpm,
        fontSize,
        isMirrored,
        isVoiceActivated,
        isPlaying,
        scrollProgress,
        countdown,
      ];
}
