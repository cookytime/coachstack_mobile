import 'package:flutter/material.dart';
import 'auth.dart';

void main() {
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
  }

  Future<void> _boot() async {
    try {
      final token = await Api.instance.getToken();
      setState(() {
        _authed = token != null && token.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

  Future<void> _start() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await Api.instance.startMagicLink(_email.text.trim());
      setState(() => _msg = 'Magic link sent. Paste token from link below and verify.');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await Api.instance.verifyMagicToken(_token.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardPage()));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _devLogin() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await Api.instance.devToken(_email.text.trim(), _devSecret.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardPage()));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    } finally {
      setState(() => _busy = false);
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
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),

            // DEV shortcut
            TextField(
              controller: _devSecret,
              decoration: const InputDecoration(labelText: 'Dev Secret (optional)'),
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
              decoration: const InputDecoration(labelText: 'Paste magic token (ml_...)'),
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
    setState(() { _busy = true; _err = null; });
    try {
      final d = await Api.instance.dashboard(days: 14);
      setState(() { _dash = d; _busy = false; });
    } catch (e) {
      setState(() { _err = '$e'; _busy = false; });
    }
  }

  Future<void> _logout() async {
    await Api.instance.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Center(child: Text(_err!)),
      );
    }

    final client = _dash?['client'] as Map<String, dynamic>? ?? {};
    final today = _dash?['today'] ?? '';
    final todayData = _dash?['today_data'] as Map<String, dynamic>? ?? {};
    final last = _dash?['last_n_days'] as Map<String, dynamic>? ?? {};
    final daily = (last['daily_checkins'] as List?) ?? const [];
    final prog = (last['progress_logs'] as List?) ?? const [];

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
        child: ListView(
          children: [
            Text('Today: $today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Daily check-in today: ${todayData['daily_checkin'] != null ? '✅' : '—'}'),
            Text('Progress log today: ${todayData['progress_log'] != null ? '✅' : '—'}'),
            const SizedBox(height: 16),

            Text('Last 14 days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Daily check-ins: ${daily.length}'),
            Text('Progress logs: ${prog.length}'),
          ],
        ),
      ),
    );
  }
}
