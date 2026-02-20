import 'package:flutter/material.dart';
import 'api.dart';

class ProgressLogPage extends StatefulWidget {
  const ProgressLogPage({super.key});

  @override
  State<ProgressLogPage> createState() => _ProgressLogPageState();
}

class _ProgressLogPageState extends State<ProgressLogPage> {
  bool _busy = false;
  String? _err;

  final _weight = TextEditingController();
  final _bodyFatPercentage = TextEditingController();
  final _waist = TextEditingController();
  final _chest = TextEditingController();
  final _hips = TextEditingController();
  final _photoUrl = TextEditingController();
  final _notes = TextEditingController();

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final measurements = <String, double?>{
        'waist': _parseDouble(_waist.text),
        'chest': _parseDouble(_chest.text),
        'hips': _parseDouble(_hips.text),
      };
      final hasAnyMeasurement = measurements.values.any((v) => v != null);

      final payload = <String, dynamic>{
        'log_date': _today(),
        'weight': _parseDouble(_weight.text),
        'body_fat_percentage': _parseDouble(_bodyFatPercentage.text),
        'measurements': hasAnyMeasurement ? measurements : null,
        'photo_url': _photoUrl.text.trim().isEmpty
            ? null
            : _photoUrl.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      };

      final dash = await Api.instance.saveProgressLog(payload);
      if (!mounted) return;
      Navigator.of(context).pop(dash);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _bodyFatPercentage.dispose();
    _waist.dispose();
    _chest.dispose();
    _hips.dispose();
    _photoUrl.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _today();

    return Scaffold(
      appBar: AppBar(title: Text('Progress Log ($today)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _numberField(
            controller: _weight,
            label: 'Weight',
            hint: 'e.g. 185.4',
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _bodyFatPercentage,
            label: 'Body Fat %',
            hint: 'optional',
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _waist,
            label: 'Waist Measurement',
            hint: 'optional',
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _chest,
            label: 'Chest Measurement',
            hint: 'optional',
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _hips,
            label: 'Hips Measurement',
            hint: 'optional',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _photoUrl,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Photo URL',
              hintText: 'optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 4,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
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
                : const Text('Save Progress Log'),
          ),
        ],
      ),
    );
  }
}
