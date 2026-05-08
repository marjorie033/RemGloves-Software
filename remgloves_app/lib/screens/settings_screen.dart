import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';
import '../theme/app_icons.dart';

const String _prefAutoConnect = 'auto_connect_glove';

class SettingsScreen extends StatefulWidget {
  final BleService ble;

  const SettingsScreen({super.key, required this.ble});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BleStatus _bleStatus = BleStatus.idle;
  bool _autoConnect = false;

  StreamSubscription<BleStatus>? _bleSub;

  @override
  void initState() {
    super.initState();
    _bleStatus = widget.ble.status;
    _bleSub = widget.ble.statusStream.listen((s) {
      if (mounted) setState(() => _bleStatus = s);
    });
    _loadPrefs();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _autoConnect = prefs.getBool(_prefAutoConnect) ?? false);
  }

  Future<void> _setAutoConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoConnect, value);
    if (mounted) setState(() => _autoConnect = value);
    if (value && _bleStatus == BleStatus.idle) {
      widget.ble.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RemGloveAppBar(ble: widget.ble),
      backgroundColor: AppTheme.primary,
      body: RoundedBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'More',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                children: [
                  const SizedBox(height: 4),

                  // ── Glove ────────────────────────────────────────────
                  const _SectionHeader(title: 'Glove'),
                  const SizedBox(height: 10),
                  _GloveConnectionTile(
                    status: _bleStatus,
                    onConnect: widget.ble.connect,
                    onDisconnect: widget.ble.disconnect,
                  ),
                  const SizedBox(height: 10),
                  _ConnectivityTile(
                    icon: Icons.bluetooth_searching,
                    iconColor: Colors.blue,
                    bgColor: Colors.blue.withValues(alpha: 0.1),
                    title: 'Auto-connect on Startup',
                    value: _autoConnect,
                    onChanged: _setAutoConnect,
                  ),
                  const SizedBox(height: 20),

                  // ── Account ──────────────────────────────────────────
                  const _SectionHeader(title: 'Account'),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.person_outline,
                    iconColor: AppTheme.primary,
                    title: 'User Profile',
                    subtitle: 'RemGlove Admin',
                    trailing: const Icon(Icons.insert_drive_file_outlined, size: 20, color: AppTheme.textSecondary),
                    onTap: () => _showUserProfileSheet(context),
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.pan_tool_alt_outlined,
                    iconColor: AppTheme.primary,
                    title: 'Gesture Guide',
                    onTap: () => _showGestureGuideSheet(context),
                  ),
                  const SizedBox(height: 20),

                  // ── About ─────────────────────────────────────────────
                  const _SectionHeader(title: 'About'),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    iconColor: AppTheme.primary,
                    title: 'App Version',
                    subtitle: 'v1.0.0',
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppTheme.primary,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.logout,
                    iconColor: Colors.red,
                    title: 'Sign Out',
                    titleColor: Colors.red,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.person, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            const Text('RemGlove Admin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Text('admin@remglove.com',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            _ProfileField(label: 'Full Name', value: 'RemGlove Admin'),
            const SizedBox(height: 12),
            _ProfileField(label: 'Device ID', value: 'RG-2024-001'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Edit Profile',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showGestureGuideSheet(BuildContext context) {
    final gestures = [
      {'gesture': 'Open Palm',    'action': 'Turn ON Smart Light',  'icon': AppIcons.handOpen,   'color': AppTheme.primary},
      {'gesture': 'Closed Fist',  'action': 'Turn OFF Smart Light', 'icon': AppIcons.fist,       'color': AppTheme.primary},
      {'gesture': 'Thumbs Up',    'action': 'Increase Fan Speed',   'icon': AppIcons.thumbsUp,   'color': AppTheme.primary},
      {'gesture': 'Thumbs Down',  'action': 'Decrease Fan Speed',   'icon': AppIcons.thumbsDown, 'color': AppTheme.primary},
      {'gesture': 'Peace Sign',   'action': 'Turn ON TV',           'icon': AppIcons.peaceSign,  'color': AppTheme.primary},
      {'gesture': 'Point Up',     'action': 'Volume Up',            'icon': AppIcons.pointUp,    'color': AppTheme.primary},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Gesture Guide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: gestures.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final color = gestures[i]['color'] as Color;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF483912), width: 1),
                      ),
                      child: Center(
                        child: Iconify(gestures[i]['icon'] as String, color: color, size: 22),
                      ),
                    ),
                    title: Text(gestures[i]['gesture'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(gestures[i]['action'] as String,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Glove connection tile ─────────────────────────────────────────────────────

class _GloveConnectionTile extends StatelessWidget {
  final BleStatus status;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _GloveConnectionTile({
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final connected = status == BleStatus.connected;
    final busy = status == BleStatus.scanning || status == BleStatus.connecting;

    final dotColor = connected
        ? AppTheme.toggleOn
        : busy
            ? AppTheme.primary
            : Colors.grey;

    final statusText = {
      BleStatus.idle:         'Not connected',
      BleStatus.scanning:     'Scanning for RemGloves…',
      BleStatus.connecting:   'Connecting…',
      BleStatus.connected:    'Connected to RemGloves',
      BleStatus.disconnected: 'Disconnected',
      BleStatus.error:        'Connection error',
    }[status]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF483912), width: 1),
            ),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RemGloves',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            )
          else
            TextButton(
              onPressed: connected ? onDisconnect : onConnect,
              style: TextButton.styleFrom(
                foregroundColor: connected ? Colors.red : AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: connected ? Colors.red : AppTheme.primary),
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
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF483912), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF483912), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: titleColor ?? AppTheme.textPrimary,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary, size: 20)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

// ── Connectivity tile (auto-connect toggle) ───────────────────────────────────

class _ConnectivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConnectivityTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF483912), width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary)),
          ),
          _SmallToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Small toggle ──────────────────────────────────────────────────────────────

class _SmallToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SmallToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48, height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? AppTheme.toggleOn : const Color(0xFFDDDDDD),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 23 : 2,
              top: 2,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile field ─────────────────────────────────────────────────────────────

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ],
    );
  }
}
