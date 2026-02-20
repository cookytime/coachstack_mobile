import 'package:flutter/material.dart';
import 'api.dart';

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  bool _busy = false;
  String? _err;

  // sliders are doubles in Flutter
  double _mood = 7;
  double _stress = 3;
  double _soreness = 4;
  double _energy = 7;

  final _sleep = TextEditingController(text: "7.5");
  final _notes = TextEditingController();

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, "0");
    final m = now.month.toString().padLeft(2, "0");
    final d = now.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  double? _parseDouble(String s) {
    final v = double.tryParse(s.trim());
    return v;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final sleepHours = _parseDouble(_sleep.text);
      final payload = <String, dynamic>{
        "log_date": _today(),
        "mood": _mood.round(),
        "stress": _stress.round(),
        "soreness": _soreness.round(),
        "energy": _energy.round(),
        "sleep_hours": sleepHours,
        "notes": _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        "source": "flutter",
        "updated_at": DateTime.now().toUtc().toIso8601String(),
      };

      // This returns the updated dashboard from your gateway
      final dash = await Api.instance.saveDailyCheckIn(payload);

      if (!mounted) return;
      Navigator.of(context).pop(dash); // return dashboard to caller
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = "$e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _sleep.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ${value.round()}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Slider(
          value: value,
          min: 1,
          max: 10,
          divisions: 9,
          label: value.round().toString(),
          onChanged: _busy ? null : onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _today();

    return Scaffold(
      appBar: AppBar(
        title: Text("Daily Check-In ($today)"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sliderRow("Mood", _mood, (v) => setState(() => _mood = v)),
          _sliderRow("Energy", _energy, (v) => setState(() => _energy = v)),
          _sliderRow("Stress", _stress, (v) => setState(() => _stress = v)),
          _sliderRow("Soreness", _soreness, (v) => setState(() => _soreness = v)),

          const SizedBox(height: 12),
          TextField(
            controller: _sleep,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Sleep hours",
              hintText: "e.g. 7.5",
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: "Notes",
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
          ),

          const SizedBox(height: 16),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: Colors.red)),

          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Save Check-In"),
          ),
        ],
      ),
    );
  }
}