import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentials {
  const SavedCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

/// Persists login email/password in secure storage when "Remember me" is on.
class SavedCredentialsStore {
  static const _emailKey = 'remembered_email';
  static const _passwordKey = 'remembered_password';
  static const _enabledKey = 'remember_me_enabled';

  final FlutterSecureStorage _storage;

  SavedCredentialsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> isRememberEnabled() async {
    final raw = await _storage.read(key: _enabledKey);
    return raw == 'true';
  }

  Future<SavedCredentials?> load() async {
    if (!await isRememberEnabled()) return null;
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || email.isEmpty || password == null) return null;
    return SavedCredentials(email: email, password: password);
  }

  Future<void> save({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.write(key: _enabledKey, value: 'false');
  }
}
