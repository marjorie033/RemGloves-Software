import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';

// ── Glove SVG icon ────────────────────────────────────────────────────────────

const String _handIcon = AppIcons.remlogo;

// ── States ────────────────────────────────────────────────────────────────────

enum GloveConnectState { scanning, found, nothingFound, connected }

// ── Device model ──────────────────────────────────────────────────────────────

class GloveDevice {
  final String name;
  final String meta;
  final int signalBars;

  const GloveDevice({
    required this.name,
    required this.meta,
    required this.signalBars,
  });
}

// ── Public helper ─────────────────────────────────────────────────────────────

Future<void> showConnectGloveDialog(BuildContext context, BleService ble) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _ConnectGloveDialog(ble: ble),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _ConnectGloveDialog extends StatefulWidget {
  final BleService ble;

  const _ConnectGloveDialog({required this.ble});

  @override
  State<_ConnectGloveDialog> createState() => _ConnectGloveDialogState();
}

class _ConnectGloveDialogState extends State<_ConnectGloveDialog>
    with TickerProviderStateMixin {
  GloveConnectState _state = GloveConnectState.scanning;
  GloveDevice? _selectedDevice;
  StreamSubscription<BleStatus>? _bleSub;

  late final List<AnimationController> _ringCtls;
  late final List<Animation<double>> _ringScales;
  late final List<Animation<double>> _ringOpacities;
  late final List<AnimationController> _dotCtls;
  late final List<Animation<double>> _dotOffsets;

  static const _mockDevices = [
    GloveDevice(name: 'RemGlove L-01', meta: 'Left hand · Firmware 2.3.1', signalBars: 3),
    GloveDevice(name: 'RemGlove R-01', meta: 'Right hand · Firmware 2.3.1', signalBars: 2),
  ];

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

    _dotCtls = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      ),
    );
    _dotOffsets = _dotCtls
        .map((c) => Tween<double>(begin: 0, end: -3)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _dotCtls[i].repeat(reverse: true);
      });
    }

    // Subscribe to real BLE status and kick off a scan if needed.
    _bleSub = widget.ble.statusStream.listen(_onBleStatus);
    final current = widget.ble.status;
    if (current == BleStatus.idle ||
        current == BleStatus.disconnected ||
        current == BleStatus.error) {
      widget.ble.connect();
    } else {
      _onBleStatus(current);
    }
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    for (final c in _ringCtls) {
      c.dispose();
    }
    for (final c in _dotCtls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onBleStatus(BleStatus status) {
    if (!mounted) return;
    setState(() {
      switch (status) {
        case BleStatus.scanning:
        case BleStatus.connecting:
          _state = GloveConnectState.scanning;
        case BleStatus.connected:
          _state = GloveConnectState.connected;
          _pauseRings();
        case BleStatus.disconnected:
        case BleStatus.error:
        case BleStatus.idle:
          _state = GloveConnectState.nothingFound;
          _pauseRings();
      }
    });
  }

  void _pauseRings() {
    for (final c in _ringCtls) {
      c.stop();
    }
  }

  void _resumeRings() {
    for (int i = 0; i < 3; i++) {
      _ringCtls[i].repeat();
    }
  }

  void _startScan() {
    setState(() {
      _state = GloveConnectState.scanning;
      _selectedDevice = null;
    });
    _resumeRings();
    widget.ble.connect();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            color: AppTheme.textPrimary.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
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
            if (_state == GloveConnectState.found) _buildDeviceList(),
            if (_state == GloveConnectState.nothingFound) _buildNothingFound(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Connect glove',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border.all(
                  color: AppTheme.textPrimary,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scan area ──────────────────────────────────────────────────────────────

  Widget _buildScanArea() {
    final isNothing   = _state == GloveConnectState.nothingFound;
    final isConnected = _state == GloveConnectState.connected;

    final Color iconBg = isNothing
        ? const Color(0xFFEEEEEE)
        : isConnected
            ? const Color(0xFFE6F9EE)
            : AppTheme.primary.withOpacity(0.13);

    final Color iconColor = isNothing
        ? AppTheme.textSecondary
        : isConnected
            ? const Color(0xFF2E9E5B)
            : AppTheme.primary;

    final Color ringColor =
        isConnected ? const Color(0xFF2E9E5B) : AppTheme.primary;

    final String label = switch (_state) {
      GloveConnectState.scanning     => 'Searching for gloves',
      GloveConnectState.found        => 'Glove detected',
      GloveConnectState.nothingFound => 'No gloves found',
      GloveConnectState.connected    => 'Connected',
    };

    // Reduced ring size to tighten vertical space
    const double ringSize    = 120.0;
    const double ringMid     = 92.0;
    const double ringInner   = 64.0;
    const double iconSize    = 52.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // ── Rings + icon ────────────────────────────────────────────────
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isNothing)
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
                                color: ringColor.withOpacity(0.3),
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
                      color: iconColor.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Iconify(_handIcon, color: iconColor, size: 26),
                  ),
                ),
              ],
            ),
          ),

          // ── Tighter gap from icon to label ──────────────────────────────
          const SizedBox(height: 10),

          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          // ── Subtitle ────────────────────────────────────────────────────
          if (_state == GloveConnectState.scanning)
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Make sure your glove is powered on\nand in pairing mode ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => AnimatedBuilder(
                          animation: _dotCtls[i],
                          builder: (_, _) => Transform.translate(
                            offset: Offset(0, _dotOffsets[i].value),
                            child: Container(
                              width: 3.5,
                              height: 3.5,
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_state == GloveConnectState.found)
            const Text(
              'Select a glove below to pair',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else if (_state == GloveConnectState.nothingFound)
            const Text(
              'We couldn\'t detect any nearby gloves',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else if (_state == GloveConnectState.connected)
            const Text(
              'Your glove is ready to use',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Device list ────────────────────────────────────────────────────────────

  Widget _buildDeviceList() {
    return Padding(
      // No divider — just consistent 20px side padding
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: List.generate(_mockDevices.length, (i) {
          final d        = _mockDevices[i];
          final selected = _selectedDevice?.name == d.name;
          return GestureDetector(
            onTap: () => setState(() => _selectedDevice = d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withOpacity(0.07)
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.textPrimary.withOpacity(0.08),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Iconify(_handIcon, color: AppTheme.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.meta,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SignalBars(bars: d.signalBars, color: AppTheme.primary),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Nothing found ──────────────────────────────────────────────────────────

  Widget _buildNothingFound() {
    const tips = [
      'Hold power button 3 s until it blinks',
      'Keep glove within 1 m of your phone',
      'Enable Bluetooth on your device',
      'Charge glove if LED indicator is red',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.textPrimary.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Try these steps',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            ...tips.asMap().entries.map(
              (e) => Padding(
                padding: EdgeInsets.only(bottom: e.key < tips.length - 1 ? 8 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final isConnected = _state == GloveConnectState.connected;
    final isNothing   = _state == GloveConnectState.nothingFound;
    final canConnect  = _state == GloveConnectState.found && _selectedDevice != null;

    final String rightLabel = isConnected
        ? 'Done'
        : isNothing
            ? 'Scan again'
            : 'Connect';

    final bool rightActive = canConnect || isConnected || isNothing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(
                  color: AppTheme.textPrimary,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            flex: 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: rightActive ? 1.0 : 0.4,
              child: ElevatedButton(
                onPressed: rightActive
                    ? () {
                        if (isConnected) {
                          Navigator.of(context).pop();
                        } else if (isNothing) {
                          _startScan();
                        } else if (canConnect) {
                          _pauseRings();
                          setState(() => _state = GloveConnectState.connected);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isConnected ? const Color(0xFF2E9E5B) : AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  disabledBackgroundColor: AppTheme.primary,
                  disabledForegroundColor: Colors.white,
                ),
                child: Text(
                  rightLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signal bars ───────────────────────────────────────────────────────────────

class _SignalBars extends StatelessWidget {
  final int bars;
  final Color color;

  const _SignalBars({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 10.0, 14.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        3,
        (i) => Container(
          width: 4,
          height: heights[i],
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: i < bars ? color : color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}