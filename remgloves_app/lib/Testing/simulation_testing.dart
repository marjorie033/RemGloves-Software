// import 'dart:math';
// import 'package:flutter/material.dart';
// import '../../theme/app_theme.dart';
// import '../../widgets/app_bar.dart';
// import '../../widgets/rounded_body.dart';

// class SimulationTesting extends StatefulWidget {
//   const SimulationTesting({super.key});

//   @override
//   State<SimulationTesting> createState() => _SimulationTestingState();
// }

// class _SimulationTestingState extends State<SimulationTesting>
//     with TickerProviderStateMixin {
//   // Flex values 0.0 (open) to 1.0 (closed)
//   double _indexFlex  = 0.0;
//   double _middleFlex = 0.0;
//   double _ringFlex   = 0.0;
//   double _pinkyFlex  = 0.0;
//   double _thumbFlex  = 0.0;

//   String _activeGesture = 'Open Palm';

//   late AnimationController _pulseController;
//   late Animation<double> _pulseAnim;

//   @override
//   void initState() {
//     super.initState();
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat(reverse: true);
//     _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _pulseController.dispose();
//     super.dispose();
//   }

//   void _detectGesture() {
//     if (_indexFlex < 0.2 && _middleFlex < 0.2 && _ringFlex < 0.2 && _pinkyFlex < 0.2) {
//       _activeGesture = 'Open Palm';
//     } else if (_indexFlex > 0.7 && _middleFlex > 0.7 && _ringFlex > 0.7 && _pinkyFlex > 0.7) {
//       _activeGesture = 'Closed Fist';
//     } else if (_indexFlex < 0.2 && _middleFlex < 0.2 && _ringFlex > 0.7 && _pinkyFlex > 0.7) {
//       _activeGesture = 'Peace Sign ✌️';
//     // } else if (_indexFlex < 0.2 && _middleFlex > 0.7 && _ringFlex > 0.7 && _pinkyFlex > 0.7) {
//       _activeGesture = 'Point Up ☝️';
//     } else if (_thumbFlex < 0.2 && _indexFlex > 0.7 && _middleFlex > 0.7 && _ringFlex > 0.7 && _pinkyFlex > 0.7) {
//       _activeGesture = 'Thumbs Up 👍';
//     } else {
//       _activeGesture = 'Custom Gesture';
//     }
//   }

//   void _applyPreset(String gesture) {
//     setState(() {
//       switch (gesture) {
//         case 'Open Palm':
//           _thumbFlex = 0.0; _indexFlex = 0.0; _middleFlex = 0.0; _ringFlex = 0.0; _pinkyFlex = 0.0;
//           break;
//         case 'Closed Fist':
//           _thumbFlex = 0.8; _indexFlex = 1.0; _middleFlex = 1.0; _ringFlex = 1.0; _pinkyFlex = 1.0;
//           break;
//         case 'Peace Sign':
//           _thumbFlex = 0.6; _indexFlex = 0.0; _middleFlex = 0.0; _ringFlex = 1.0; _pinkyFlex = 1.0;
//           break;
//         case 'Point Up':
//           _thumbFlex = 0.5; _indexFlex = 0.0; _middleFlex = 1.0; _ringFlex = 1.0; _pinkyFlex = 1.0;
//           break;
//         case 'Thumbs Up':
//           _thumbFlex = 0.0; _indexFlex = 1.0; _middleFlex = 1.0; _ringFlex = 1.0; _pinkyFlex = 1.0;
//           break;
//       }
//       _detectGesture();
//     });
//   }

