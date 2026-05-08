import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/calibration_data.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class GloveData {
  /// Discrete bend state per finger — 0.0 (straight) or 1.0 (bent).
  final Map<String, double> fingers;

  /// Raw bend percentage 0–100 per finger, as measured by the ESP32.
  final Map<String, int> percentages;

  /// 5-bit gesture code from the ESP32.  bit0=Thumb … bit4=Pinky.
  final int gestureCode;

  const GloveData({
    required this.fingers,
    required this.percentages,
    required this.gestureCode,
  });

  /// Binary string MSB→LSB: Pinky Ring Middle Index Thumb  (e.g. "11010")
  String get gestureBinary =>
      [4, 3, 2, 1, 0].map((b) => (gestureCode >> b) & 1).join();
}

enum BleStatus { idle, scanning, connecting, connected, disconnected, error }

// ── BLE service ───────────────────────────────────────────────────────────────

class BleService {
  // ── Nordic UART Service UUIDs ────────────────────────────────────────────
  static const String deviceName = 'RemGloves';
  static const String _svcUuid  = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _txUuid   = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // notify
  static const String _rxUuid   = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'; // write

  // ── Streams ──────────────────────────────────────────────────────────────
  final _dataCtrl   = StreamController<GloveData>.broadcast();
  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _calCtrl    = StreamController<CalibrationData>.broadcast();
  final _wifiCtrl   = StreamController<String>.broadcast();
  final _logCtrl    = StreamController<String>.broadcast();

  Stream<GloveData>       get dataStream        => _dataCtrl.stream;
  Stream<BleStatus>       get statusStream      => _statusCtrl.stream;

  /// Fires whenever the glove sends a CAL: packet — after calibration
  /// completes or after a LOAD command is acknowledged.
  Stream<CalibrationData> get calibrationStream => _calCtrl.stream;

  /// Fires "OK" or "FAIL" when the glove replies to a WIFI: command.
  Stream<String>          get wifiStream        => _wifiCtrl.stream;

  /// Fires each LOG: message (prefix stripped) as the glove emits it.
  Stream<String>          get logStream         => _logCtrl.stream;

  BleStatus _status = BleStatus.idle;
  BleStatus get status => _status;

