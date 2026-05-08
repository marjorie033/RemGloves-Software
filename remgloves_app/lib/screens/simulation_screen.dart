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

  // ── BLE ───────────────────────────────────────────────────────────────────
  BleService get _ble => widget.ble;
  int _gestureCode = 0;
  StreamSubscription<GloveData>? _dataSub;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) _initWebView();
    _dataSub = _ble.dataStream.listen(_onBleData);
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  // ── BLE callbacks ─────────────────────────────────────────────────────────

  void _onBleData(GloveData data) {
    setState(() => _gestureCode = data.gestureCode);
    data.fingers.forEach(_setFinger);
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
      final gltfStr =
          await rootBundle.loadString('lib/assets/3dhand/scene.gltf');
      final binBytes = await rootBundle.load('lib/assets/3dhand/scene.bin');

      final gltfMap = json.decode(gltfStr) as Map<String, dynamic>;
      final binB64 = base64.encode(binBytes.buffer.asUint8List());
      (gltfMap['buffers'] as List)[0]['uri'] =
          'data:application/octet-stream;base64,$binB64';

      const basePath =
          'file:///android_asset/flutter_assets/lib/assets/3dhand/';
      final fullJson = json.encode(gltfMap);
      const chunkSize = 50000;

      for (var i = 0; i < fullJson.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, fullJson.length);
        await ctrl.runJavaScript(
            '_addGLTFChunk(${json.encode(fullJson.substring(i, end))})');
      }
      await ctrl.runJavaScript('_parseGLTF("$basePath")');
    } catch (e) {
      debugPrint('GLTF injection error: $e');
    }
  }

  // ── Finger → WebView ──────────────────────────────────────────────────────

  void _setFinger(String finger, double value) {
    _webViewController?.runJavaScript('setFingerValue("$finger", $value)');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RemGloveAppBar(ble: _ble),
      backgroundColor: AppTheme.primary,
      body: RoundedBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                '3D Hand Simulation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                children: [
                  _buildModelView(),
                  const SizedBox(height: 12),
                  _gestureCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3D view ───────────────────────────────────────────────────────────────

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
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
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
                      style:
                          TextStyle(color: Colors.white38, fontSize: 12)),
            ),
    );
  }

  // ── Gesture binary card ───────────────────────────────────────────────────

  Widget _gestureCard() {
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF483912)),
              ),
              child: const Icon(Icons.gesture,
                  color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Gesture Code',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                [4, 3, 2, 1, 0]
                    .map((b) => ((_gestureCode >> b) & 1))
                    .join(),
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
                  Text(
                    labels[i],
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: bent
                            ? AppTheme.primary
                            : AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: bent
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: bent
                            ? AppTheme.primary
                            : Colors.grey.shade300,
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
