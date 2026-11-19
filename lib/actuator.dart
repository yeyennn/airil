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

// Writes a value to Firebase and tells the user whether it worked.
Future<void> _send(
    BuildContext context,
    DatabaseReference ref,
    bool value,
    String name,
    ) async {
  try {
    await ref.set(value);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent $name command: ${value ? "ON" : "OFF"}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send command: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class ActuatorControlPage extends StatelessWidget {
  const ActuatorControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: realtimeDatabaseUrl,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actuator Control'),
        backgroundColor: const Color(0xFF723B0A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: db.ref('System/auto_mode').onValue,
        builder: (context, modeSnap) {
          // Missing node = automatic (the board's default)
          final auto = modeSnap.data?.snapshot.value != false;

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
                child: SwitchListTile(
                  title: const Text(
                    'AUTO MODE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: auto,
                  onChanged: (v) =>
                      _send(context, db.ref('System/auto_mode'), v, 'AUTO MODE'),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'Switch AUTO MODE off to control the devices below by hand.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              _ControlTile(db, 'Fan', 'Exhaust fan / relay (GPIO 26)',
                  Icons.toys, auto),
              _ControlTile(db, 'Lamp', 'Warning LED (GPIO 27)',
                  Icons.lightbulb, auto),
              _ControlTile(db, 'Buzzer', 'Active buzzer (GPIO 25)',
                  Icons.notifications_active, auto),
            ],
          );
        },
      ),
    );
  }
}

// path: 'Fan' | 'Lamp' | 'Buzzer'
// Command path: Actuator/<path>        (app writes)
// Actual state:  ActuatorState/<path>  (ESP32 writes)
class _ControlTile extends StatelessWidget {
  final FirebaseDatabase db;
  final String path;
  final String label;
  final IconData icon;
  final bool auto;
  const _ControlTile(this.db, this.path, this.label, this.icon, this.auto);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: db.ref('ActuatorState/$path').onValue,
      builder: (context, stateSnap) {
        final reported = stateSnap.data?.snapshot.value == true;

        return StreamBuilder<DatabaseEvent>(
          stream: db.ref('Actuator/$path').onValue,
          builder: (context, cmdSnap) {
            final cmd = cmdSnap.data?.snapshot.value;

            // Auto: show what the outputs are really doing.
            // Manual: show the command, so the switch moves straight away.
            final value = auto ? reported : (cmd is bool ? cmd : reported);

            return Card(
              elevation: 0,
              child: SwitchListTile(
                secondary: Icon(icon,
                    color: reported ? Colors.green : Colors.grey, size: 32),
                title: Text(label),
                subtitle: Text(reported
                    ? 'Currently ON (reported by ESP32)'
                    : 'Currently OFF (reported by ESP32)'),
                value: value,
                onChanged: auto
                    ? null
                    : (v) => _send(context, db.ref('Actuator/$path'), v, path),
              ),
            );
          },
        );
      },
    );
  }
}