import 'package:shared_preferences/shared_preferences.dart';

import 'Keys.dart';

class AppPrefs {
  static AppPrefs? _gcPrefrence;
  static SharedPreferences? _prefrence;

  AppPrefs._internal();

  static AppPrefs? getInstance() {
    if (_gcPrefrence == null || _prefrence == null) {
      _init();
      _gcPrefrence = AppPrefs._internal();
    }
    return _gcPrefrence;
  }

  static Future _init() async {
    _prefrence = await SharedPreferences.getInstance();
  }

  checkLogin() {
    return _prefrence?.getBool(Keys.IS_LOGIN) ?? false;
  }

  setLogin() {
    _prefrence!.setBool(Keys.IS_LOGIN, true);
  }

  setLogout(bool isClear) {
    isClear ? _prefrence!.clear() : _prefrence!.setBool(Keys.IS_LOGIN, false);
  }

  setStringData(String key, String? stringData) {
    _prefrence!.setString(key, stringData!);
  }

  getStringData(String key) {
    return _prefrence!.getString(key) ?? "";
  }

  setIntData(String key, int value) {
    _prefrence!.setInt(key, value);
  }

  getIntData(String key) {
    return _prefrence!.getInt(key) ?? 0;
  }

  setBoolData(String key, bool value) {
    _prefrence!.setBool(key, value);
  }

  getBoolData(String key) {
    return _prefrence!.getBool(key) ?? false;
  }

  setDoubleData(String key, double value) {
    _prefrence!.setDouble(key, value);
  }

  getDoubleData(String key) {
    return _prefrence!.getDouble(key) ?? 0.0;
  }
}
