import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/breakdown_service.dart';
import 'services/notification_service.dart';
import 'state/planner_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';

class BrightdayApp extends StatelessWidget {
  const BrightdayApp({
    super.key,
    required this.planner,
    required this.settings,
    required this.breakdown,
    required this.reminders,
  });

  final PlannerController planner;
  final SettingsController settings;
  final SmartBreakdown breakdown;
  final Reminders reminders;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: planner),
        ChangeNotifierProvider.value(value: settings),
        Provider<SmartBreakdown>.value(value: breakdown),
        Provider<Reminders>.value(value: reminders),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) {
          final reduceMotion = s.value.reduceMotion;
          return MaterialApp(
            title: 'Brightday',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: s.value.themeMode,
            builder: (context, child) {
              if (!reduceMotion) return child!;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              );
            },
            home: s.value.onboardingDone
                ? const HomeScreen()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

/// True when animations should be skipped (system setting or in-app toggle).
bool motionReduced(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;
