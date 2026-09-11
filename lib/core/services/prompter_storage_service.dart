import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompter_model.dart';
import '../models/saved_script_model.dart';

/// Offline local persistence service for teleprompter configuration and saved scripts.
class PrompterStorageService {
  static const String _activeConfigKey = 'offcast_prompter_active_config';
  static const String _savedScriptsKey = 'offcast_prompter_saved_scripts';

  final SharedPreferences? prefs;

  PrompterStorageService({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Persists the active live prompter configuration (script, speed, font size, mirror).
  Future<void> saveActiveConfig(PrompterConfig config) async {
    final prefs = await _getPrefs();
    await prefs.setString(_activeConfigKey, jsonEncode(config.toJson()));
  }

  /// Restores the last active prompter configuration from device storage.
  Future<PrompterConfig> loadActiveConfig() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_activeConfigKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return PrompterConfig.fromJson(decoded);
      }
    } catch (_) {
      // Fallback to default if corrupt
    }
    return const PrompterConfig();
  }

  /// Retrieves all saved scripts from the creator's offline script library.
  Future<List<SavedScript>> loadSavedScripts() async {
    try {
      final prefs = await _getPrefs();
      final listStr = prefs.getStringList(_savedScriptsKey);
      if (listStr != null) {
        final scripts = listStr.map((item) {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return SavedScript.fromJson(decoded);
        }).toList();

        // Sort descending by most recently updated
        scripts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return scripts;
      }
    } catch (_) {
      // Fallback to empty list
    }
    return [];
  }

  /// Saves or updates a script in the library.
  Future<List<SavedScript>> saveScript(SavedScript script) async {
    final prefs = await _getPrefs();
    final existing = await loadSavedScripts();
    final index = existing.indexWhere((s) => s.id == script.id);

    if (index >= 0) {
      existing[index] = script;
    } else {
      existing.insert(0, script);
    }

    final serialized = existing.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_savedScriptsKey, serialized);
    return existing;
  }

  /// Deletes a saved script from the library by its ID.
  Future<List<SavedScript>> deleteScript(String id) async {
    final prefs = await _getPrefs();
    final existing = await loadSavedScripts();
    existing.removeWhere((s) => s.id == id);

    final serialized = existing.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_savedScriptsKey, serialized);
    return existing;
  }
}
