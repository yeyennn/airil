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

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: realtimeDatabaseUrl,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical Data'),
        backgroundColor: const Color(0xFF723B0A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: db
            .ref('History/Readings')
            .orderByChild('time')
            .limitToLast(50)
            .onValue,
        builder: (context, snap) {
          final rows = _readings(snap.data?.snapshot.value);

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
              const Text('Historical Sensor Data',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${rows.length} stored readings (latest first)',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),

              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No readings recorded yet. The ESP32 writes to History/Readings every 10 seconds once it is running.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Card(
                  elevation: 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('Temp °C')),
                        DataColumn(label: Text('Hum %')),
                        DataColumn(label: Text('MQ2')),
                        DataColumn(label: Text('Dist cm')),
                        DataColumn(label: Text('Alarm')),
                      ],
                      rows: rows.map((r) {
                        final t = r.time;
                        return DataRow(cells: [
                          DataCell(Text(
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}')),
                          DataCell(Text(r.temperatureC == -999
                              ? 'ERR'
                              : r.temperatureC.toStringAsFixed(1))),
                          DataCell(Text(r.humidityPct == -999
                              ? 'ERR'
                              : r.humidityPct.toStringAsFixed(1))),
                          DataCell(Text('${r.mq2Raw}')),
                          DataCell(Text(r.distanceCm == -999
                              ? 'ERR'
                              : r.distanceCm.toStringAsFixed(1))),
                          DataCell(Text(
                            r.alarm ? 'ALARM' : 'OK',
                            style: TextStyle(
                              color: r.alarm ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              const Text('Danger Events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              StreamBuilder<DatabaseEvent>(
                stream: db
                    .ref('History/Dangers')
                    .orderByChild('time')
                    .limitToLast(20)
                    .onValue,
                builder: (context, dangerSnap) {
                  final dangers = _dangers(dangerSnap.data?.snapshot.value);

                  if (dangers.isEmpty) {
                    return const Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text('No danger events recorded.'),
                      ),
                    );
                  }

                  return Column(
                    children: dangers.map((d) {
                      final t = d.time;
                      return Card(
                        elevation: 0,
                        color: Colors.red.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(d.message),
                          subtitle: Text(
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}'
                                  '  •  MQ2 raw: ${d.mq2Raw}'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  List<_Reading> _readings(dynamic v) {
    if (v is! Map) return [];
    final rows = v.values
        .whereType<Map>()
        .map((e) => _Reading.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time)); // newest first
    return rows;
  }

  List<_Danger> _dangers(dynamic v) {
    if (v is! Map) return [];
    final rows = v.values
        .whereType<Map>()
        .map((e) => _Danger.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time)); // newest first
    return rows;
  }
}

class _Reading {
  final DateTime time;
  final double temperatureC;
  final double humidityPct;
  final int mq2Raw;
  final double distanceCm;
  final bool alarm;

  _Reading({
    required this.time,
    required this.temperatureC,
    required this.humidityPct,
    required this.mq2Raw,
    required this.distanceCm,
    required this.alarm,
  });

  factory _Reading.fromJson(Map<String, dynamic> json) {
    return _Reading(
      time: _timeFrom(json['time']),
      temperatureC: _num(json['temperature_c'], -999),
      humidityPct: _num(json['humidity_pct'], -999),
      mq2Raw: _num(json['mq2_raw'], 0).round(),
      distanceCm: _num(json['distance_cm'], -999),
      alarm: json['alarm'] == true,
    );
  }
}

class _Danger {
  final DateTime time;
  final String message;
  final int mq2Raw;

  _Danger({required this.time, required this.message, required this.mq2Raw});

  factory _Danger.fromJson(Map<String, dynamic> json) {
    return _Danger(
      time: _timeFrom(json['time']),
      message: json['message']?.toString() ?? 'Danger event',
      mq2Raw: _num(json['mq2_raw'], 0).round(),
    );
  }
}

DateTime _timeFrom(dynamic v) {
  final ms = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
  return ms != null
      ? DateTime.fromMillisecondsSinceEpoch(ms)
      : DateTime.now();
}

double _num(dynamic v, double fallback) =>
    (v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '')) ??
        fallback;