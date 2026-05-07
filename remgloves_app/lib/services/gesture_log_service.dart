import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'ble_service.dart';

// Mirrors the gesture table in the ESP32 sketch.
const Map<int, String> _gestures = {
  29: 'TV: UP',
  25: 'TV: DOWN',
   3: 'TV: LEFT',
   1: 'TV: RIGHT',
  15: 'TV: OK',
  24: 'TV: Volume UP',
  28: 'TV: Volume DOWN',
  31: 'TV: BACK',
  17: 'TV: HOME',
  14: 'TV: NETFLIX',
   4: 'TV: ON/OFF',
   9: 'Light ON',
  13: 'Light OFF',
  30: 'Fan ON',
  12: 'Fan OFF',
};

class GestureLogService {
  final BleService _ble;

  final List<Map<String, dynamic>> _buffer = [];
  int _lastCode = -1;
  bool _wasConnected = false;

  StreamSubscription<GloveData>? _dataSub;
  StreamSubscription<BleStatus>? _statusSub;

  GestureLogService(this._ble) {
    _statusSub = _ble.statusStream.listen(_onStatus);
    _dataSub   = _ble.dataStream.listen(_onData);
  }

  void _onStatus(BleStatus status) {
    if (status == BleStatus.connected) {
      _wasConnected = true;
      _lastCode = -1;
    } else if (_wasConnected &&
        (status == BleStatus.disconnected || status == BleStatus.idle)) {
      _wasConnected = false;
      _flush();
    }
  }

  void _onData(GloveData data) {
    final code = data.gestureCode;
    if (code == _lastCode) return;
    _lastCode = code;

    final action = _gestures[code];
    if (action == null) return;

    _buffer.add({
      't':   DateTime.now().millisecondsSinceEpoch,
      'cmd': action,
    });
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final toUpload = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    final ref = FirebaseDatabase.instance.ref('gestures');
    for (final entry in toUpload) {
      try {
        await ref.push().set(entry);
      } catch (_) {
        // Continue uploading remaining entries even if one fails.
      }
    }
  }

  void dispose() {
    _dataSub?.cancel();
    _statusSub?.cancel();
  }
}
