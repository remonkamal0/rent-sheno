import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../app/constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService() : _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.keyUserToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.keyUserToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.keyUserToken);
  }

  Future<void> saveRememberedEmail(String email) async {
    await _storage.write(key: AppConstants.keyUserEmail, value: email);
  }

  Future<String?> getRememberedEmail() async {
    return await _storage.read(key: AppConstants.keyUserEmail);
  }

  Future<void> deleteRememberedEmail() async {
    await _storage.delete(key: AppConstants.keyUserEmail);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
