import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _refreshUrl = 'http://10.0.2.2:8000/api/accounts/token/refresh/';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<String?>? _refreshInProgress;

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> refreshAccessToken() {
    final currentRefresh = _refreshInProgress;
    if (currentRefresh != null) return currentRefresh;

    final refresh = _performRefresh();
    _refreshInProgress = refresh;
    return refresh.whenComplete(() => _refreshInProgress = null);
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse(_refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access'] as String?;
      if (accessToken == null || accessToken.isEmpty) return null;

      final newRefreshToken = data['refresh'] as String? ?? refreshToken;
      await saveTokens(accessToken, newRefreshToken);
      return accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
