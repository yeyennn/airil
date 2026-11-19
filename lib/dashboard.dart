import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'live.dart' show LivePage;
import 'history.dart' show HistoryPage;
import 'actuator.dart' show ActuatorControlPage;

const String realtimeDatabaseUrl =
    'https://mobile-app-project-fa711-default-rtdb.asia-southeast1.firebasedatabase.app';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: realtimeDatabaseUrl,
    );

    // Flat buttons: no shadow in any state (normal, hovered, pressed).
    final flatButton = ElevatedButton.styleFrom(
      elevation: 0,
      shadowColor: Colors.transparent,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Lab Dashboard'),
        backgroundColor: const Color(0xFF723B0A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: db.ref('Sensor/latest').onValue,
        builder: (context, sensorSnap) {
          final s = _asMap(sensorSnap.data?.snapshot.value);
          final alarm = s['alarm'] == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: flatButton,
                    onPressed: () => _go(context, const LivePage()),
                    icon: const Icon(Icons.speed),
                    label: const Text('Live'),
                  ),
                  ElevatedButton.icon(
                    style: flatButton,
                    onPressed: () => _go(context, const ActuatorControlPage()),
                    icon: const Icon(Icons.toggle_on),
                    label: const Text('Actuator'),
                  ),
                  ElevatedButton.icon(
                    style: flatButton,
                    onPressed: () => _go(context, const HistoryPage()),
                    icon: const Icon(Icons.show_chart),
                    label: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                alarm ? 'LAB STATUS: DANGER' : 'LAB STATUS: NORMAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: alarm ? Colors.red : Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Live readings from the laboratory ESP32',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),

              _ReadingTile('Temperature', _fmt(s['temperature_c'], '°C'),
                  Icons.thermostat, alarm),
              _ReadingTile('Humidity', _fmt(s['humidity_pct'], '%'),
                  Icons.water_drop, alarm),
              _ReadingTile('MQ2 Gas', _fmt(s['mq2_raw'], 'raw'),
                  Icons.gas_meter, alarm),
              _ReadingTile('Distance', _fmt(s['distance_cm'], 'cm'),
                  Icons.social_distance, alarm),

              const SizedBox(height: 16),
              const Text('Actuator State',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _ActuatorTile(db, 'Fan', 'Exhaust fan / relay (GPIO 26)', Icons.toys),
              _ActuatorTile(db, 'Lamp', 'Warning LED (GPIO 27)', Icons.lightbulb),
              _ActuatorTile(db, 'Buzzer', 'Active buzzer (GPIO 25)',
                  Icons.notifications_active),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : {};

  String _fmt(dynamic v, String unit) {
    if (v == null) return '--';
    final n = v is num ? v : double.tryParse(v.toString());
    if (n == null) return '--';
    if (n == -999) return 'ERR';
    final text =
    n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
    return '$text $unit';
  }
}

class _ReadingTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool alarm;
  const _ReadingTile(this.label, this.value, this.icon, this.alarm);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: alarm ? Colors.red.shade50 : null,
      child: ListTile(
        leading: Icon(icon, color: alarm ? Colors.red : Colors.green),
        title: Text(label),
        trailing: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ActuatorTile extends StatelessWidget {
  final FirebaseDatabase db;
  final String path; // 'Fan' | 'Lamp' | 'Buzzer'
  final String label;
  final IconData icon;
  const _ActuatorTile(this.db, this.path, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: db.ref('ActuatorState/$path').onValue,
      builder: (context, snap) {
        final on = snap.data?.snapshot.value == true;
        return Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(icon, color: on ? Colors.green : Colors.grey),
            title: Text(label),
            trailing: Text(
              on ? 'ON' : 'OFF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: on ? Colors.green : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}