  BluetoothDevice?         _device;
  BluetoothCharacteristic? _rxChar;
  StreamSubscription?      _scanSub;
  StreamSubscription?      _charSub;
  StreamSubscription?      _connSub;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) return;

    _emit(BleStatus.scanning);
    _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == deviceName) {
          FlutterBluePlus.stopScan();
          _connectDevice(r.device);
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (_) {
      _emit(BleStatus.error);
      return;
    }

    if (_status == BleStatus.scanning) _emit(BleStatus.disconnected);
  }

  void disconnect() {
    _scanSub?.cancel();
    _charSub?.cancel();
    _connSub?.cancel();
    _device?.disconnect();
    _device  = null;
    _rxChar  = null;
    _emit(BleStatus.idle);
  }

  void dispose() {
    disconnect();
    _dataCtrl.close();
    _statusCtrl.close();
    _calCtrl.close();
    _wifiCtrl.close();
    _logCtrl.close();
  }

  /// Sends "CAL" to the glove, triggering the 3-phase physical calibration.
  /// Listen to [calibrationStream] for the resulting CAL: confirmation.
  Future<void> startCalibration() => _write('CAL');

  /// Sends "LOAD:<20 values>" to the glove, restoring a saved profile.
  /// The glove echoes a CAL: packet on success — listen to [calibrationStream].
  Future<void> loadProfile(CalibrationData data) =>
      _write(data.toLoadCommand());

  /// Sends `WIFI:<ssid>|<password>` to the glove.
  /// Listen to [wifiStream] for "OK" or "FAIL".
  Future<void> sendWifiCredentials(String ssid, String password) =>
      _write('WIFI:$ssid|$password');

  // ── Internal ──────────────────────────────────────────────────────────────

  void _emit(BleStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<void> _write(String command) async {
    final rx = _rxChar;
    if (rx == null) return;
    await rx.write(utf8.encode(command), withoutResponse: false);
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    _device = device;
    _emit(BleStatus.connecting);

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      // Request a large MTU so LOAD: commands and CAL: replies fit in one frame.
      // Best-effort — proceed even if the peripheral refuses.
      try {
        await device.requestMtu(512);
      } catch (_) {}

      _emit(BleStatus.connected);

      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _charSub?.cancel();
          _rxChar = null;
          _emit(BleStatus.disconnected);
        }
      });

      final services = await device.discoverServices();
      for (final svc in services) {
        if (!_matchUuid(svc.uuid, _svcUuid)) continue;

        for (final char in svc.characteristics) {
          if (_matchUuid(char.uuid, _txUuid)) {
            await char.setNotifyValue(true);
            _charSub = char.onValueReceived.listen(
              (bytes) => _handlePacket(utf8.decode(bytes).trim()),
            );
          }
          if (_matchUuid(char.uuid, _rxUuid)) {
            _rxChar = char;
          }
        }
        break; // found our service — no need to scan further
      }
    } catch (_) {
      _emit(BleStatus.error);
    }
  }

  // ── Packet dispatcher ─────────────────────────────────────────────────────

  void _handlePacket(String raw) {
    if (raw.startsWith('CAL:')) {
      final cal = _parseCalibration(raw.substring(4));
      if (cal != null && !_calCtrl.isClosed) _calCtrl.add(cal);
    } else if (raw.startsWith('WIFI:')) {
      final result = raw.substring(5); // "OK" or "FAIL"
      if (!_wifiCtrl.isClosed) _wifiCtrl.add(result);
    } else if (raw.startsWith('LOG:')) {
      final msg = raw.substring(4);
      if (!_logCtrl.isClosed) _logCtrl.add(msg);
    } else {
      final data = _parseSensor(raw);
      if (data != null && !_dataCtrl.isClosed) _dataCtrl.add(data);
    }
  }

  // ── CAL: parser ───────────────────────────────────────────────────────────
  // Payload: 20 comma-separated ints
  //   calMin×5, calMax×5, bentThresh×5, strtThresh×5

  CalibrationData? _parseCalibration(String payload) {
    try {
      final values =
          payload.split(',').map((s) => int.parse(s.trim())).toList();
      if (values.length != 20) return null;
      return CalibrationData.fromList(values);
    } catch (_) {
      return null;
    }
  }

  // ── Sensor packet parser ──────────────────────────────────────────────────
  // Format: T%,T_bent,I%,I_bent,M%,M_bent,R%,R_bent,P%,P_bent,code
  //   %    : 0–100 bend percentage
  //   _bent: 0=straight, 1=bent (debounced)
  //   code : 5-bit gesture (bit0=Thumb … bit4=Pinky)

  static const _names = ['thumb', 'index', 'middle', 'ring', 'pinky'];

  GloveData? _parseSensor(String raw) {
    try {
      final parts = raw.split(',');
      if (parts.length < 11) return null;

      final fingers     = <String, double>{};
      final percentages = <String, int>{};

      for (int i = 0; i < 5; i++) {
        final pct  = int.tryParse(parts[i * 2].trim());
        final bent = int.tryParse(parts[i * 2 + 1].trim());
        if (pct == null || bent == null) return null;
        fingers[_names[i]]     = bent == 0 ? 0.0 : 1.0;
        percentages[_names[i]] = pct.clamp(0, 100);
      }

      final code = int.tryParse(parts[10].trim()) ?? 0;
      return GloveData(
          fingers: fingers, percentages: percentages, gestureCode: code);
    } catch (_) {
      return null;
    }
  }

  bool _matchUuid(Guid uuid, String target) =>
      uuid.toString().toUpperCase() == target.toUpperCase();
}
