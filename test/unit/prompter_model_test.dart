import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/constants/webrtc_constants.dart';
import 'package:hotspot_screen_sharing/core/models/prompter_model.dart';
import 'package:hotspot_screen_sharing/core/services/audio_vad_service.dart';

void main() {
  group('PrompterConfig Tests', () {
    test('Default values are correctly initialized', () {
      const config = PrompterConfig();
      expect(
        config.scriptText,
        contains('Welcome to the live studio broadcast'),
      );
      expect(config.scrollSpeedWpm, 140.0);
      expect(config.fontSize, 32.0);
      expect(config.isMirrored, isFalse);
      expect(config.isVoiceActivated, isFalse);
      expect(config.isPlaying, isFalse);
      expect(config.scrollProgress, 0.0);
      expect(config.countdown, 0);
    });

    test('copyWith properly updates fields', () {
      const config = PrompterConfig();
      final updated = config.copyWith(
        scriptText: 'New script text',
        scrollSpeedWpm: 200.0,
        fontSize: 40.0,
        isMirrored: true,
        isVoiceActivated: false,
        isPlaying: true,
        scrollProgress: 0.5,
        countdown: 5,
      );

      expect(updated.scriptText, 'New script text');
      expect(updated.scrollSpeedWpm, 200.0);
      expect(updated.fontSize, 40.0);
      expect(updated.isMirrored, isTrue);
      expect(updated.isVoiceActivated, isFalse);
      expect(updated.isPlaying, isTrue);
      expect(updated.scrollProgress, 0.5);
      expect(updated.countdown, 5);
    });

    test('Serialization and deserialization matches', () {
      const original = PrompterConfig(
        scriptText: 'Testing teleprompter JSON serialization.',
        scrollSpeedWpm: 155.0,
        fontSize: 28.0,
        isMirrored: true,
        isVoiceActivated: false,
        isPlaying: true,
        scrollProgress: 0.72,
        countdown: 0,
      );

      final json = original.toJson();
      final restored = PrompterConfig.fromJson(json);

      expect(restored.scriptText, original.scriptText);
      expect(restored.scrollSpeedWpm, original.scrollSpeedWpm);
      expect(restored.fontSize, original.fontSize);
      expect(restored.isMirrored, original.isMirrored);
      expect(restored.isVoiceActivated, original.isVoiceActivated);
      expect(restored.isPlaying, original.isPlaying);
      expect(restored.scrollProgress, original.scrollProgress);
      expect(restored.countdown, original.countdown);
    });

    test('pixelsPerSecond calculates accurate scrolling velocity', () {
      const config130 = PrompterConfig(scrollSpeedWpm: 130.0, fontSize: 32.0);
      final expected130 = (130.0 / 60.0) * ((32.0 * 1.5) / 8.0) * 1.8;
      expect(config130.pixelsPerSecond, closeTo(expected130, 0.01));

      const config260 = PrompterConfig(scrollSpeedWpm: 260.0, fontSize: 32.0);
      expect(
        config260.pixelsPerSecond,
        closeTo(config130.pixelsPerSecond * 2, 0.01),
      );
    });
  });

  group('AudioVadService & VadEvent Tests', () {
    test('VadEvent properties and representation', () {
      const eventActive = VadEvent(
        isSpeaking: true,
        decibels: -18.5,
        audioLevel: 0.75,
      );
      expect(eventActive.isSpeaking, isTrue);
      expect(eventActive.decibels, -18.5);
      expect(eventActive.audioLevel, 0.75);
      expect(eventActive.toString(), contains('isSpeaking: true'));
      expect(eventActive.toString(), contains('dB: -18.5'));

      const eventSilence = VadEvent(
        isSpeaking: false,
        decibels: -50.0,
        audioLevel: 0.05,
      );
      expect(eventSilence.isSpeaking, isFalse);
    });

    test(
      'AudioVadService gracefully handles non-Android platform fallback',
      () async {
        final vad = AudioVadService();
        // On desktop test runner, method channel falls back to no-op
        await vad.start();
        await vad.setThreshold(-32.0);
        await vad.stop();
        vad.dispose();
      },
    );
  });

  group('Stream Configuration Tests', () {
    test('StreamSourceType definitions', () {
      expect(StreamSourceType.screen.label, 'Screen Mirroring');
    });

    test(
      'WebRTCConstants.getDisplayMediaConstraints returns correct constraints',
      () {
        final hdConstraints = WebRTCConstants.getDisplayMediaConstraints(
          preset: StreamingQualityPreset.hd720p30,
        );

        final video = hdConstraints['video'] as Map<String, dynamic>;
        final mandatory = video['mandatory'] as Map<String, dynamic>;
        expect(mandatory['maxWidth'], 720);
        expect(mandatory['maxHeight'], 1600);
        expect(mandatory['minFrameRate'], 24);
        expect(mandatory['maxFrameRate'], 30);

        final coolConstraints = WebRTCConstants.getDisplayMediaConstraints(
          preset: StreamingQualityPreset.cool540p30,
        );
        final coolVideo = coolConstraints['video'] as Map<String, dynamic>;
        final coolMandatory = coolVideo['mandatory'] as Map<String, dynamic>;
        expect(coolMandatory['maxWidth'], 540);
        expect(coolMandatory['maxHeight'], 1200);
        expect(coolMandatory['minFrameRate'], 24);
        expect(coolMandatory['maxFrameRate'], 30);
      },
    );
  });
}
