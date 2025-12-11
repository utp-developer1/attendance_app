import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for persisted compound settings
const _kCompoundLat = 'compound_lat';
const _kCompoundLng = 'compound_lng';
const _kCompoundRadius = 'compound_radius';

class LocationService {
  // Default compound center and radius (meters).
  // Coordinates provided as: 4°23'05.2"N 100°58'03.1"E
  // Decimal degrees: latitude = 4.3847778, longitude = 100.9675278
  static const double _defaultLatitude = 4.3847778;
  static const double _defaultLongitude = 100.9675278;
  static const double _defaultRadiusMeters = 2000.0;

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<double> _getCompoundLatitude() async {
    final p = await _prefs;
    return p.getDouble(_kCompoundLat) ?? _defaultLatitude;
  }

  Future<double> _getCompoundLongitude() async {
    final p = await _prefs;
    return p.getDouble(_kCompoundLng) ?? _defaultLongitude;
  }

  Future<double> _getCompoundRadius() async {
    final p = await _prefs;
    return p.getDouble(_kCompoundRadius) ?? _defaultRadiusMeters;
  }

  /// Persist compound settings (admin only)
  Future<void> setCompound(double lat, double lng, double radiusMeters) async {
    final p = await _prefs;
    await p.setDouble(_kCompoundLat, lat);
    await p.setDouble(_kCompoundLng, lng);
    await p.setDouble(_kCompoundRadius, radiusMeters);
  }

  Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied forever');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  Future<bool> isInsideCompound(Position pos) async {
    final lat = await _getCompoundLatitude();
    final lng = await _getCompoundLongitude();
    final radius = await _getCompoundRadius();

    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );
    return distance <= radius;
  }
}
