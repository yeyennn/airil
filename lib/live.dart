import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

const String realtimeDatabaseUrl =
    'https://mobile-app-project-fa711-default-rtdb.asia-southeast1.firebasedatabase.app';

// Flat buttons: no shadow in any state.
final ButtonStyle _flatButton = ElevatedButton.styleFrom(
  elevation: 0,
  shadowColor: Colors.transparent,
);

class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: realtimeDatabaseUrl,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Sensor Readings'),
        backgroundColor: const Color(0xFF723B0A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: db.ref('Sensor/latest').onValue,
        builder: (context, snap) {
          final v = snap.data?.snapshot.value;
          final s = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

          final temp = _num(s['temperature_c']);
          final hum = _num(s['humidity_pct']);
          final mq2 = _num(s['mq2_raw']);
          final dist = _num(s['distance_cm']);
          final alarm = s['alarm'] == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  style: _flatButton,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Dashboard'),
                ),
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                color: alarm ? Colors.red.shade100 : Colors.green.shade50,
                child: ListTile(
                  leading: Icon(
                    alarm ? Icons.warning : Icons.verified_user,
                    color: alarm ? Colors.red : Colors.green,
                  ),
                  title: Text(
                      alarm ? 'Abnormal condition detected' : 'No abnormal condition'),
                  subtitle: const Text(
                      'Automatic safety response is handled by the ESP32.'),
                ),
              ),
              const SizedBox(height: 12),

              _MeterTile('Temperature', temp, 0, 60, '°C', Icons.thermostat,
                  alarm),
              _MeterTile('Humidity', hum, 0, 100, '%', Icons.water_drop,
                  alarm),
              _MeterTile('MQ2 Gas', mq2, 0, 4095, 'raw', Icons.gas_meter,
                  alarm),
              _MeterTile('Ultrasonic Distance', dist < 0 ? 0 : dist, 0, 200,
                  'cm', Icons.social_distance, alarm),

              const SizedBox(height: 16),
              const Text('Status Indicators',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _FlagTile('Gas over limit', mq2 >= 800),
              _FlagTile('Temperature over 40°C', temp > 40),
              _FlagTile('Object closer than 20 cm', dist > 0 && dist < 20),
              const SizedBox(height: 12),
              Text(
                s.isEmpty
                    ? 'Waiting for data from the ESP32…'
                    : 'Updates live from Firebase (Sensor/latest)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  double _num(dynamic v) =>
      (v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '')) ?? -999;
}

class _MeterTile extends StatelessWidget {
  final String label;
  final double value; // -999 = sensor error
  final double min;
  final double max;
  final String unit;
  final IconData icon;
  final bool alarm;

  const _MeterTile(this.label, this.value, this.min, this.max, this.unit,
      this.icon, this.alarm);

  @override
  Widget build(BuildContext context) {
    final error = value == -999;
    final clamped = value.clamp(min, max);
    final fraction = (clamped - min) / (max - min);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: alarm ? Colors.red : const Color(0xFF723B0A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(
                  error ? 'ERR' : '${value.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: error ? 0 : fraction,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                color: alarm ? Colors.red : const Color(0xFF723B0A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final String label;
  final bool active;
  const _FlagTile(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(
          active ? Icons.error : Icons.check_circle,
          color: active ? Colors.red : Colors.green,
        ),
        title: Text(label),
        trailing: Text(
          active ? 'YES' : 'NO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: active ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }
}