//   Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 60,
//             child: Text(label,
//                 style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
//           ),
//           Expanded(
//             child: SliderTheme(
//               data: SliderThemeData(
//                 activeTrackColor: AppTheme.primary,
//                 inactiveTrackColor: AppTheme.primary.withOpacity(0.2),
//                 thumbColor: AppTheme.primary,
//                 overlayColor: AppTheme.primary.withOpacity(0.1),
//                 trackHeight: 3,
//                 thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
//               ),
//               child: Slider(
//                 value: value,
//                 onChanged: (v) {
//                   setState(() {
//                     onChanged(v);
//                     _detectGesture();
//                   });
//                 },
//               ),
//             ),
//           ),
//           SizedBox(
//             width: 36,
//             child: Text('${(value * 100).toInt()}%',
//                 style: const TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: AppTheme.textPrimary)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: const RemGloveAppBar(),
//       backgroundColor: AppTheme.primary,
//       body: RoundedBody(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Padding(
//               padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
//               child: Text(
//                 'Hand Simulation',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w700,
//                   color: AppTheme.textPrimary,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: ScrollbarTheme(
//                 data: ScrollbarThemeData(
//                   thumbColor: WidgetStateProperty.all(const Color(0xFFFDBF25)),
//                   trackColor: WidgetStateProperty.all(AppTheme.background),
//                   trackBorderColor: WidgetStateProperty.all(Colors.transparent),
//                   thickness: WidgetStateProperty.all(10),
//                   radius: const Radius.circular(10),
//                   trackVisibility: WidgetStateProperty.all(true),
//                   thumbVisibility: WidgetStateProperty.all(true),
//                   crossAxisMargin: 8,
//                   mainAxisMargin: 8,
//                 ),
//                 child: Scrollbar(
//                   child: ListView(
//                     padding: const EdgeInsets.only(left: 16, right: 36, bottom: 24),
//                     children: [
//                       const SizedBox(height: 4),

//                       // ── 3D Hand Canvas ─────────────────────────────────────
//                       Container(
//                         height: 300,
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF1A1A2E),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: const Color(0xFF483912).withOpacity(0.2),
//                             width: 1,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.2),
//                               blurRadius: 12,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         clipBehavior: Clip.antiAlias,
//                         child: Stack(
//                           children: [
//                             // Grid
//                             CustomPaint(
//                               painter: _GridPainter(),
//                               size: Size.infinite,
//                             ),
//                             // Animated hand
//                             AnimatedBuilder(
//                               animation: _pulseAnim,
//                               builder: (context, child) {
//                                 return Center(
//                                   child: Transform.scale(
//                                     scale: _pulseAnim.value,
//                                     child: CustomPaint(
//                                       size: const Size(180, 240),
//                                       painter: _HandPainter(
//                                         indexFlex: _indexFlex,
//                                         middleFlex: _middleFlex,
//                                         ringFlex: _ringFlex,
//                                         pinkyFlex: _pinkyFlex,
//                                         thumbFlex: _thumbFlex,
//                                       ),
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                             // Gesture label overlay
//                             Positioned(
//                               bottom: 12,
//                               left: 0,
//                               right: 0,
//                               child: Center(
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 14, vertical: 5),
//                                   decoration: BoxDecoration(
//                                     color: AppTheme.primary.withOpacity(0.85),
//                                     borderRadius: BorderRadius.circular(20),
//                                   ),
//                                   child: Text(
//                                     _activeGesture,
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.w700,
//                                       fontSize: 13,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 14),

