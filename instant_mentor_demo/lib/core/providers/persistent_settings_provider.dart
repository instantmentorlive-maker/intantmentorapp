import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_persistence_service.dart';

/// Persistent settings provider using SharedPreferences
class PersistentSettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  PersistentSettingsNotifier() : super({}) {
    _loadSettings();
  }

  /// Load settings from persistence
  Future<void> _loadSettings() async {
    final settings = await SettingsPersistenceService.loadSettings();
    state = settings;
  }

  /// Update a single setting and persist it
  Future<void> updateSetting(String key, dynamic value) async {
    state = {...state, key: value};
    await SettingsPersistenceService.saveSetting(key, value);
  }

  /// Update multiple settings and persist them
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    state = {...state, ...newSettings};
    await SettingsPersistenceService.saveSettings(state);
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    await SettingsPersistenceService.resetToDefaults();
    await _loadSettings();
  }

  /// Get a specific setting with type safety
  T getSetting<T>(String key, T defaultValue) {
    return state[key] as T? ?? defaultValue;
  }
}

/// Provider for persistent settings
final persistentSettingsProvider =
    StateNotifierProvider<PersistentSettingsNotifier, Map<String, dynamic>>(
        (ref) {
  return PersistentSettingsNotifier();
});

/// Individual setting providers that persist automatically
final notificationsEnabledProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('notificationsEnabled', true, ref);
});

final pushNotificationsProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('pushNotifications', true, ref);
});

final emailNotificationsProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('emailNotifications', true, ref);
});

final studyRemindersProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('studyReminders', true, ref);
});

final sessionRemindersProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('sessionReminders', true, ref);
});

final soundEffectsProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('soundEffects', true, ref);
});

final vibrationProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('vibration', true, ref);
});

final darkModeProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('darkMode', false, ref);
});

final languageProvider =
    StateNotifierProvider<_SettingNotifier<String>, String>((ref) {
  return _SettingNotifier<String>('language', 'English', ref);
});

final autoSyncProvider =
    StateNotifierProvider<_SettingNotifier<bool>, bool>((ref) {
  return _SettingNotifier<bool>('autoSync', true, ref);
});

final dataUsageProvider =
    StateNotifierProvider<_SettingNotifier<String>, String>((ref) {
  return _SettingNotifier<String>('dataUsage', 'WiFi Only', ref);
});

/// Private helper class for individual settings
class _SettingNotifier<T> extends StateNotifier<T> {
  final String _key;
  final T _defaultValue;
  final Ref _ref;

  _SettingNotifier(this._key, this._defaultValue, this._ref)
      : super(_defaultValue) {
    _loadFromPersistence();
  }

  Future<void> _loadFromPersistence() async {
    final value =
        await SettingsPersistenceService.getSetting<T>(_key, _defaultValue);
    state = value;
  }

  @override
  set state(T value) {
    super.state = value;
    _saveToPersistence(value);
    // Also update the main settings provider
    _ref.read(persistentSettingsProvider.notifier).updateSetting(_key, value);
  }

  Future<void> _saveToPersistence(T value) async {
    await SettingsPersistenceService.saveSetting(_key, value);
  }
}
