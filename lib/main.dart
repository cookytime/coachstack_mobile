import 'package:flutter/material.dart';
import 'deep_link_handler.dart';
import 'api.dart';
import 'daily_checkin_page.dart';
import 'progress_log_page.dart';
import 'work_sessions_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoachStackApp());
}

class CoachStackApp extends StatelessWidget {
  const CoachStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoachStack',
      theme: ThemeData(useMaterial3: true),
      home: const BootstrapPage(),
    );
  }
}

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  bool _loading = true;
  bool _authed = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _boot();

    DeepLinkHandler.instance.start(
      onAuthed: () async {
        debugPrint('onAuthed fired -> refreshing auth state');
        await _boot(); // re-read token and flip _authed
        // Optional: also force navigation (not required if you use the _authed switch)
        if (!mounted) return;
        setState(() {}); // ensures rebuild
      },
      onError: (err) {
        debugPrint('Deep link auth error: $err');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $err')));
      },
    );
  }

  Future<void> _boot() async {
    try {
      final token = await Api.instance.getToken();
      if (!mounted) return;
      setState(() {
        _authed = token != null && token.isNotEmpty;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_err != null) return Scaffold(body: Center(child: Text(_err!)));
    return _authed ? const DashboardPage() : const LoginPage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'test@glencook.net');
  final _token = TextEditingController();
  final _devSecret = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _devSecret.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await Api.instance.startMagicLink(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _msg = 'Magic link sent. Paste token from link below and verify.';
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = 'Error: $e';
        _busy = false;
      });
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await Api.instance.verifyMagicToken(_token.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = 'Error: $e';
        _busy = false;
      });
    }
  }

  Future<void> _devLogin() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await Api.instance.devToken(_email.text.trim(), _devSecret.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = 'Error: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CoachStack Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),

            // DEV shortcut
            TextField(
              controller: _devSecret,
              decoration: const InputDecoration(
                labelText: 'Dev Secret (optional)',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _devLogin,
                    child: const Text('Dev Login'),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _start,
                    child: const Text('Send Magic Link'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Paste magic token (ml_...)',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _verify,
                    child: const Text('Verify Token'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_msg != null) Text(_msg!, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _busy = true;
  Map<String, dynamic>? _dash;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final d = await Api.instance.dashboard(days: 14);
      if (!mounted) return;
      setState(() {
        _dash = d;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _logout() async {
    await Api.instance.clearToken();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _openDailyCheckIn() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DailyCheckInPage()));
    if (!mounted) return;
    _applyWriteResult(result);
  }

  Future<void> _openProgressLog() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProgressLogPage()));
    if (!mounted) return;
    _applyWriteResult(result);
  }

  Future<void> _openWorkSessions() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WorkSessionsPage()));
  }

  void _applyWriteResult(Object? result) {
    if (result is Map<String, dynamic>) {
      setState(() {
        _dash = result;
        _err = null;
        _busy = false;
      });
      return;
    }
    _load();
  }

  List<Map<String, dynamic>> _extractWorkoutSchedules(
    Map<String, dynamic> dash,
    Map<String, dynamic> todayData,
    Map<String, dynamic> last,
  ) {
    final candidates = [
      dash['workout_schedules'],
      dash['workout_schedule'],
      dash['schedules'],
      todayData['workout_schedules'],
      todayData['workout_schedule'],
      last['workout_schedules'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (candidate is Map) {
        return [Map<String, dynamic>.from(candidate)];
      }
    }
    return const [];
  }

  String _schedulePrimaryLabel(Map<String, dynamic> item) {
    final title =
        item['title'] ??
        item['name'] ??
        item['session_name'] ??
        item['workout_name'];
    return (title ?? 'Workout').toString();
  }

  String _scheduleSecondaryLabel(Map<String, dynamic> item) {
    final date =
        item['scheduled_date'] ??
        item['date'] ??
        item['day'] ??
        item['log_date'] ??
        '';
    final focus = item['focus'] ?? item['type'] ?? item['category'] ?? '';
    if (date.toString().isEmpty && focus.toString().isEmpty) {
      return 'No details';
    }
    if (date.toString().isEmpty) return focus.toString();
    if (focus.toString().isEmpty) return date.toString();
    return '$date • $focus';
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Center(child: Text(_err!)),
      );
    }

    final dash = _dash ?? const <String, dynamic>{};
    final client = dash['client'] as Map<String, dynamic>? ?? {};
    final today = _dash?['today'] ?? '';
    final todayData = _dash?['today_data'] as Map<String, dynamic>? ?? {};
    final last = _dash?['last_n_days'] as Map<String, dynamic>? ?? {};
    final daily = (last['daily_checkins'] as List?) ?? const [];
    final prog = (last['progress_logs'] as List?) ?? const [];
    final schedules = _extractWorkoutSchedules(dash, todayData, last);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard (${client['name'] ?? ''})'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Today: $today',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Daily check-in today: ${todayData['daily_checkin'] != null ? '✅' : '—'}',
              ),
              Text(
                'Progress log today: ${todayData['progress_log'] != null ? '✅' : '—'}',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: todayData['daily_checkin'] != null
                      ? null
                      : _openDailyCheckIn,
                  child: Text(
                    todayData['daily_checkin'] != null
                        ? 'Daily Check-In Logged ✅'
                        : 'Log Daily Check-In',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: todayData['progress_log'] != null
                      ? null
                      : _openProgressLog,
                  child: Text(
                    todayData['progress_log'] != null
                        ? 'Progress Logged ✅'
                        : 'Log Progress',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openWorkSessions,
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Open Work Sessions'),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Last 14 days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Daily check-ins: ${daily.length}'),
              Text('Progress logs: ${prog.length}'),
              const SizedBox(height: 24),
              Text(
                'Workout Schedule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (schedules.isEmpty)
                const Text('No scheduled workouts found in dashboard data.')
              else
                ...schedules.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text(_schedulePrimaryLabel(item)),
                      subtitle: Text(_scheduleSecondaryLabel(item)),
                      trailing: item['status'] != null
                          ? Text(item['status'].toString())
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