//                       // ── Gesture Presets ────────────────────────────────────
//                       Container(
//                         padding: const EdgeInsets.all(14),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(14),
//                           border: Border.all(
//                               color: const Color(0xFF483912).withOpacity(0.2),
//                               width: 1),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text('Quick Gestures',
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: 13,
//                                     color: AppTheme.textPrimary)),
//                             const SizedBox(height: 10),
//                             Wrap(
//                               spacing: 8,
//                               runSpacing: 8,
//                               children: [
//                                 'Open Palm',
//                                 'Closed Fist',
//                                 'Peace Sign',
//                                 'Point Up',
//                                 'Thumbs Up',
//                               ].map((g) => GestureDetector(
//                                 onTap: () => _applyPreset(g),
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 12, vertical: 6),
//                                   decoration: BoxDecoration(
//                                     color: _activeGesture.startsWith(g)
//                                         ? AppTheme.primary
//                                         : AppTheme.primary.withOpacity(0.1),
//                                     borderRadius: BorderRadius.circular(20),
//                                     border: Border.all(
//                                       color: AppTheme.primary.withOpacity(0.4),
//                                       width: 1,
//                                     ),
//                                   ),
//                                   child: Text(
//                                     g,
//                                     style: TextStyle(
//                                       fontSize: 11,
//                                       fontWeight: FontWeight.w600,
//                                       color: _activeGesture.startsWith(g)
//                                           ? Colors.white
//                                           : AppTheme.primary,
//                                     ),
//                                   ),
//                                 ),
//                               )).toList(),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 14),

//                       // ── Finger Sliders ─────────────────────────────────────
//                       Container(
//                         padding: const EdgeInsets.all(14),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(14),
//                           border: Border.all(
//                               color: const Color(0xFF483912).withOpacity(0.2),
//                               width: 1),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.04),
//                               blurRadius: 6,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text('Flex Sensors',
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: 13,
//                                     color: AppTheme.textPrimary)),
//                             const SizedBox(height: 10),
//                             _buildSlider('Thumb',  _thumbFlex,  (v) => _thumbFlex  = v),
//                             _buildSlider('Index',  _indexFlex,  (v) => _indexFlex  = v),
//                             _buildSlider('Middle', _middleFlex, (v) => _middleFlex = v),
//                             _buildSlider('Ring',   _ringFlex,   (v) => _ringFlex   = v),
//                             _buildSlider('Pinky',  _pinkyFlex,  (v) => _pinkyFlex  = v),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 14),

//                       // ── Stat Cards ─────────────────────────────────────────
//                       Row(
//                         children: [
//                           Expanded(child: _StatCard(label: 'Flex Index',  value: '${(_indexFlex  * 100).toInt()}%')),
//                           const SizedBox(width: 10),
//                           Expanded(child: _StatCard(label: 'Flex Middle', value: '${(_middleFlex * 100).toInt()}%')),
//                         ],
//                       ),
//                       const SizedBox(height: 10),
//                       Row(
//                         children: [
//                           Expanded(child: _StatCard(label: 'Flex Ring',  value: '${(_ringFlex  * 100).toInt()}%')),
//                           const SizedBox(width: 10),
//                           Expanded(child: _StatCard(label: 'Flex Pinky', value: '${(_pinkyFlex * 100).toInt()}%')),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Hand Painter ───────────────────────────────────────────────────────────────
// class _HandPainter extends CustomPainter {
//   final double indexFlex;
//   final double middleFlex;
//   final double ringFlex;
//   final double pinkyFlex;
//   final double thumbFlex;

//   const _HandPainter({
//     required this.indexFlex,
//     required this.middleFlex,
//     required this.ringFlex,
//     required this.pinkyFlex,
//     required this.thumbFlex,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final skinColor = const Color(0xFFFDBF25);
//     final shadowColor = const Color(0xFFE09400);
//     final outlineColor = const Color(0xFF483912);

//     final fillPaint = Paint()..color = skinColor..style = PaintingStyle.fill;
//     final shadowPaint = Paint()..color = shadowColor..style = PaintingStyle.fill;
//     final outlinePaint = Paint()
//       ..color = outlineColor.withOpacity(0.6)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.5
//       ..strokeCap = StrokeCap.round
//       ..strokeJoin = StrokeJoin.round;

//     final cx = size.width / 2;
//     final cy = size.height;

