import 'package:flutter/material.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.onboardingDone = false,
    this.dayStartHour = 7,
    this.dayEndHour = 22,
    this.defaultReminderLead = 5,
    this.focusCheckInMinutes = 10,
    this.reduceMotion = false,
    this.haptics = true,
    this.aiEnabled = true,
    this.name = '',
  });

  final ThemeMode themeMode;
  final bool onboardingDone;

  /// Visible hours on the timeline.
  final int dayStartHour;
  final int dayEndHour;

  /// Default reminder lead for new scheduled tasks (minutes). Null = none.
  final int? defaultReminderLead;

  /// How often the focus companion checks in. 0 disables check-ins.
  final int focusCheckInMinutes;
  final bool reduceMotion;
  final bool haptics;

  /// Lets the user opt out of sending task titles to the AI service.
  final bool aiEnabled;
  final String name;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? onboardingDone,
    int? dayStartHour,
    int? dayEndHour,
    int? Function()? defaultReminderLead,
    int? focusCheckInMinutes,
    bool? reduceMotion,
    bool? haptics,
    bool? aiEnabled,
    String? name,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      dayEndHour: dayEndHour ?? this.dayEndHour,
      defaultReminderLead: defaultReminderLead != null
          ? defaultReminderLead()
          : this.defaultReminderLead,
      focusCheckInMinutes: focusCheckInMinutes ?? this.focusCheckInMinutes,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      haptics: haptics ?? this.haptics,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      name: name ?? this.name,
    );
  }
}
