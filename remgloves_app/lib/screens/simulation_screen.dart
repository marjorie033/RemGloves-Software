import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  WebViewController? _webViewController;
  bool _modelReady = false;

  static bool get _webViewSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  final Map<String, double> _fingerValues = {
    'thumb': 0.0,
    'index': 0.0,
    'middle': 0.0,
    'ring': 0.0,
    'pinky': 0.0,
  };

  static const _fingerLabels = {
    'thumb': 'Thumb',
    'index': 'Index',
    'middle': 'Middle',
    'ring': 'Ring',
    'pinky': 'Pinky',
  };

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) _initWebView();
  }

  Future<void> _initWebView() async {
    final ctrl = WebViewController();

    if (!kIsWeb) {
      ctrl
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: (msg) {
            if (msg.message == 'page_ready') {
              // Scripts loaded — inject GLTF with bin pre-embedded so
              // GLTFLoader.parse() never needs to XHR any binary files.
              _injectGLTFData(ctrl);
            } else if (msg.message == 'model_ready' && mounted) {
              setState(() => _modelReady = true);
            }
          },
        );

      final html = await rootBundle.loadString('lib/assets/hand_viewer.html');
      await ctrl.loadHtmlString(
        html,
        baseUrl: 'file:///android_asset/flutter_assets/lib/assets/',
      );
    } else {
      ctrl.loadRequest(
        Uri.base.resolve('assets/lib/assets/hand_viewer.html'),
      );
      if (mounted) setState(() => _modelReady = true);
    }

    if (mounted) setState(() => _webViewController = ctrl);
  }

  // Embeds scene.bin as a data URI inside the GLTF JSON and sends it to the
  // WebView in 50 KB chunks so each evaluateJavascript call stays small.
  // Textures stay as relative paths — img elements load them without XHR.
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

      final fullJson  = json.encode(gltfMap);
      const chunkSize = 50000; // 50 KB per evaluateJavascript call

      for (var i = 0; i < fullJson.length; i += chunkSize) {
        final end   = (i + chunkSize).clamp(0, fullJson.length);
        final chunk = fullJson.substring(i, end);
        await ctrl.runJavaScript('_addGLTFChunk(${json.encode(chunk)})');
      }
      await ctrl.runJavaScript('_parseGLTF("$basePath")');
    } catch (e) {
      debugPrint('GLTF injection error: $e');
    }
  }

  // Public surface: call this to drive fingers from live sensor data
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
                    // ── 3D Hand View ──────────────────────────────────
                    Container(
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
                          ? Stack(
                              children: [
                                WebViewWidget(controller: _webViewController!),
                                if (!_modelReady)
                                  Container(
                                    color: const Color(0xFF1A1A2E),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            color: AppTheme.primary,
                                            strokeWidth: 2,
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Loading 3D model...',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Center(
                              child: _webViewSupported
                                  ? CircularProgressIndicator(
                                      color: AppTheme.primary,
                                      strokeWidth: 2,
                                    )
                                  : const Text(
                                      '3D view is available on mobile only',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 14),

                    // ── Finger Sliders ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF483912),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: const Color(0xFF483912).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.pan_tool_outlined,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Finger Control',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ..._fingerValues.entries.map(
                            (e) => _FingerSlider(
                              label: _fingerLabels[e.key]!,
                              value: e.value,
                              onChanged: (v) => _setFinger(e.key, v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _FingerSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
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
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.15),
                thumbColor: AppTheme.primary,
                overlayColor: AppTheme.primary.withValues(alpha: 0.12),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 1,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
