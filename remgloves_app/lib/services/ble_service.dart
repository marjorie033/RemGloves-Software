import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── Data model ───────────────────────────────────────────────────────────────

class GloveData {
  /// Finger bend values — 0.0 (straight) to 1.0 (fully bent).
  final Map<String, double> fingers;

  /// 5-bit gesture byte from the ESP32.  bit0=Thumb … bit4=Pinky.
  final int gestureCode;

  const GloveData({required this.fingers, required this.gestureCode});

  /// Binary string MSB→LSB: Pinky Ring Middle Index Thumb  (e.g. "11010")
  String get gestureBinary =>
      [4, 3, 2, 1, 0].map((b) => (gestureCode >> b) & 1).join();
}

enum BleStatus { idle, scanning, connecting, connected, disconnected, error }

// ── BLE service ──────────────────────────────────────────────────────────────

class BleService {
  // ── Match your ESP32 exactly ───────────────────────────────────────────
  // BLEDevice::init("RemGloves")  →  deviceName must match
  static const String deviceName = 'RemGloves';

  // Nordic UART Service UUIDs (same as in ESP32 sketch)
  static const String _svcUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _txUuid  = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // notify

  // ── Streams ───────────────────────────────────────────────────────────────
  final _dataCtrl   = StreamController<GloveData>.broadcast();
  final _statusCtrl = StreamController<BleStatus>.broadcast();

  Stream<GloveData>  get dataStream   => _dataCtrl.stream;
  Stream<BleStatus>  get statusStream => _statusCtrl.stream;

  BleStatus _status = BleStatus.idle;
  BleStatus get status => _status;

  BluetoothDevice?    _device;
  StreamSubscription? _scanSub;
  StreamSubscription? _charSub;
  StreamSubscription? _connSub;

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

    // Scan timed out without finding the device
    if (_status == BleStatus.scanning) _emit(BleStatus.disconnected);
  }

  void disconnect() {
    _scanSub?.cancel();
    _charSub?.cancel();
    _connSub?.cancel();
    _device?.disconnect();
    _device = null;
    _emit(BleStatus.idle);
  }

  void dispose() {
    disconnect();
    _dataCtrl.close();
    _statusCtrl.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _emit(BleStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    _device = device;
    _emit(BleStatus.connecting);

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _emit(BleStatus.connected);

      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _charSub?.cancel();
          _emit(BleStatus.disconnected);
        }
      });

      final services = await device.discoverServices();
      for (final svc in services) {
        if (_matchUuid(svc.uuid, _svcUuid)) {
          for (final char in svc.characteristics) {
            if (_matchUuid(char.uuid, _txUuid)) {
              await char.setNotifyValue(true);
              _charSub = char.onValueReceived.listen((bytes) {
                final data = _parse(String.fromCharCodes(bytes).trim());
                if (data != null && !_dataCtrl.isClosed) _dataCtrl.add(data);
              });
              return;
            }
          }
        }
      }
    } catch (_) {
      _emit(BleStatus.error);
    }
  }

  bool _matchUuid(Guid uuid, String target) =>
      uuid.toString().toUpperCase() == target.toUpperCase();

  // ── Parser ────────────────────────────────────────────────────────────────
  // ESP32 packet (11 comma-separated integers, no spaces):
  //   pct[0],bent[0],pct[1],bent[1],pct[2],bent[2],pct[3],bent[3],pct[4],bent[4],code
  //   ─────── Thumb ────── ─────── Index ────── ─────── Middle ──────
  //   ─────── Ring  ────── ─────── Pinky ────── gestureCode
  //
  // pct  : 0–100 (bend percentage)
  // bent : 0=straight, 1=bent (debounced flag)
  // code : 5-bit byte, bit0=Thumb … bit4=Pinky

  static const _names = ['thumb', 'index', 'middle', 'ring', 'pinky'];

  GloveData? _parse(String raw) {
    try {
      final parts = raw.split(',');
      if (parts.length < 11) return null;

      final fingers = <String, double>{};
      for (int i = 0; i < 5; i++) {
        // Use the debounced bent flag (parts[i*2+1]) — 0=straight, 1=bent.
        // Ignore the raw pct value; we want discrete 0/1 behaviour only.
        final bent = int.tryParse(parts[i * 2 + 1].trim());
        if (bent == null) return null;
        fingers[_names[i]] = bent == 0 ? 0.0 : 1.0;
      }

      final code = int.tryParse(parts[10].trim()) ?? 0;
      return GloveData(fingers: fingers, gestureCode: code);
    } catch (_) {
      return null;
    }
  }
}
