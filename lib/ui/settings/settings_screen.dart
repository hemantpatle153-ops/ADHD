import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/breakdown_service.dart';
import '../../services/notification_service.dart';
import '../../state/planner_controller.dart';
import '../../state/settings_controller.dart';
import '../../util/time_format.dart';

/// Set at build time with --dart-define=PRIVACY_POLICY_URL=https://...
const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final s = controller.value;
    final breakdown = context.read<SmartBreakdown>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('Look and feel'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) =>
                  controller.update((x) => x.copyWith(themeMode: v.first)),
            ),
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text('Fewer animations, calmer screens'),
            value: s.reduceMotion,
            onChanged: (v) =>
                controller.update((x) => x.copyWith(reduceMotion: v)),
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            subtitle: const Text('Small vibrations when you finish things'),
            value: s.haptics,
            onChanged: (v) => controller.update((x) => x.copyWith(haptics: v)),
          ),
          ListTile(
            title: const Text('Your name'),
            subtitle: Text(s.name.isEmpty ? 'Not set' : s.name),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final name = await _askName(context, s.name);
              if (name != null) {
                await controller.update((x) => x.copyWith(name: name));
              }
            },
          ),
          const _Header('Your day'),
          ListTile(
            title: const Text('Timeline hours'),
            subtitle: Text(
              '${formatMinuteOfDay(context, s.dayStartHour * 60)} to '
              '${formatMinuteOfDay(context, (s.dayEndHour % 24) * 60)}',
            ),
          ),
          RangeSlider(
            values: RangeValues(
              s.dayStartHour.toDouble(),
              s.dayEndHour.toDouble(),
            ),
            min: 0,
            max: 24,
            divisions: 24,
            onChanged: (v) {
              final start = v.start.round(), end = v.end.round();
              if (end - start < 2) return;
              controller.update(
                (x) => x.copyWith(dayStartHour: start, dayEndHour: end),
              );
            },
          ),
          ListTile(
            title: const Text('Default reminder'),
            trailing: DropdownButton<int>(
              value: s.defaultReminderLead ?? -1,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: -1, child: Text('None')),
                DropdownMenuItem(value: 0, child: Text('At start')),
                DropdownMenuItem(value: 5, child: Text('5 min before')),
                DropdownMenuItem(value: 10, child: Text('10 min before')),
                DropdownMenuItem(value: 15, child: Text('15 min before')),
                DropdownMenuItem(value: 30, child: Text('30 min before')),
              ],
              onChanged: (v) => controller.update(
                (x) => x.copyWith(
                  defaultReminderLead: () => (v == null || v < 0) ? null : v,
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Allow notifications'),
            subtitle: const Text('Needed for reminders and the focus timer'),
            trailing: const Icon(Icons.notifications_active_outlined),
            onTap: () async {
              final ok = await context.read<Reminders>().requestPermission();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Notifications are on.'
                        : 'Notifications are off. You can turn them on in '
                              'your phone\'s app settings.',
                  ),
                ),
              );
            },
          ),
          const _Header('Focus'),
          ListTile(
            title: const Text('Buddy check-ins'),
            trailing: DropdownButton<int>(
              value: s.focusCheckInMinutes,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 5, child: Text('Every 5 min')),
                DropdownMenuItem(value: 10, child: Text('Every 10 min')),
                DropdownMenuItem(value: 15, child: Text('Every 15 min')),
              ],
              onChanged: (v) => controller.update(
                (x) => x.copyWith(focusCheckInMinutes: v ?? 10),
              ),
            ),
          ),
          const _Header('AI'),
          SwitchListTile(
            title: const Text('AI task breakdown'),
            subtitle: Text(
              breakdown.remote == null
                  ? 'Using built-in offline suggestions.'
                  : 'Sends only the task name and notes when you tap '
                        '"Break it down". Off means offline suggestions.',
            ),
            value: s.aiEnabled,
            onChanged: (v) {
              breakdown.aiAllowed = v;
              controller.update((x) => x.copyWith(aiEnabled: v));
            },
          ),
          const _Header('About'),
          if (privacyPolicyUrl.isNotEmpty)
            ListTile(
              title: const Text('Privacy policy'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(
                Uri.parse(privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (supportEmail.isNotEmpty)
            ListTile(
              title: const Text('Contact support'),
              subtitle: const Text(supportEmail),
              trailing: const Icon(Icons.mail_outline),
              onTap: () => launchUrl(Uri.parse('mailto:$supportEmail')),
            ),
          ListTile(
            title: const Text('Open-source licences'),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'Brightday'),
          ),
          ListTile(
            title: Text(
              'Delete all my data',
              style: TextStyle(color: scheme.error),
            ),
            subtitle: const Text('Removes every task from this phone'),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<String?> _askName(BuildContext context, String current) =>
      showDialog<String>(
        context: context,
        builder: (context) => _NameDialog(initial: current),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final planner = context.read<PlannerController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'This removes all tasks and reminders from this phone. '
          'It can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await planner.deleteEverything();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All tasks deleted.')));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog's
/// closing animation, not while the field is still on screen.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
