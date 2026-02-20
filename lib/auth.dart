import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

class Api {
  Api._();
  static final Api instance = Api._();

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  static const _timeout = Duration(seconds: 15);

  // Cache the parsed base URL so we don't re-parse on every request.
  static final _baseUri = Uri.parse(
    Config.apiBaseUrl.replaceAll(RegExp(r'/$'), ''),
  );

  Future<String?> getToken() => _storage.read(key: 'access_token');
  Future<void> setToken(String token) => _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() => _storage.delete(key: 'access_token');

  Uri _u(String path, [Map<String, String>? qs]) {
    return Uri.parse('$_baseUri$path').replace(queryParameters: qs);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {Map<String, String>? extraHeaders}) async {
    final token = await getToken();
    final headers = <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      ...?extraHeaders,
    };

    final res = await _client
        .post(_u(path), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    final text = res.body;
    final data = text.isNotEmpty ? jsonDecode(text) : null;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data as Map).cast<String, dynamic>();
    }
    throw Exception((data is Map && data['error'] != null) ? data['error'] : 'HTTP ${res.statusCode}: $text');
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? qs}) async {
    final token = await getToken();
    final headers = <String, String>{
      if (token != null) 'authorization': 'Bearer $token',
    };

    final res = await _client
        .get(_u(path, qs), headers: headers)
        .timeout(_timeout);
    final text = res.body;
    final data = text.isNotEmpty ? jsonDecode(text) : null;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data as Map).cast<String, dynamic>();
    }
    throw Exception((data is Map && data['error'] != null) ? data['error'] : 'HTTP ${res.statusCode}: $text');
  }

  // ---- Auth ----
  Future<void> startMagicLink(String email) async {
    await postJson('/auth/start', {'email': email});
  }

  Future<void> verifyMagicToken(String token) async {
    final res = await postJson('/auth/verify', {'token': token});
    final accessToken = res['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) throw Exception('Missing access_token');
    await setToken(accessToken);
  }

  // DEV shortcut (Hoppscotch-style)
  Future<void> devToken(String email, String devSecret) async {
    final res = await postJson(
      '/dev/token',
      {'email': email},
      extraHeaders: {'x-dev-token-secret': devSecret},
    );
    final accessToken = res['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) throw Exception('Missing access_token');
    await setToken(accessToken);
  }

  // ---- Dashboard ----
  Future<Map<String, dynamic>> dashboard({int days = 14}) async {
    return await getJson('/dashboard', qs: {'days': '$days'});
  }

  // Writes return dashboard (your gateway now does this)
  Future<Map<String, dynamic>> saveDailyCheckIn(Map<String, dynamic> payload) async {
    return await postJson('/daily-checkin', payload);
  }

  Future<Map<String, dynamic>> saveProgressLog(Map<String, dynamic> payload) async {
    return await postJson('/progress-log', payload);
  }
}
