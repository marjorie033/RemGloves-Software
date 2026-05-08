// 20 calibration integers in this order (5 fingers each):
//   calMin[0..4], calMax[5..9], bentThresh[10..14], strtThresh[15..19]
class CalibrationData {
  final List<int> calMin;      // raw ADC minimum (fully straight)
  final List<int> calMax;      // raw ADC maximum (fully bent)
  final List<int> bentThresh;  // ADC value above which finger counts as bent
  final List<int> strtThresh;  // ADC value below which finger counts as straight

  const CalibrationData({
    required this.calMin,
    required this.calMax,
    required this.bentThresh,
    required this.strtThresh,
  });

  factory CalibrationData.fromList(List<int> v) {
    assert(v.length == 20, 'Expected 20 calibration values, got ${v.length}');
    return CalibrationData(
      calMin:      List.unmodifiable(v.sublist(0, 5)),
      calMax:      List.unmodifiable(v.sublist(5, 10)),
      bentThresh:  List.unmodifiable(v.sublist(10, 15)),
      strtThresh:  List.unmodifiable(v.sublist(15, 20)),
    );
  }

  List<int> toList() =>
      [...calMin, ...calMax, ...bentThresh, ...strtThresh];

  // Produces "LOAD:v0,v1,...,v19" ready to write to RX characteristic.
  String toLoadCommand() => 'LOAD:${toList().join(',')}';

  @override
  String toString() => 'CalibrationData(${toList().join(',')})';
}
