import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'work_sessions_store.dart';

class WorkSessionsPage extends StatefulWidget {
  const WorkSessionsPage({super.key});

  @override
  State<WorkSessionsPage> createState() => _WorkSessionsPageState();
}

class _WorkSessionsPageState extends State<WorkSessionsPage> {
  final _store = WorkSessionsStore.instance;

  bool _loading = true;
  bool _syncing = false;
  String? _err;
  List<Map<String, dynamic>> _sessions = [];
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _loadLocalThenSync();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalThenSync() async {
    try {
      final local = await _store.readSessions();
      if (!mounted) return;
      setState(() {
        _sessions = _sortedSessions(local);
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = '$e';
      });
    }

    await _syncSessions();
  }

  Future<void> _syncSessions() async {
    setState(() {
      _syncing = true;
      _err = null;
    });

    try {
      var synced = await Api.instance.syncSessions(days: 7);
      if (synced.isEmpty) {
        synced = await Api.instance.recentSessions(days: 7);
      }

      if (!mounted) return;
      setState(() {
        _sessions = _sortedSessions(synced);
        _syncing = false;
      });
      await _store.writeSessions(_sessions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _err = '$e';
      });
    }
  }

  List<Map<String, dynamic>> _sortedSessions(List<Map<String, dynamic>> input) {
    final copy = input.map((e) => Map<String, dynamic>.from(e)).toList();
    copy.sort((a, b) {
      final aDate = DateTime.tryParse((a['scheduled_date'] ?? '').toString());
      final bDate = DateTime.tryParse((b['scheduled_date'] ?? '').toString());
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return copy;
  }

  void _scheduleLocalSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _store.writeSessions(_sessions);
    });
  }

  List<Map<String, dynamic>> _exerciseLogs(Map<String, dynamic> session) {
    final raw = session['exercise_logs'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _sets(Map<String, dynamic> exercise) {
    final raw = exercise['sets'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _ensureExerciseLogsRef(int sessionIndex) {
    final current = _sessions[sessionIndex]['exercise_logs'];
    if (current is List) {
      _sessions[sessionIndex]['exercise_logs'] = current
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return;
    }
    _sessions[sessionIndex]['exercise_logs'] = <Map<String, dynamic>>[];
  }

  void _addSet(int sessionIndex, int exerciseIndex) {
    setState(() {
      _ensureExerciseLogsRef(sessionIndex);
      final logs = (_sessions[sessionIndex]['exercise_logs'] as List)
          .cast<Map<String, dynamic>>();
      final exercise = logs[exerciseIndex];
      final sets = _sets(exercise);
      sets.add({'weight': null, 'reps': 0, 'completed': false});
      exercise['sets'] = sets;
    });
    _scheduleLocalSave();
  }

  void _removeSet(int sessionIndex, int exerciseIndex, int setIndex) {
    setState(() {
      final logs = (_sessions[sessionIndex]['exercise_logs'] as List)
          .cast<Map<String, dynamic>>();
      final exercise = logs[exerciseIndex];
      final sets = _sets(exercise);
      if (setIndex >= 0 && setIndex < sets.length) {
        sets.removeAt(setIndex);
      }
      exercise['sets'] = sets;
    });
    _scheduleLocalSave();
  }

  void _updateSetField(
    int sessionIndex,
    int exerciseIndex,
    int setIndex,
    String field,
    Object? value,
  ) {
    final logs = (_sessions[sessionIndex]['exercise_logs'] as List)
        .cast<Map<String, dynamic>>();
    final exercise = logs[exerciseIndex];
    final sets = _sets(exercise);
    if (setIndex < 0 || setIndex >= sets.length) return;
    sets[setIndex][field] = value;
    exercise['sets'] = sets;
    _scheduleLocalSave();
  }

  void _updateFeedback(int sessionIndex, int exerciseIndex, String feedback) {
    setState(() {
      final logs = (_sessions[sessionIndex]['exercise_logs'] as List)
          .cast<Map<String, dynamic>>();
      logs[exerciseIndex]['client_feedback'] = feedback;
    });
    _scheduleLocalSave();
  }

  void _updateNotes(int sessionIndex, int exerciseIndex, String notes) {
    final logs = (_sessions[sessionIndex]['exercise_logs'] as List)
        .cast<Map<String, dynamic>>();
    logs[exerciseIndex]['notes'] = notes;
    _scheduleLocalSave();
  }

  String _sessionTitle(Map<String, dynamic> session) {
    return (session['program_name'] ?? session['client_name'] ?? 'Work Session')
        .toString();
  }

  String _sessionSubtitle(Map<String, dynamic> session) {
    final client = (session['client_name'] ?? '').toString();
    final dateRaw = (session['scheduled_date'] ?? '').toString();
    final dt = DateTime.tryParse(dateRaw);
    final when = dt == null
        ? dateRaw
        : '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (client.isEmpty) return when;
    return '$client • $when';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Sessions (Next 7 Days)'),
        actions: [
          IconButton(
            onPressed: _syncing ? null : _syncSessions,
            icon: _syncing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncSessions,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_err!, style: const TextStyle(color: Colors.red)),
              ),
            if (_sessions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sessions cached yet.'),
                ),
              )
            else
              ...List.generate(_sessions.length, (sessionIndex) {
                final session = _sessions[sessionIndex];
                final exercises = _exerciseLogs(session);
                final status = (session['status'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _sessionTitle(session),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_sessionSubtitle(session)),
                                ],
                              ),
                            ),
                            if (status.isNotEmpty)
                              Chip(label: Text(status.toLowerCase())),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(exercises.length, (exerciseIndex) {
                          final exercise = exercises[exerciseIndex];
                          final sets = _sets(exercise);
                          final feedback = (exercise['client_feedback'] ?? '')
                              .toString();

                          return Card(
                            color: Colors.grey.shade50,
                            margin: const EdgeInsets.only(top: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (exercise['exercise_name'] ??
                                                  'Exercise')
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _addSet(
                                          sessionIndex,
                                          exerciseIndex,
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Set'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(sets.length, (setIndex) {
                                    final set = sets[setIndex];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 26,
                                            child: Text('${setIndex + 1}'),
                                          ),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue:
                                                  (set['weight'] ?? '')
                                                      .toString(),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                labelText: 'Weight',
                                                isDense: true,
                                              ),
                                              onChanged: (v) => _updateSetField(
                                                sessionIndex,
                                                exerciseIndex,
                                                setIndex,
                                                'weight',
                                                double.tryParse(v.trim()),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: (set['reps'] ?? 0)
                                                  .toString(),
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Reps',
                                                isDense: true,
                                              ),
                                              onChanged: (v) => _updateSetField(
                                                sessionIndex,
                                                exerciseIndex,
                                                setIndex,
                                                'reps',
                                                int.tryParse(v.trim()) ?? 0,
                                              ),
                                            ),
                                          ),
                                          Checkbox(
                                            value:
                                                (set['completed'] ?? false) ==
                                                true,
                                            onChanged: (val) {
                                              setState(() {
                                                _updateSetField(
                                                  sessionIndex,
                                                  exerciseIndex,
                                                  setIndex,
                                                  'completed',
                                                  val == true,
                                                );
                                              });
                                            },
                                          ),
                                          IconButton(
                                            onPressed: () => _removeSet(
                                              sessionIndex,
                                              exerciseIndex,
                                              setIndex,
                                            ),
                                            icon: const Icon(Icons.close),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 6),
                                  const Text('How did it feel?'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children:
                                        ['Easy', 'Moderate', 'Hard', 'Failed']
                                            .map(
                                              (option) => ChoiceChip(
                                                label: Text(option),
                                                selected: feedback == option,
                                                onSelected: (_) =>
                                                    _updateFeedback(
                                                      sessionIndex,
                                                      exerciseIndex,
                                                      option,
                                                    ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: (exercise['notes'] ?? '')
                                        .toString(),
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => _updateNotes(
                                      sessionIndex,
                                      exerciseIndex,
                                      v,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
