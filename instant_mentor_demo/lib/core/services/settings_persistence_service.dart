import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle persistence of user settings and preferences
class SettingsPersistenceService {
  static const String _settingsKey = 'user_settings_v1';
  static const String _preferencesKey = 'user_preferences_v1';

  /// Default settings values
  static const Map<String, dynamic> _defaultSettings = {
    'notificationsEnabled': true,
    'pushNotifications': true,
    'emailNotifications': true,
    'studyReminders': true,
    'sessionReminders': true,
    'soundEffects': true,
    'vibration': true,
    'darkMode': false,
    'language': 'English',
    'autoSync': true,
    'dataUsage': 'WiFi Only',
  };

  /// Save settings to SharedPreferences
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings);
      await prefs.setString(_settingsKey, settingsJson);
      debugPrint('💾 Settings saved to local storage: $settings');
    } catch (e) {
      debugPrint('⚠️ Failed to save settings: $e');
    }
  }

  /// Load settings from SharedPreferences
  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        debugPrint('✅ Settings loaded from local storage: $settings');
        return {..._defaultSettings, ...settings}; // Merge with defaults
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load settings: $e');
    }

    debugPrint('🔧 Using default settings');
    return Map.from(_defaultSettings);
  }

  /// Save a single setting
  static Future<void> saveSetting(String key, dynamic value) async {
    final currentSettings = await loadSettings();
    currentSettings[key] = value;
    await saveSettings(currentSettings);
  }

  /// Get a single setting with fallback to default
  static Future<T> getSetting<T>(String key, T defaultValue) async {
    final settings = await loadSettings();
    return settings[key] as T? ?? defaultValue;
  }

  /// Save user preferences (separate from UI settings)
  static Future<void> savePreferences(Map<String, dynamic> preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = json.encode(preferences);
      await prefs.setString(_preferencesKey, prefsJson);
      debugPrint('💾 Preferences saved to local storage: $preferences');
    } catch (e) {
      debugPrint('⚠️ Failed to save preferences: $e');
    }
  }

  /// Load user preferences
  static Future<Map<String, dynamic>> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString(_preferencesKey);

      if (prefsJson != null) {
        final preferences = json.decode(prefsJson) as Map<String, dynamic>;
        debugPrint('✅ Preferences loaded from local storage: $preferences');
        return preferences;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load preferences: $e');
    }

    debugPrint('🔧 Using empty preferences');
    return <String, dynamic>{};
  }

  /// Clear all settings (for logout)
  static Future<void> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
      await prefs.remove(_preferencesKey);
      debugPrint('🗑️ Settings cleared from local storage');
    } catch (e) {
      debugPrint('⚠️ Failed to clear settings: $e');
    }
  }

  /// Reset settings to defaults
  static Future<void> resetToDefaults() async {
    await saveSettings(_defaultSettings);
    await savePreferences(<String, dynamic>{});
    debugPrint('🔄 Settings reset to defaults');
  }

  /// Check if settings exist (for first-time setup)
  static Future<bool> hasSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_settingsKey);
    } catch (e) {
      debugPrint('⚠️ Failed to check settings existence: $e');
      return false;
    }
  }
}
