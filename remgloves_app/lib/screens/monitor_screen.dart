import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../services/ble_service.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';
import '../theme/app_icons.dart';
import '../widgets/connect-glove-dialog.dart';

const String _lightIcon = AppIcons.lightbulb;
const String _fanIcon   = AppIcons.fan;
const String _tvIcon    = AppIcons.tv;

class MonitorScreen extends StatefulWidget {
  final MqttService mqttService;
  final BleService ble;

  const MonitorScreen({super.key, required this.mqttService, required this.ble});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  bool _lightOn      = false;
  bool _lightPending = false;
  Timer? _lightRollbackTimer;

  bool _fanOn      = false;
  bool _fanPending = false;
  Timer? _fanRollbackTimer;

  final bool _tvOn = false;
  bool _connected  = false;

  StreamSubscription<bool>?    _lightSub;
  StreamSubscription<bool>?    _fanSub;
  StreamSubscription<bool>?    _connSub;
  StreamSubscription<String?>? _errorSub;
  String? _mqttError;

  @override
  void initState() {
    super.initState();
    _connected = widget.mqttService.isConnected;
    _lightOn   = widget.mqttService.lightOn;
    _fanOn     = widget.mqttService.fanOn;

    _lightSub = widget.mqttService.lightStateStream.listen((on) {
      _lightRollbackTimer?.cancel();
      _lightRollbackTimer = null;
      setState(() {
        _lightOn      = on;
        _lightPending = false;
      });
    });

    _fanSub = widget.mqttService.fanStateStream.listen((on) {
      _fanRollbackTimer?.cancel();
      _fanRollbackTimer = null;
      setState(() {
        _fanOn      = on;
        _fanPending = false;
      });
    });

    _connSub = widget.mqttService.connectionStream.listen(
      (connected) => setState(() => _connected = connected),
    );

    _errorSub = widget.mqttService.errorStream.listen(
      (err) => setState(() => _mqttError = err),
    );
    
     if (!_connected) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showConnectGloveDialog(context, widget.ble);
    });
  }
  }

  @override
  void dispose() {
    _lightSub?.cancel();
    _fanSub?.cancel();
    _connSub?.cancel();
    _errorSub?.cancel();
    _lightRollbackTimer?.cancel();
    _fanRollbackTimer?.cancel();
    super.dispose();
  }

  void _toggleLight(bool v) {
    if (_lightPending) return;
    _lightRollbackTimer?.cancel();
    setState(() {
      _lightOn      = v;
      _lightPending = true;
    });
    widget.mqttService.publishLightControl(v ? 'ON' : 'OFF');
    _lightRollbackTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _lightOn      = !v;
          _lightPending = false;
        });
      }
    });
  }

  void _toggleFan(bool v) {
    if (_fanPending) return;
    _fanRollbackTimer?.cancel();
    setState(() {
      _fanOn      = v;
      _fanPending = true;
    });
    widget.mqttService.publishFanControl(v ? 'ON' : 'OFF');
    _fanRollbackTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _fanOn      = !v;
          _fanPending = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RemGloveAppBar(ble: widget.ble),
      backgroundColor: AppTheme.primary,
      body: RoundedBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Device Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                _ConnectionBadge(connected: _connected),
              ],
            ),
            if (!_connected && _mqttError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCA28)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFF9A825)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MQTT error: $_mqttError',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _DeviceTile(
              svgIcon: _lightIcon,
              iconColor: const Color(0xFFF5A623),
              label: 'Smart Light',
              subtitle: _lightPending
                  ? 'Updating...'
                  : (_lightOn ? 'Device is ON' : 'Device is OFF'),
              value: _lightOn,
              pending: _lightPending,
              onChanged: _toggleLight,
            ),
            const SizedBox(height: 10),
            _DeviceTile(
              svgIcon: _fanIcon,
              iconColor: const Color(0xFF29B6F6),
              label: 'Smart Fan',
              subtitle: _fanPending
                  ? 'Updating...'
                  : (_fanOn ? 'Device is ON' : 'Device is OFF'),
              value: _fanOn,
              pending: _fanPending,
              onChanged: _toggleFan,
            ),
            const SizedBox(height: 10),
            _DeviceTile(
              svgIcon: _tvIcon,
              iconColor: const Color(0xFFF5A623),
              label: 'Smart TV',
              subtitle: 'Coming soon',
              value: _tvOn,
              pending: false,
              onChanged: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  const _ConnectionBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: connected
                ? const Color(0xFF4CAF50)
                : const Color(0xFFBDBDBD),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          connected ? 'Connected' : 'Disconnected',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: connected
                ? const Color(0xFF4CAF50)
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final String svgIcon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final bool pending;
  final ValueChanged<bool>? onChanged;

  const _DeviceTile({
    required this.svgIcon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.pending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onChanged == null;

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
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
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF483912), width: 1),
              ),
              child: Center(
                child: Iconify(svgIcon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _CustomToggle(
              value: value,
              pending: pending,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final bool pending;
  final ValueChanged<bool>? onChanged;

  const _CustomToggle({
    required this.value,
    required this.pending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool interactive = onChanged != null && !pending;

    final Color bgColor = pending
        ? const Color(0xFFFFC107)
        : (value ? AppTheme.toggleOn : const Color(0xFFDDDDDD));

    return GestureDetector(
      onTap: interactive ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bgColor,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 26 : 2,
              top: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: pending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.only(
                        left: value ? 0 : 16,
                        right: value ? 16 : 0,
                      ),
                      child: Text(
                        value ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: value
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
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
