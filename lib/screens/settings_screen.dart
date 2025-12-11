import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../utils/dms_parser.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  final LocationService _locationService = LocationService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('compound_lat') ?? 4.3847778;
    final lng = prefs.getDouble('compound_lng') ?? 100.9675278;
    final rad = prefs.getDouble('compound_radius') ?? 2000.0;

    setState(() {
      _latController.text = lat.toString();
      _lngController.text = lng.toString();
      _radiusController.text = rad.toStringAsFixed(0);
      _loading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      setState(() {
        _latController.text = pos.latitude.toString();
        _lngController.text = pos.longitude.toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to get current location')));
    }
  }

  Future<void> _save() async {
    // Parse lat/lng (accept DMS or decimal)
    final latInput = _latController.text.trim();
    final lngInput = _lngController.text.trim();
    final radInput = _radiusController.text.trim();

    final lat = parseDmsOrDecimal(latInput);
    final lng = parseDmsOrDecimal(lngInput);
    final rad = double.tryParse(radInput);

    if (lat == null || lng == null || rad == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid input')));
      return;
    }

    await _locationService.setCompound(lat, lng, rad);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compound settings saved')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Compound Settings')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Latitude (decimal or DMS)'),
            TextField(controller: _latController),
            const SizedBox(height: 12),
            const Text('Longitude (decimal or DMS)'),
            TextField(controller: _lngController),
            const SizedBox(height: 12),
            const Text('Radius (meters)'),
            TextField(controller: _radiusController, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _useCurrentLocation, icon: const Icon(Icons.my_location), label: const Text('Use current location')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
