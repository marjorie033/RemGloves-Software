import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

Future<void> showCalibrationProgressDialog(
    BuildContext context, BleService ble) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _CalibrationProgressDialog(ble: ble),
  );
}

// ── Dialog widget ─────────────────────────────────────────────────────────────

class _CalibrationProgressDialog extends StatefulWidget {
  final BleService ble;
  const _CalibrationProgressDialog({required this.ble});

  @override
  State<_CalibrationProgressDialog> createState() =>
      _CalibrationProgressDialogState();
}

class _CalibrationProgressDialogState
    extends State<_CalibrationProgressDialog> with TickerProviderStateMixin {

  final _logs      = <String>[];
  bool  _done      = false;
  StreamSubscription<String>? _logSub;
  final _scrollCtrl = ScrollController();

  // Pulsing rings — same parameters as the BLE scan dialog
  late final List<AnimationController> _ringCtls;
  late final List<Animation<double>>   _ringScales;
  late final List<Animation<double>>   _ringOpacities;

  @override
  void initState() {
    super.initState();

    _ringCtls = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      ),
    );
    _ringScales = _ringCtls
        .map((c) => Tween<double>(begin: 0.65, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
    _ringOpacities = _ringCtls
        .map((c) => Tween<double>(begin: 0.55, end: 0.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted) _ringCtls[i].repeat();
      });
    }

    _logSub = widget.ble.logStream.listen(_onLog);
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _scrollCtrl.dispose();
    for (final c in _ringCtls) { c.dispose(); }
    super.dispose();
  }

  void _onLog(String msg) {
    if (!mounted) return;
    setState(() => _logs.add(msg));

    // Keep the log scrolled to the latest line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });

    if (msg.contains('Calibration done!')) {
      setState(() => _done = true);
      for (final c in _ringCtls) { c.stop(); }
      // Brief pause so user sees the "complete" state before auto-close.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.textPrimary.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildScanArea(),
            if (_logs.isNotEmpty) _buildLogArea(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(
        _done ? 'Calibration Complete' : 'Calibrating Glove',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  // ── Animated rings + icon (mirrors the BLE scan dialog) ──────────────────

  Widget _buildScanArea() {
    const double ringSize  = 120.0;
    const double ringMid   = 92.0;
    const double ringInner = 64.0;
    const double iconSize  = 52.0;

    final Color ringColor  = _done ? const Color(0xFF2E9E5B) : AppTheme.primary;
    final Color iconBg     = _done
        ? const Color(0xFFE6F9EE)
        : AppTheme.primary.withValues(alpha: 0.13);
    final Color iconColor  = _done ? const Color(0xFF2E9E5B) : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!_done)
                  ...List.generate(3, (i) {
                    final sizes = [ringSize, ringMid, ringInner];
                    return AnimatedBuilder(
                      animation: _ringCtls[i],
                      builder: (_, _) => Opacity(
                        opacity: _ringOpacities[i].value,
                        child: Transform.scale(
                          scale: _ringScales[i].value,
                          child: Container(
                            width: sizes[i],
                            height: sizes[i],
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ringColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _done ? Icons.check_rounded : Icons.tune,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _done ? const Color(0xFF2E9E5B) : AppTheme.textPrimary,
            ),
            child: Text(_done ? 'Calibration complete!' : 'Calibrating…'),
          ),
          const SizedBox(height: 4),
          Text(
            _done
                ? 'Your glove is ready to use'
                : 'Follow the LED instructions on your glove',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Dark terminal-style log area ──────────────────────────────────────────

  Widget _buildLogArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(10),
        itemCount: _logs.length,
        itemBuilder: (_, i) => Text(
          _logs[i],
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.55,
            color: _logColor(_logs[i]),
          ),
        ),
      ),
    );
  }

  Color _logColor(String msg) {
    if (msg.contains('Calibration done!')) return const Color(0xFF4ADE80);
    if (msg.startsWith('====='))           return const Color(0xFFFBBF24);
    if (msg.startsWith('['))               return const Color(0xFF60A5FA);
    return Colors.white70;
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          // Cancel is only available while calibration is still running.
          onPressed: _done ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: const Text('Cancel',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
