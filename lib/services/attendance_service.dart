import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';

class AttendanceService {
  static const String _key = 'attendance_records';

  Future<List<Attendance>> loadRecords() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addRecord(Attendance a) async {
    final list = await loadRecords();
    list.add(a);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