//     // Draw palm
//     final palmPath = Path();
//     palmPath.moveTo(cx - 55, cy - 70);
//     palmPath.cubicTo(cx - 60, cy - 20, cx - 50, cy, cx, cy + 5);
//     palmPath.cubicTo(cx + 50, cy, cx + 60, cy - 20, cx + 55, cy - 70);
//     palmPath.cubicTo(cx + 40, cy - 90, cx - 40, cy - 90, cx - 55, cy - 70);
//     canvas.drawPath(palmPath, shadowPaint);
//     canvas.drawPath(palmPath, outlinePaint);

//     final palmFillPath = Path();
//     palmFillPath.moveTo(cx - 52, cy - 72);
//     palmFillPath.cubicTo(cx - 57, cy - 22, cx - 47, cy - 4, cx, cy + 2);
//     palmFillPath.cubicTo(cx + 47, cy - 4, cx + 57, cy - 22, cx + 52, cy - 72);
//     palmFillPath.cubicTo(cx + 37, cy - 88, cx - 37, cy - 88, cx - 52, cy - 72);
//     canvas.drawPath(palmFillPath, fillPaint);

//     // Draw fingers
//     _drawFinger(canvas, size, fillPaint, shadowPaint, outlinePaint,
//         baseX: cx - 38, baseY: cy - 88, flex: indexFlex,
//         fingerWidth: 16, segmentLengths: [30.0, 22.0, 18.0], label: 'I');

//     _drawFinger(canvas, size, fillPaint, shadowPaint, outlinePaint,
//         baseX: cx - 13, baseY: cy - 95, flex: middleFlex,
//         fingerWidth: 17, segmentLengths: [34.0, 24.0, 19.0], label: 'M');

//     _drawFinger(canvas, size, fillPaint, shadowPaint, outlinePaint,
//         baseX: cx + 13, baseY: cy - 92, flex: ringFlex,
//         fingerWidth: 15, segmentLengths: [30.0, 22.0, 17.0], label: 'R');

//     _drawFinger(canvas, size, fillPaint, shadowPaint, outlinePaint,
//         baseX: cx + 38, baseY: cy - 83, flex: pinkyFlex,
//         fingerWidth: 12, segmentLengths: [22.0, 16.0, 13.0], label: 'P');

//     // Thumb
//     _drawThumb(canvas, fillPaint, shadowPaint, outlinePaint,
//         baseX: cx - 58, baseY: cy - 55, flex: thumbFlex);
//   }

//   void _drawFinger(
//     Canvas canvas,
//     Size size,
//     Paint fill,
//     Paint shadow,
//     Paint outline, {
//     required double baseX,
//     required double baseY,
//     required double flex,
//     required double fingerWidth,
//     required List<double> segmentLengths,
//     required String label,
//   }) {
//     double x = baseX;
//     double y = baseY;
//     double angle = -pi / 2; // start pointing up

//     final hw = fingerWidth / 2;

//     for (int i = 0; i < segmentLengths.length; i++) {
//       final len = segmentLengths[i];
//       final bend = flex * (i == 0 ? 1.1 : 1.3) * (pi / 3);
//       final nextAngle = angle + bend;

//       final x2 = x + cos(nextAngle) * len;
//       final y2 = y + sin(nextAngle) * len;

//       // Segment shadow
//       final segShadow = Path();
//       segShadow.moveTo(x + cos(angle + pi / 2) * (hw + 1), y + sin(angle + pi / 2) * (hw + 1));
//       segShadow.lineTo(x + cos(angle - pi / 2) * (hw + 1), y + sin(angle - pi / 2) * (hw + 1));
//       segShadow.lineTo(x2 + cos(nextAngle - pi / 2) * (hw - 1), y2 + sin(nextAngle - pi / 2) * (hw - 1));
//       segShadow.lineTo(x2 + cos(nextAngle + pi / 2) * (hw - 1), y2 + sin(nextAngle + pi / 2) * (hw - 1));
//       segShadow.close();
//       canvas.drawPath(segShadow, shadow);

