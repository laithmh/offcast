import 'package:flutter_test/flutter_test.dart';
import 'package:hotspot_screen_sharing/core/models/prompter_model.dart';
import 'package:hotspot_screen_sharing/core/models/saved_script_model.dart';
import 'package:hotspot_screen_sharing/core/services/prompter_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PrompterStorageService Tests', () {
    late PrompterStorageService storageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storageService = PrompterStorageService();
    });

    test('loadActiveConfig returns default config on empty storage', () async {
      final config = await storageService.loadActiveConfig();
      expect(config.scriptText, contains('Welcome to the live studio broadcast'));
      expect(config.scrollSpeedWpm, 140.0);
      expect(config.fontSize, 32.0);
      expect(config.isMirrored, isFalse);
    });

    test('saveActiveConfig and loadActiveConfig round-trips correctly', () async {
      const customConfig = PrompterConfig(
        scriptText: 'Welcome to today’s tech review!',
        scrollSpeedWpm: 180.0,
        fontSize: 40.0,
        isMirrored: true,
      );

      await storageService.saveActiveConfig(customConfig);
      final restored = await storageService.loadActiveConfig();

      expect(restored.scriptText, 'Welcome to today’s tech review!');
      expect(restored.scrollSpeedWpm, 180.0);
      expect(restored.fontSize, 40.0);
      expect(restored.isMirrored, isTrue);
    });

    test('saveScript, loadSavedScripts, and deleteScript work correctly', () async {
      final initialList = await storageService.loadSavedScripts();
      expect(initialList, isEmpty);

      final script1 = SavedScript(
        id: 'script_1',
        title: 'Intro Segment',
        content: 'Hey guys, welcome back to the channel!',
        scrollSpeedWpm: 150.0,
        fontSize: 34.0,
        updatedAt: DateTime(2026, 9, 11, 10, 0),
      );

      final script2 = SavedScript(
        id: 'script_2',
        title: 'Outro Segment',
        content: 'Don’t forget to like and subscribe!',
        scrollSpeedWpm: 130.0,
        fontSize: 36.0,
        updatedAt: DateTime(2026, 9, 11, 11, 0),
      );

      await storageService.saveScript(script1);
      await storageService.saveScript(script2);

      final saved = await storageService.loadSavedScripts();
      expect(saved.length, 2);
      // script2 has later timestamp so should be first
      expect(saved[0].title, 'Outro Segment');
      expect(saved[1].title, 'Intro Segment');

      // Update script 1
      final updatedScript1 = script1.copyWith(
        title: 'Updated Intro',
        content: 'Brand new intro text!',
      );
      await storageService.saveScript(updatedScript1);
      final updatedList = await storageService.loadSavedScripts();
      expect(updatedList.length, 2);
      expect(updatedList.any((s) => s.title == 'Updated Intro'), isTrue);

      // Delete script 2
      await storageService.deleteScript('script_2');
      final afterDelete = await storageService.loadSavedScripts();
      expect(afterDelete.length, 1);
      expect(afterDelete[0].id, 'script_1');
    });
  });
}
