import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A suggested step from a breakdown, with a rough time estimate.
class SuggestedStep {
  const SuggestedStep(this.title, this.minutes);

  final String title;
  final int minutes;
}

class BreakdownResult {
  const BreakdownResult({required this.steps, required this.source});

  final List<SuggestedStep> steps;

  /// Where the steps came from, so the UI can be honest about it.
  final BreakdownSource source;

  int get totalMinutes => steps.fold(0, (sum, s) => sum + s.minutes);
}

enum BreakdownSource { ai, offline }

abstract class TaskBreakdown {
  Future<BreakdownResult> breakDown(String task, {String notes = ''});
}

/// Calls the Brightday breakdown endpoint (see `proxy/` in the repo).
///
/// The app never holds an LLM provider key. It talks to a small server that
/// holds the key, which keeps the key out of the APK and lets you rate-limit.
class RemoteBreakdown implements TaskBreakdown {
  RemoteBreakdown({
    required this.endpoint,
    this.appToken = '',
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  final Uri endpoint;
  final String appToken;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<BreakdownResult> breakDown(String task, {String notes = ''}) async {
    final response = await _client
        .post(
          endpoint,
          headers: {
            'content-type': 'application/json',
            if (appToken.isNotEmpty) 'x-app-token': appToken,
          },
          body: jsonEncode({
            'task': task,
            if (notes.isNotEmpty) 'notes': notes,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw BreakdownException('Server returned ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final rawSteps = (body is Map ? body['steps'] : null) as List?;
    if (rawSteps == null || rawSteps.isEmpty) {
      throw const BreakdownException('No steps in response');
    }
    final steps = <SuggestedStep>[];
    for (final s in rawSteps) {
      if (s is! Map) continue;
      final title = (s['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      final minutes = ((s['minutes'] as num?)?.toInt() ?? 5).clamp(1, 120);
      steps.add(SuggestedStep(title, minutes));
    }
    if (steps.isEmpty) throw const BreakdownException('No usable steps');
    return BreakdownResult(steps: steps, source: BreakdownSource.ai);
  }
}

class BreakdownException implements Exception {
  const BreakdownException(this.message);
  final String message;

  @override
  String toString() => 'BreakdownException: $message';
}

/// Works with no network: picks a template by keyword and fills in the task.
///
/// The steps follow common ADHD coaching advice: make the first step tiny and
/// physical, keep each step short, and build in a reset break.
class OfflineBreakdown implements TaskBreakdown {
  const OfflineBreakdown();

  static const _templates = <List<String>, List<(String, int)>>{
    ['clean', 'tidy', 'declutter', 'room', 'kitchen', 'dishes', 'vacuum']: [
      ('Put on a song and grab a bag or basket', 2),
      ('Throw away any obvious trash', 5),
      ('Put dishes and cups in the sink', 5),
      ('Put clothes in the laundry basket', 5),
      ('Clear one surface completely', 10),
      ('Quick wipe or vacuum the most visible spot', 10),
    ],
    ['email', 'inbox', 'reply', 'message', 'messages']: [
      ('Open the inbox and close every other tab', 1),
      ('Archive or delete anything you can in 5 minutes', 5),
      ('Star the 3 emails that actually need you', 3),
      ('Reply to the easiest one first', 5),
      ('Reply to the next starred email', 10),
      ('Reply to the last starred email', 10),
    ],
    ['study', 'exam', 'revise', 'homework', 'learn', 'read', 'chapter']: [
      ('Clear your desk and get water', 3),
      ('Open the material and pick one small section', 2),
      ('Skim the headings of that section', 5),
      ('Read or work through it for one focused block', 20),
      ('Write 3 things you remember without looking', 5),
      ('Take a 5 minute movement break', 5),
    ],
    ['write', 'essay', 'report', 'blog', 'post', 'draft', 'article']: [
      ('Open a blank doc and give it a title', 2),
      ('Brain-dump bullet points, no editing', 10),
      ('Group the bullets into 3 to 5 sections', 5),
      ('Write the messiest possible first section', 15),
      ('Draft the remaining sections roughly', 25),
      ('Read it once and fix only the obvious bits', 10),
    ],
    ['laundry', 'washing', 'clothes', 'fold']: [
      ('Carry the laundry basket to the machine', 2),
      ('Load the machine and start it', 3),
      ('Set a timer for when it finishes', 1),
      ('Move clothes to dry', 5),
      ('Fold or hang one pile while listening to something', 15),
      ('Put the folded clothes away', 5),
    ],
    ['cook', 'dinner', 'lunch', 'meal', 'breakfast', 'recipe']: [
      ('Pick what you are making', 2),
      ('Get every ingredient out on the counter', 5),
      ('Wash and chop what needs chopping', 10),
      ('Cook it', 20),
      ('Eat, then soak the pans right away', 5),
    ],
    ['gym', 'workout', 'exercise', 'run', 'walk', 'yoga']: [
      ('Put on workout clothes and shoes', 3),
      ('Fill a water bottle', 1),
      ('Warm up for 5 minutes', 5),
      ('Do the main workout', 25),
      ('Stretch and cool down', 5),
    ],
    ['shop', 'shopping', 'groceries', 'grocery', 'buy']: [
      ('Check the fridge and cupboards', 5),
      ('Write the list grouped by aisle', 5),
      ('Grab bags, wallet and keys', 2),
      ('Get to the shop', 15),
      ('Shop the list only', 20),
      ('Put everything away when you get home', 10),
    ],
    ['call', 'phone', 'appointment', 'book', 'schedule']: [
      ('Find the number or booking link', 3),
      ('Write down what you need to say or ask', 3),
      ('Make the call or fill in the form', 10),
      ('Add the result to your planner', 2),
    ],
    ['pay', 'bill', 'bills', 'tax', 'taxes', 'budget', 'invoice']: [
      ('Gather the bills or documents in one place', 5),
      ('Log in to the account you need', 3),
      ('Handle the first item', 10),
      ('Handle the rest, one at a time', 15),
      ('Note what is done and what is due next', 3),
    ],
  };

  @override
  Future<BreakdownResult> breakDown(String task, {String notes = ''}) async {
    final words = task
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    for (final entry in _templates.entries) {
      if (entry.key.any(words.contains)) {
        return BreakdownResult(
          steps: [for (final (t, m) in entry.value) SuggestedStep(t, m)],
          source: BreakdownSource.offline,
        );
      }
    }
    final name = task.trim().isEmpty ? 'the task' : '"${task.trim()}"';
    return BreakdownResult(
      steps: [
        const SuggestedStep('Get water and clear your space', 2),
        SuggestedStep('Gather everything you need for $name', 5),
        SuggestedStep('Do just the first 5 minutes of $name', 5),
        const SuggestedStep('Keep going for one focused block', 15),
        const SuggestedStep('Take a short movement break', 5),
        const SuggestedStep('Finish the last bit and check it off', 10),
      ],
      source: BreakdownSource.offline,
    );
  }
}

/// Uses the AI endpoint when it is configured and allowed, and falls back to
/// [OfflineBreakdown] whenever it is not reachable.
class SmartBreakdown implements TaskBreakdown {
  SmartBreakdown({this.remote, this.offline = const OfflineBreakdown()});

  /// Built from `--dart-define=BREAKDOWN_API_URL=...` at compile time.
  factory SmartBreakdown.fromEnvironment() {
    const url = String.fromEnvironment('BREAKDOWN_API_URL');
    const token = String.fromEnvironment('BREAKDOWN_API_TOKEN');
    final uri = url.isEmpty ? null : Uri.tryParse(url);
    return SmartBreakdown(
      remote: uri == null
          ? null
          : RemoteBreakdown(endpoint: uri, appToken: token),
    );
  }

  final TaskBreakdown? remote;
  final TaskBreakdown offline;

  /// Toggled from settings when the user opts out of AI.
  bool aiAllowed = true;

  bool get aiAvailable => remote != null && aiAllowed;

  @override
  Future<BreakdownResult> breakDown(String task, {String notes = ''}) async {
    if (aiAvailable) {
      try {
        return await remote!.breakDown(task, notes: notes);
      } catch (_) {
        // Fall through to offline steps; the UI labels the source.
      }
    }
    return offline.breakDown(task, notes: notes);
  }
}
