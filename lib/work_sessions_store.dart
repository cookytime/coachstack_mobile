import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WorkSessionsStore {
  WorkSessionsStore._();
  static final WorkSessionsStore instance = WorkSessionsStore._();

  final _storage = const FlutterSecureStorage();
  static const _sessionsKey = 'work_sessions_cache_v1';

  Future<List<Map<String, dynamic>>> readSessions() async {
    final raw = await _storage.read(key: _sessionsKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> writeSessions(List<Map<String, dynamic>> sessions) async {
    await _storage.write(key: _sessionsKey, value: jsonEncode(sessions));
  }

  Future<void> clearSessions() async {
    await _storage.delete(key: _sessionsKey);
  }
}
