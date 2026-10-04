import 'package:flutter/material.dart';

const taskEmojis = [
  '✨',
  '📝',
  '📚',
  '💻',
  '📧',
  '📞',
  '🧹',
  '🧺',
  '🍳',
  '🥗',
  '💊',
  '💧',
  '🛒',
  '💪',
  '🚶',
  '🧘',
  '🛏️',
  '🚿',
  '🪥',
  '👕',
  '🚗',
  '🚌',
  '🏠',
  '🐶',
  '🌱',
  '🎨',
  '🎸',
  '🎮',
  '📖',
  '✍️',
  '💡',
  '🧠',
  '💼',
  '📅',
  '💰',
  '🧾',
  '🎁',
  '❤️',
  '👋',
  '☕',
  '🍎',
  '😴',
  '🎧',
  '📷',
  '🔧',
  '🧩',
  '🎯',
  '⭐',
];

/// Suggests an emoji from words in the title so new tasks look friendly
/// without an extra decision.
String suggestEmoji(String title) {
  final t = title.toLowerCase();
  const rules = <String, String>{
    'clean': '🧹',
    'tidy': '🧹',
    'laundry': '🧺',
    'wash': '🧺',
    'cook': '🍳',
    'dinner': '🍳',
    'lunch': '🥗',
    'breakfast': '☕',
    'coffee': '☕',
    'meds': '💊',
    'medic': '💊',
    'pill': '💊',
    'water': '💧',
    'shop': '🛒',
    'grocer': '🛒',
    'gym': '💪',
    'workout': '💪',
    'walk': '🚶',
    'run': '🚶',
    'yoga': '🧘',
    'meditat': '🧘',
    'sleep': '😴',
    'bed': '🛏️',
    'shower': '🚿',
    'teeth': '🪥',
    'email': '📧',
    'call': '📞',
    'phone': '📞',
    'study': '📚',
    'read': '📖',
    'write': '✍️',
    'essay': '📝',
    'homework': '📝',
    'work': '💼',
    'meeting': '📅',
    'code': '💻',
    'bill': '🧾',
    'pay': '💰',
    'budget': '💰',
    'dog': '🐶',
    'plant': '🌱',
    'music': '🎧',
    'guitar': '🎸',
    'game': '🎮',
    'draw': '🎨',
    'paint': '🎨',
    'drive': '🚗',
    'gift': '🎁',
  };
  for (final e in rules.entries) {
    if (t.contains(e.key)) return e.value;
  }
  return '✨';
}

Future<String?> pickEmoji(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          children: [
            for (final e in taskEmojis)
              InkResponse(
                onTap: () => Navigator.pop(context, e),
                child: Container(
                  alignment: Alignment.center,
                  decoration: e == current
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