//       // Segment fill
//       final seg = Path();
//       seg.moveTo(x + cos(angle + pi / 2) * hw, y + sin(angle + pi / 2) * hw);
//       seg.lineTo(x + cos(angle - pi / 2) * hw, y + sin(angle - pi / 2) * hw);
//       seg.lineTo(x2 + cos(nextAngle - pi / 2) * (hw - 1.5), y2 + sin(nextAngle - pi / 2) * (hw - 1.5));
//       seg.lineTo(x2 + cos(nextAngle + pi / 2) * (hw - 1.5), y2 + sin(nextAngle + pi / 2) * (hw - 1.5));
//       seg.close();
//       canvas.drawPath(seg, fill);
//       canvas.drawPath(seg, outline);

//       // Joint circle
//       canvas.drawCircle(Offset(x, y), hw - 1, fill);
//       canvas.drawCircle(Offset(x, y), hw - 1, outline);

//       x = x2;
//       y = y2;
//       angle = nextAngle;
//     }

//     // Fingertip
//     canvas.drawCircle(Offset(x, y), hw - 2, fill);
//     canvas.drawCircle(Offset(x, y), hw - 2, outline);
//   }

//   void _drawThumb(
//     Canvas canvas,
//     Paint fill,
//     Paint shadow,
//     Paint outline, {
//     required double baseX,
//     required double baseY,
//     required double flex,
//   }) {
//     double x = baseX;
//     double y = baseY;
//     double angle = -pi / 4;

//     final segments = [22.0, 18.0];
//     final hw = 10.0;

//     for (int i = 0; i < segments.length; i++) {
//       final len = segments[i];
//       final bend = flex * (pi / 2.5);
//       final nextAngle = angle + bend;

//       final x2 = x + cos(nextAngle) * len;
//       final y2 = y + sin(nextAngle) * len;

//       final seg = Path();
//       seg.moveTo(x + cos(angle + pi / 2) * hw, y + sin(angle + pi / 2) * hw);
//       seg.lineTo(x + cos(angle - pi / 2) * hw, y + sin(angle - pi / 2) * hw);
//       seg.lineTo(x2 + cos(nextAngle - pi / 2) * (hw - 2), y2 + sin(nextAngle - pi / 2) * (hw - 2));
//       seg.lineTo(x2 + cos(nextAngle + pi / 2) * (hw - 2), y2 + sin(nextAngle + pi / 2) * (hw - 2));
//       seg.close();

//       canvas.drawPath(seg, shadow);
//       canvas.drawPath(seg, fill);
//       canvas.drawPath(seg, outline);
//       canvas.drawCircle(Offset(x, y), hw - 1, fill);
//       canvas.drawCircle(Offset(x, y), hw - 1, outline);

//       x = x2;
//       y = y2;
//       angle = nextAngle;
//     }
//     canvas.drawCircle(Offset(x, y), hw - 3, fill);
//     canvas.drawCircle(Offset(x, y), hw - 3, outline);
//   }

//   @override
//   bool shouldRepaint(_HandPainter old) =>
//       old.indexFlex != indexFlex ||
//       old.middleFlex != middleFlex ||
//       old.ringFlex != ringFlex ||
//       old.pinkyFlex != pinkyFlex ||
//       old.thumbFlex != thumbFlex;
// }

// // ── Grid Painter ───────────────────────────────────────────────────────────────
// class _GridPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.white.withOpacity(0.05)
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

// // ── Stat Card ──────────────────────────────────────────────────────────────────
// class _StatCard extends StatelessWidget {
//   final String label;
//   final String value;

//   const _StatCard({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//             color: const Color(0xFF483912).withOpacity(0.2), width: 1),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.show_chart, color: AppTheme.primary, size: 18),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(label,
//                     style: const TextStyle(
//                         fontSize: 11, color: AppTheme.textSecondary)),
//                 Text(value,
//                     style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w700,
//                         color: AppTheme.textPrimary)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }