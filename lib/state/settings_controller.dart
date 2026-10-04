import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../models/settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;
  AppSettings _value = const AppSettings();

  AppSettings get value => _value;

  Future<void> load() async {
    _value = await _store.load();
    notifyListeners();
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    _value = change(_value);
    notifyListeners();
    await _store.save(_value);
  }
}
