import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<void> Function()? onAuthenticationFailed;
  bool _isHandlingAuthenticationFailure = false;

  Future<http.Response> get(String path, {Map<String, String>? headers}) =>
      _send(
        (requestHeaders) => http.get(_uri(path), headers: requestHeaders),
        headers: headers,
      );

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _send(
    (requestHeaders) =>
        http.post(_uri(path), headers: requestHeaders, body: body),
    headers: headers,
  );

  Future<http.Response> patchMultipart(
    String path, {
    required Map<String, String> fields,
    List<int>? fileBytes,
    String? fileName,
    String fileField = 'avatar',
  }) => _send((requestHeaders) async {
    final request = http.MultipartRequest('PATCH', _uri(path))
      ..headers.addAll(requestHeaders)
      ..fields.addAll(fields);
    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName),
      );
    }
    return http.Response.fromStream(await request.send());
  });

  Uri _uri(String path) => Uri.parse(
    path.startsWith('http')
        ? path
        : '$baseUrl${path.startsWith('/') ? '' : '/'}$path',
  );

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    Map<String, String>? headers,
  }) async {
    final requestAccessToken = await AuthService.instance.getAccessToken();
    final response = await request(
      _authenticatedHeaders(headers, requestAccessToken),
    );
    if (response.statusCode != 401) return response;

    // Another concurrent request may already have refreshed this token.
    final currentAccessToken = await AuthService.instance.getAccessToken();
    final newAccessToken =
        currentAccessToken != null && currentAccessToken != requestAccessToken
        ? currentAccessToken
        : await AuthService.instance.refreshAccessToken();
    if (newAccessToken == null) {
      await _handleAuthenticationFailure();
      return response;
    }

    // Return the single retry directly so another refresh loop cannot start.
    final retryResponse = await request({
      ...?headers,
      'Authorization': 'Bearer $newAccessToken',
    });
    if (retryResponse.statusCode == 401) {
      await _handleAuthenticationFailure();
    }
    return retryResponse;
  }

  Map<String, String> _authenticatedHeaders(
    Map<String, String>? headers,
    String? accessToken,
  ) {
    return {
      ...?headers,
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Future<void> _handleAuthenticationFailure() async {
    if (_isHandlingAuthenticationFailure) return;
    _isHandlingAuthenticationFailure = true;
    try {
      await AuthService.instance.logout();
      await onAuthenticationFailed?.call();
    } finally {
      _isHandlingAuthenticationFailure = false;
    }
  }
}
