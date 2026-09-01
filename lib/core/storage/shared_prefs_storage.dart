import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage.dart';

class SharedPrefsStorage implements LocalStorage {
  SharedPrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<void> write<T>(String key, T value) async {
    switch (value) {
      case final String stringValue:
        await _prefs.setString(key, stringValue);
      case final bool boolValue:
        await _prefs.setBool(key, boolValue);
      case final int intValue:
        await _prefs.setInt(key, intValue);
      case final double doubleValue:
        await _prefs.setDouble(key, doubleValue);
      default:
        await _prefs.setString(key, value.toString());
    }
  }

  @override
  T? read<T>(String key) {
    final value = _prefs.get(key);
    if (value is T) {
      return value;
    }
    return null;
  }

  @override
  Future<void> delete(String key) {
    return _prefs.remove(key);
  }

  @override
  Future<void> clear() {
    return _prefs.clear();
  }
}
