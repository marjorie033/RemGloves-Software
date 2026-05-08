import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calibration_data.dart';
import '../models/glove_profile.dart';

class ProfileService {
  static const _prefsKey    = 'glove_profiles_v1';
  static const _lastCalKey  = 'last_calibration_v1';

  /// The reserved name shown for the auto-saved entry.
  static const lastCalName  = 'Last Calibration';

  // ── Last Calibration (auto-saved on every CAL: packet) ───────────────────

  Future<void> saveLastCalibration(CalibrationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCalKey, jsonEncode({
      'values':  data.toList(),
      'savedAt': DateTime.now().toIso8601String(),
    }));
  }

  Future<GloveProfile?> loadLastCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastCalKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GloveProfile(
        name:        lastCalName,
        calibration: CalibrationData.fromList(
            (map['values'] as List).cast<int>()),
        savedAt: DateTime.parse(map['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Named presets ─────────────────────────────────────────────────────────

  Future<List<GloveProfile>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map(_decode).whereType<GloveProfile>().toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt)); // newest first
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> save(GloveProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];

    // Replace any existing entry with the same name.
    final updated = list
        .where((e) => _decode(e)?.name != profile.name)
        .toList()
      ..add(_encode(profile));

    await prefs.setStringList(_prefsKey, updated);
  }

  Future<void> delete(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    final updated =
        list.where((e) => _decode(e)?.name != name).toList();
    await prefs.setStringList(_prefsKey, updated);
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  String _encode(GloveProfile p) => jsonEncode({
        'name':    p.name,
        'values':  p.calibration.toList(),
        'savedAt': p.savedAt.toIso8601String(),
      });

  GloveProfile? _decode(String raw) {
    try {
      final map    = jsonDecode(raw) as Map<String, dynamic>;
      final values = (map['values'] as List).cast<int>();
      return GloveProfile(
        name:        map['name'] as String,
        calibration: CalibrationData.fromList(values),
        savedAt:     DateTime.parse(map['savedAt'] as String),
      );
    } catch (_) {
      return null; // silently drop malformed entries
    }
  }
}
