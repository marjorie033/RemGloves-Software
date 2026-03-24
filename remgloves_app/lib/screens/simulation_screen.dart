import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';


class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

 @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  UnityWidgetController? _unityController;
  bool _unityLoaded = false;
  String _activeGesture = 'Waiting...';

  // Called when Unity is ready
  void _onUnityCreated(UnityWidgetController controller) {
    _unityController = controller;
    setState(() => _unityLoaded = true);
  }

  // Called when Unity sends a message back to Flutter
  // e.g. detected gesture name
  void _onUnityMessage(message) {
    setState(() => _activeGesture = message.toString());
  }

  // Send finger flex values to Unity hand model
  // Call this whenever your glove sensor data updates
  void sendFlexData({
    required double index,
    required double middle,
    required double ring,
    required double pinky,
  }) {
    if (_unityController == null) return;
    final payload = '$index,$middle,$ring,$pinky';
    _unityController!.postMessage(
      'HandController',   // GameObject name in Unity scene
      'ReceiveFlexData',  // Method name on the Unity script
      payload,
    );
  }

  @override
  void dispose() {
    _unityController?.dispose();
    super.dispose();
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
                'Unity Real-time Render',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(const Color(0xFFFDBF25)),
                  trackColor: WidgetStateProperty.all(AppTheme.background),
                  trackBorderColor: WidgetStateProperty.all(Colors.transparent),
                  thickness: WidgetStateProperty.all(10),
                  radius: const Radius.circular(10),
                  trackVisibility: WidgetStateProperty.all(true),
                  thumbVisibility: WidgetStateProperty.all(true),
                  crossAxisMargin: 8,
                  mainAxisMargin: 8,
                ),
                child: Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.only(left: 16, right: 36, bottom: 16),
                    children: [
                      const SizedBox(height: 4),

// ── Unity 3D View ──────────────────────────────────────

                      // Container(
                      //   height: 260,
                      //   decoration: BoxDecoration(
                      //     color: const Color(0xFF1A1A2E),
                      //     borderRadius: BorderRadius.circular(16),
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: Colors.black.withOpacity(0.15),
                      //         blurRadius: 12,
                      //         offset: const Offset(0, 4),
                      //       ),
                      //     ],
                      //   ),
                      //   child: Stack(
                      //     children: [
                      //       CustomPaint(
                      //         painter: _GridPainter(),
                      //         size: Size.infinite,
                      //       ),
                      //       Center(
                      //         child: Column(
                      //           mainAxisAlignment: MainAxisAlignment.center,
                      //           children: [
                      //             Container(
                      //               width: 80,
                      //               height: 80,
                      //               decoration: BoxDecoration(
                      //                 color: AppTheme.primary.withOpacity(0.15),
                      //                 shape: BoxShape.circle,
                      //                 border: Border.all(
                      //                   color: AppTheme.primary.withOpacity(0.4),
                      //                   width: 2,
                      //                 ),
                      //               ),
                      //               child: const Icon(
                      //                 Icons.pan_tool_alt,
                      //                 color: AppTheme.primary,
                      //                 size: 42,
                      //               ),
                      //             ),
                      //             const SizedBox(height: 16),
                      //             const Text(
                      //               '3D Model',
                      //               style: TextStyle(
                      //                 color: Colors.white70,
                      //                 fontSize: 13,
                      //                 fontWeight: FontWeight.w500,
                      //               ),
                      //             ),
                      //             const SizedBox(height: 4),
                      //             const Text(
                      //               'Coming soon — stay tuned',
                      //               style: TextStyle(
                      //                 color: Colors.white38,
                      //                 fontSize: 11,
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(height: 14),

                      Container(
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF483912).withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Unity widget embedded here
                            UnityWidget(
                              onUnityCreated: _onUnityCreated,
                              onUnityMessage: _onUnityMessage,
                              useAndroidViewSurface: true,
                              fullscreen: false,
                            ),
                            // Loading overlay while Unity initialises
                            if (!_unityLoaded)
                              Container(
                                color: const Color(0xFF1A1A2E),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                        ),
                      ),
                      const SizedBox(height: 14),

// ── Active Gesture Card ────────────────────────────────

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF483912),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),                   
                                border: Border.all(
                                  color: const Color(0xFF483912).withOpacity(0.2),
                                  width: 1,                      

                                ),
                              ),
                              child: const Icon(
                                Icons.pan_tool_outlined,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Active Gesture :',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _activeGesture,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 14),

// ── Flex Sensor Stats ──────────────────────────────────
                      
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Flex Index', value: '72%', icon: Icons.show_chart)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'Flex Middle', value: '68%', icon: Icons.show_chart)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Flex Ring', value: '45%', icon: Icons.show_chart)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'Flex Pinky', value: '30%', icon: Icons.show_chart)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class _GridPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.white.withOpacity(0.04)
//       ..strokeWidth = 1;

//     const step = 30.0;
//     for (double x = 0; x < size.width; x += step) {
//       canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
//     }
//     for (double y = 0; y < size.height; y += step) {
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }