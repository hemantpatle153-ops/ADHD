import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _theme = 'themeMode';
  static const _onboarding = 'onboardingDone';
  static const _dayStart = 'dayStartHour';
  static const _dayEnd = 'dayEndHour';
  static const _reminder = 'defaultReminderLead';
  static const _checkIn = 'focusCheckInMinutes';
  static const _reduceMotion = 'reduceMotion';
  static const _haptics = 'haptics';
  static const _ai = 'aiEnabled';
  static const _name = 'name';

  @override
  Future<AppSettings> load() async {
    const d = AppSettings();
    final theme = await _prefs.getString(_theme);
    final reminder = await _prefs.getInt(_reminder);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => d.themeMode,
      ),
      onboardingDone: await _prefs.getBool(_onboarding) ?? d.onboardingDone,
      dayStartHour: await _prefs.getInt(_dayStart) ?? d.dayStartHour,
      dayEndHour: await _prefs.getInt(_dayEnd) ?? d.dayEndHour,
      // -1 encodes "no reminder" so it survives a round trip.
      defaultReminderLead: reminder == null
          ? d.defaultReminderLead
          : (reminder < 0 ? null : reminder),
      focusCheckInMinutes:
          await _prefs.getInt(_checkIn) ?? d.focusCheckInMinutes,
      reduceMotion: await _prefs.getBool(_reduceMotion) ?? d.reduceMotion,
      haptics: await _prefs.getBool(_haptics) ?? d.haptics,
      aiEnabled: await _prefs.getBool(_ai) ?? d.aiEnabled,
      name: await _prefs.getString(_name) ?? d.name,
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    await Future.wait([
      _prefs.setString(_theme, s.themeMode.name),
      _prefs.setBool(_onboarding, s.onboardingDone),
      _prefs.setInt(_dayStart, s.dayStartHour),
      _prefs.setInt(_dayEnd, s.dayEndHour),
      _prefs.setInt(_reminder, s.defaultReminderLead ?? -1),
      _prefs.setInt(_checkIn, s.focusCheckInMinutes),
      _prefs.setBool(_reduceMotion, s.reduceMotion),
      _prefs.setBool(_haptics, s.haptics),
      _prefs.setBool(_ai, s.aiEnabled),
      _prefs.setString(_name, s.name),
    ]);
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.value = const AppSettings()]);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}
