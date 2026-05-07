import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';

class SimulationScreen extends StatefulWidget {
  final BleService ble;

  const SimulationScreen({super.key, required this.ble});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  // ── WebView ───────────────────────────────────────────────────────────────
  WebViewController? _webViewController;
  bool _modelReady = false;

  static bool get _webViewSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  // ── Finger state ──────────────────────────────────────────────────────────
  final Map<String, double> _fingerValues = {
    'thumb': 0.0, 'index': 0.0, 'middle': 0.0, 'ring': 0.0, 'pinky': 0.0,
  };

  static const _fingerLabels = {
    'thumb': 'Thumb', 'index': 'Index', 'middle': 'Middle',
    'ring': 'Ring',   'pinky': 'Pinky',
  };

  // ── BLE ───────────────────────────────────────────────────────────────────
  BleService get _ble => widget.ble;
  BleStatus _bleStatus = BleStatus.idle;
  int _gestureCode = 0;
  StreamSubscription<GloveData>? _dataSub;
  StreamSubscription<BleStatus>? _statusSub;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) _initWebView();
    _dataSub   = _ble.dataStream.listen(_onBleData);
    _statusSub = _ble.statusStream.listen((s) => setState(() => _bleStatus = s));
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  // ── BLE callbacks ─────────────────────────────────────────────────────────

  void _onBleData(GloveData data) {
    setState(() => _gestureCode = data.gestureCode);
    data.fingers.forEach((finger, value) {
      if (_fingerValues.containsKey(finger)) _setFinger(finger, value);
    });
  }

  // ── WebView init ──────────────────────────────────────────────────────────

  Future<void> _initWebView() async {
    final ctrl = WebViewController();

    if (!kIsWeb) {
      ctrl
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (msg) {
          if (msg.message == 'page_ready') {
            _injectGLTFData(ctrl);
          } else if (msg.message == 'model_ready' && mounted) {
            setState(() => _modelReady = true);
          }
        });

      final html = await rootBundle.loadString('lib/assets/hand_viewer.html');
      await ctrl.loadHtmlString(
        html,
        baseUrl: 'file:///android_asset/flutter_assets/lib/assets/',
      );
    } else {
      ctrl.loadRequest(Uri.base.resolve('assets/lib/assets/hand_viewer.html'));
      if (mounted) setState(() => _modelReady = true);
    }

    if (mounted) setState(() => _webViewController = ctrl);
  }

  Future<void> _injectGLTFData(WebViewController ctrl) async {
    try {
      final gltfStr  = await rootBundle.loadString('lib/assets/3dhand/scene.gltf');
      final binBytes = await rootBundle.load('lib/assets/3dhand/scene.bin');

      final gltfMap = json.decode(gltfStr) as Map<String, dynamic>;
      final binB64  = base64.encode(binBytes.buffer.asUint8List());
      (gltfMap['buffers'] as List)[0]['uri'] =
          'data:application/octet-stream;base64,$binB64';

      const basePath =
          'file:///android_asset/flutter_assets/lib/assets/3dhand/';
      final fullJson = json.encode(gltfMap);
      const chunkSize = 50000;

      for (var i = 0; i < fullJson.length; i += chunkSize) {
        final end   = (i + chunkSize).clamp(0, fullJson.length);
        await ctrl.runJavaScript(
            '_addGLTFChunk(${json.encode(fullJson.substring(i, end))})');
      }
      await ctrl.runJavaScript('_parseGLTF("$basePath")');
    } catch (e) {
      debugPrint('GLTF injection error: $e');
    }
  }

  // ── Finger control ────────────────────────────────────────────────────────

  void updateFingerValues(Map<String, double> values) {
    values.forEach((finger, value) {
      if (_fingerValues.containsKey(finger)) {
        _setFinger(finger, value.clamp(0.0, 1.0));
      }
    });
  }

  void _setFinger(String finger, double value) {
    setState(() => _fingerValues[finger] = value);
    _webViewController?.runJavaScript('setFingerValue("$finger", $value)');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RemGloveAppBar(),
      backgroundColor: AppTheme.primary,
      body: RoundedBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text('3D Hand Simulation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  )),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                children: [
                  // ── 3D view ─────────────────────────────────────────
                  _buildModelView(),
                  const SizedBox(height: 12),

                  // ── BLE connection card ──────────────────────────────
                  _bleCard(),
                  const SizedBox(height: 12),

                  // ── Gesture code (binary) ────────────────────────────
                  _gestureCard(),
                  const SizedBox(height: 12),

                  // ── Finger sliders ───────────────────────────────────
                  _sliderCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3D view widget ────────────────────────────────────────────────────────

  Widget _buildModelView() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _webViewSupported && _webViewController != null
          ? Stack(children: [
              WebViewWidget(controller: _webViewController!),
              if (!_modelReady)
                Container(
                  color: const Color(0xFF1A1A2E),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2),
                        const SizedBox(height: 16),
                        const Text('Loading 3D model…',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ])
          : Center(
              child: _webViewSupported
                  ? CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2)
                  : const Text('3D view is available on mobile only',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
    );
  }

  // ── BLE connection card ───────────────────────────────────────────────────

  Widget _bleCard() {
    final connected = _bleStatus == BleStatus.connected;
    final busy = _bleStatus == BleStatus.scanning ||
        _bleStatus == BleStatus.connecting;

    final statusText = {
      BleStatus.idle:         'Not connected',
      BleStatus.scanning:     'Scanning for ${BleService.deviceName}…',
      BleStatus.connecting:   'Connecting…',
      BleStatus.connected:    'Connected to ${BleService.deviceName}',
      BleStatus.disconnected: 'Disconnected',
      BleStatus.error:        'Connection error',
    }[_bleStatus]!;

    final dot = connected
        ? AppTheme.toggleOn
        : busy
            ? AppTheme.primary
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: dot, shape: BoxShape.circle,
              boxShadow: connected
                  ? [BoxShadow(color: dot.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(statusText,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
          ),
          if (busy)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            )
          else
            TextButton(
              onPressed: connected ? _ble.disconnect : _ble.connect,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppTheme.primary),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                connected ? 'Disconnect' : 'Connect',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ── Gesture binary card ───────────────────────────────────────────────────

  Widget _gestureCard() {
    // bit4=Pinky … bit0=Thumb (MSB → LSB)
    const bits   = [4, 3, 2, 1, 0];
    const labels = ['P', 'R', 'M', 'I', 'T'];
    const names  = ['Pinky', 'Ring', 'Middle', 'Index', 'Thumb'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: const Color(0xFF483912)),
              ),
              child: const Icon(Icons.gesture, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Gesture Code',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            // Show raw binary string
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                [4,3,2,1,0].map((b) => ((_gestureCode >> b) & 1)).join(),
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final bent = ((_gestureCode >> bits[i]) & 1) == 1;
              return Tooltip(
                message: names[i],
                child: Column(children: [
                  Text(labels[i],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: bent
                              ? AppTheme.primary
                              : AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: bent
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: bent ? AppTheme.primary : Colors.grey.shade300,
                        width: bent ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        bent ? '1' : '0',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: bent
                                ? AppTheme.primary
                                : AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Slider card ───────────────────────────────────────────────────────────

  Widget _sliderCard() {
    final connected = _bleStatus == BleStatus.connected;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    // color: const Color(0xFF483912).withValues(alpha: 0.2)),
                    color: const Color(0xFF483912)),
              ),
              child: const Icon(Icons.pan_tool_outlined,
                  color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Finger Control',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text(
                connected ? 'Live from BLE' : 'Manual',
                style: TextStyle(
                    fontSize: 10,
                    color: connected ? AppTheme.toggleOn : AppTheme.textSecondary),
              ),
            ]),
          ]),
          const SizedBox(height: 14),
          ..._fingerValues.entries.map((e) => _FingerToggle(
                label: _fingerLabels[e.key]!,
                isBent: e.value >= 0.5,
                // Toggles are interactive only in manual mode
                onChanged: connected
                    ? null
                    : (bent) => _setFinger(e.key, bent ? 1.0 : 0.0),
              )),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
}

// ── Finger toggle widget ──────────────────────────────────────────────────────

class _FingerToggle extends StatelessWidget {
  final String label;
  final bool isBent;
  final ValueChanged<bool>? onChanged;
 
  const _FingerToggle({
    required this.label,
    required this.isBent,
    required this.onChanged,
  });
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Finger name — fixed width, left-anchored
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
 
          // Pushes the toggle group to the right
          const Spacer(),
 
          // "Straight" label
          Text(
            'Straight',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBent ? FontWeight.w400 : FontWeight.w600,
              color: isBent ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
 
          // Toggle switch
          Switch(
            value: isBent,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
 
          // "Bent" label — fixed width so the column stays stable
          SizedBox(
            width: 32,
            child: Text(
              'Bent',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBent ? FontWeight.w600 : FontWeight.w400,
                color: isBent ?  AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

