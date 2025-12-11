import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/screens/settings_screen.dart';
import '../services/location_service.dart';
import '../services/attendance_service.dart';
import '../models/attendance.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final AttendanceService _attendanceService = AttendanceService();
  List<Attendance> _records = [];
  // List of session ranges for today: each map contains 'in' and 'out' DateTimes
  List<Map<String, DateTime?>> _sessionRanges = [];
  DateTime _now = DateTime.now();
  Timer? _ticker;
  String _statusText = 'Unknown';
  int _sessionsToday = 0;
  Duration _workedToday = Duration.zero;
  bool _canClockIn = true;
  bool _canClockOut = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _updateStatus();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _loadRecords() async {
    final records = await _attendanceService.loadRecords();
    // keep chronological order (oldest -> newest)
    setState(() => _records = records);
    _computeTodayStats();
  }

  Future<void> _updateStatus() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      final inside = await _locationService.isInsideCompound(pos);
      setState(() => _statusText = inside ? 'In-Office' : 'Outside compound');
    } catch (e) {
      setState(() => _statusText = 'Location unavailable');
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTime12(DateTime t) {
    final local = t.toLocal();
    var hour = local.hour % 12;
    if (hour == 0) hour = 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  String _formatDateLong(DateTime t) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final local = t.toLocal();
    final wd = weekdays[local.weekday - 1];
    return '${local.day}/${local.month}/${local.year} ($wd)';
  }

  void _computeTodayStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Filter today's records (chronological)
    final todayRecords = _records.where((r) => r.timestamp.isAfter(todayStart) && r.timestamp.isBefore(todayEnd)).toList();

    int sessions = 0;
    Duration total = Duration.zero;
    _sessionRanges = [];

    // Pair check-in with next check-out and record ranges
    for (int i = 0; i < todayRecords.length; i++) {
      final r = todayRecords[i];
      if (r.event == 'check-in') {
        // find next check-out after this index
        Attendance? out;
        for (int j = i + 1; j < todayRecords.length; j++) {
          if (todayRecords[j].event == 'check-out') {
            out = todayRecords[j];
            break;
          }
        }
        _sessionRanges.add({'in': r.timestamp, 'out': out?.timestamp});
        if (out != null) {
          sessions += 1;
          total += out.timestamp.difference(r.timestamp);
        } else {
          // ongoing session: include elapsed time up to now
          total += DateTime.now().difference(r.timestamp);
        }
      }
    }

    // Determine whether the user can clock in or clock out based on last today's event
    bool canIn = true;
    bool canOut = false;
    if (todayRecords.isNotEmpty) {
      final last = todayRecords.last;
      if (last.event == 'check-in') {
        canIn = false;
        canOut = true;
      } else {
        canIn = true;
        canOut = false;
      }
    }

    setState(() {
      _sessionsToday = sessions;
      _workedToday = total;
      _canClockIn = canIn;
      _canClockOut = canOut;
    });
  }

  Future<void> _clock(String type) async {
    try {
      final pos = await _locationService.getCurrentPosition();
      bool inside = await _locationService.isInsideCompound(pos);
      String locationType = 'In-Office';

      // Only ask for location type when checking in from outside compound.
      if (!inside && type == 'check-in') {
        locationType = await _askLocationType();
      } else {
        locationType = inside ? 'In-Office' : 'Outside';
      }

      final rec = Attendance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        event: type,
        timestamp: DateTime.now(),
        latitude: pos.latitude,
        longitude: pos.longitude,
        locationType: locationType,
      );

      await _attendanceService.addRecord(rec);
      await _loadRecords();
      await _updateStatus();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${type.toUpperCase()} recorded ($locationType)'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to record attendance. Check permissions.'),
      ));
    }
  }

  Future<String> _askLocationType() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Location detected outside compound'),
          content: const Text('Select location type for this clock event'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('Work From Home'),
              child: const Text('Work From Home'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('Alternate Location'),
              child: const Text('Alternate Location'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('Out of Office'),
              child: const Text('Out of Office'),
            ),
          ],
        );
      },
    );

    return choice ?? 'Outside';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _openAdminAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('admin_pin') ?? 'admin';

    final pinController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin authentication'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Admin PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK')),
        ],
      ),
    );

    if (ok == true && pinController.text == savedPin) {
      // authorized
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show newest records first
    final displayRecords = _records.reversed.toList();

    final lastSessionIn = _sessionRanges.isNotEmpty ? _sessionRanges.last['in'] : null;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _openAdminAuth,
          child: const Text('Attendance'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    const Text('Current Time', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(_formatDateLong(_now), style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(_formatTime12(_now), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text('Location status: $_statusText'),

            const SizedBox(height: 12),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: (_canClockIn || _canClockOut)
                    ? () => _clock(_canClockOut ? 'check-out' : 'check-in')
                    : null,
                child: Text(_canClockOut ? 'Clock Out' : 'Clock In'),
              ),
            ),

            const SizedBox(height: 18),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 8.0),
                child: Column(
                  children: [
                    if (lastSessionIn != null)
                      Column(
                        children: [
                          const Text('You have checked in today @', style: TextStyle(fontSize: 14)),
                          const SizedBox(height: 12),
                          Icon(Icons.access_time, size: 56, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(_formatTime12(lastSessionIn), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text('You have worked ${_formatDuration(_workedToday)} today.', style: const TextStyle(fontSize: 14)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Text('You are not checked in yet', style: TextStyle(fontSize: 14)),
                          const SizedBox(height: 12),
                          Icon(Icons.access_time, size: 56, color: Colors.grey),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(children: [Text('Sessions today: $_sessionsToday • Worked: ${_formatDuration(_workedToday)}')]),
            const SizedBox(height: 8),
            if (_sessionRanges.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _sessionRanges.map<Widget>((s) {
                  final inT = s['in']!;
                  final outT = s['out'];
                  final dur = (outT != null) ? outT.difference(inT) : _now.difference(inT);
                  final label = '${_formatTime(inT)} — ${outT != null ? _formatTime(outT) : 'now'} (${_formatDuration(dur)})';
                  return Chip(label: Text(label));
                }).toList(),
              ),

            const SizedBox(height: 12),

            const Text('Records:'),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: displayRecords.isEmpty
                  ? const Center(child: Text('No records yet'))
                  : ListView.builder(
                      itemCount: displayRecords.length,
                      itemBuilder: (ctx, i) {
                        final r = displayRecords[i];
                        return ListTile(
                          title: Text('${r.event.toUpperCase()} • ${r.locationType}'),
                          subtitle: Text('${r.timestamp.toLocal()}\n${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}'),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
