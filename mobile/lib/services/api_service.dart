import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _send(
    (requestHeaders) =>
        http.patch(_uri(path), headers: requestHeaders, body: body),
    headers: headers,
  );

  Future<http.Response> delete(String path, {Map<String, String>? headers}) =>
      _send(
        (requestHeaders) => http.delete(_uri(path), headers: requestHeaders),
        headers: headers,
      );
  Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<int>? fileBytes,
    String? fileName,
    String fileField = 'file',
  }) => _send((requestHeaders) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(requestHeaders)
      ..fields.addAll(fields);

    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
          contentType: _mediaType(fileName),
        ),
      );
    }

    return http.Response.fromStream(await request.send());
  });

  MediaType? _mediaType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'pdf' => MediaType('application', 'pdf'),
      _ => null,
    };
  }

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

    if (response.statusCode != 401) {
      return response;
    }

    final currentAccessToken = await AuthService.instance.getAccessToken();

    final newAccessToken =
        currentAccessToken != null && currentAccessToken != requestAccessToken
        ? currentAccessToken
        : await AuthService.instance.refreshAccessToken();

    if (newAccessToken == null) {
      await _handleAuthenticationFailure();
      return response;
    }

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
    if (_isHandlingAuthenticationFailure) {
      return;
    }

    _isHandlingAuthenticationFailure = true;

    try {
      await AuthService.instance.logout();
      await onAuthenticationFailed?.call();
    } finally {
      _isHandlingAuthenticationFailure = false;
    }
  }
}
