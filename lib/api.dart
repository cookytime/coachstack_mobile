import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

class Api {
  Api._();
  static final Api instance = Api._();

  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() => _storage.read(key: 'access_token');
  Future<void> setToken(String token) =>
      _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() => _storage.delete(key: 'access_token');

  Uri _u(String path, [Map<String, String>? qs]) {
    final base = Uri.parse(Config.apiBaseUrl);
    return Uri.parse(
      '${base.toString().replaceAll(RegExp(r'/$'), '')}$path',
    ).replace(queryParameters: qs);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
  }) async {
    final token = await getToken();

    final headers = <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      ...?extraHeaders,
    };

    final res = await http.post(
      _u(path),
      headers: headers,
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data as Map).cast<String, dynamic>();
    }

    throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? qs,
  }) async {
    final token = await getToken();

    final headers = <String, String>{
      if (token != null) 'authorization': 'Bearer $token',
    };

    final res = await http.get(_u(path, qs), headers: headers);
    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data as Map).cast<String, dynamic>();
    }

    throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
  }

  // ---- Auth ----

  Future<void> startMagicLink(String email) async {
    await postJson('/auth/start', {'email': email});
  }

  Future<void> verifyMagicToken(String token) async {
    final res = await postJson('/auth/verify', {'token': token});
    final accessToken = res['access_token'];
    if (accessToken == null) throw Exception('Missing access_token');
    await setToken(accessToken);
  }

  Future<void> devToken(String email, String devSecret) async {
    final res = await postJson(
      '/dev/token',
      {'email': email},
      extraHeaders: {'x-dev-token-secret': devSecret},
    );
    final accessToken = res['access_token'];
    if (accessToken == null) throw Exception('Missing access_token');
    await setToken(accessToken);
  }

  // ---- Dashboard ----

  Future<Map<String, dynamic>> dashboard({int days = 14}) async {
    return await getJson('/dashboard', qs: {'days': '$days'});
  }

  Future<Map<String, dynamic>> saveDailyCheckIn(
    Map<String, dynamic> payload,
  ) async {
    return await postJson('/daily-checkin', payload);
  }

  Future<Map<String, dynamic>> saveProgressLog(
    Map<String, dynamic> payload,
  ) async {
    return await postJson('/progress-log', payload);
  }

  Future<List<Map<String, dynamic>>> syncSessions({int days = 7}) async {
    final res = await postJson('/sessions/sync', {'days': days});

    if (res['sync_results'] is List) {
      final syncResults = (res['sync_results'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return syncResults
          .map((item) => item['result'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (res['sessions'] is List) {
      return (res['sessions'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const [];
  }

  Future<List<Map<String, dynamic>>> recentSessions({int days = 7}) async {
    final res = await getJson('/session/recent', qs: {'days': '$days'});
    final sessions = res['sessions'];
    if (sessions is List) {
      return sessions
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
