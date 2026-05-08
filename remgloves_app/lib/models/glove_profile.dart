import 'calibration_data.dart';

class GloveProfile {
  final String name;
  final CalibrationData calibration;
  final DateTime savedAt;

  const GloveProfile({
    required this.name,
    required this.calibration,
    required this.savedAt,
  });

  GloveProfile copyWith({String? name, CalibrationData? calibration}) =>
      GloveProfile(
        name:        name        ?? this.name,
        calibration: calibration ?? this.calibration,
        savedAt:     savedAt,
      );

  @override
  String toString() => 'GloveProfile("$name", savedAt: $savedAt)';
}
