import 'package:shared_preferences/shared_preferences.dart';
import '../../app/constants/app_constants.dart';

class SharedPrefsService {
  final SharedPreferences _prefs;

  SharedPrefsService(this._prefs);

  Future<void> setLanguage(String langCode) async {
    await _prefs.setString(AppConstants.keyLanguage, langCode);
  }

  String getLanguage() {
    return _prefs.getString(AppConstants.keyLanguage) ?? 'en';
  }

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(AppConstants.keyRememberMe, value);
  }

  bool getRememberMe() {
    return _prefs.getBool(AppConstants.keyRememberMe) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(AppConstants.keyDarkMode, value);
  }

  bool getDarkMode() {
    return _prefs.getBool(AppConstants.keyDarkMode) ?? false;
  }
}
