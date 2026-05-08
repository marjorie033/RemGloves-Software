import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calibration_data.dart';
import '../models/glove_profile.dart';
import '../services/ble_service.dart';
import '../services/profile_service.dart';
import '../widgets/calibration_dialog.dart';
import 'serial_monitor_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';
import '../theme/app_icons.dart';

const String _prefAutoConnect = 'auto_connect_glove';
const String _prefWifiSsid   = 'wifi_ssid';

class SettingsScreen extends StatefulWidget {
  final BleService ble;

  const SettingsScreen({super.key, required this.ble});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BleStatus _bleStatus = BleStatus.idle;
  bool _autoConnect = false;

  final _profileService = ProfileService();
  CalibrationData? _activeCalibration;
  int _profileCount = 0;
  String? _savedSsid;

  StreamSubscription<BleStatus>? _bleSub;
  StreamSubscription<CalibrationData>? _calSub;

  @override
  void initState() {
    super.initState();
    _bleStatus = widget.ble.status;
    _bleSub = widget.ble.statusStream.listen((s) {
      if (mounted) setState(() => _bleStatus = s);
    });
    _calSub = widget.ble.calibrationStream.listen((cal) {
      if (mounted) setState(() => _activeCalibration = cal);
    });
    _loadPrefs();
    _refreshProfileCount();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _calSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshProfileCount() async {
    final profiles = await _profileService.loadAll();
    if (mounted) setState(() => _profileCount = profiles.length);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoConnect = prefs.getBool(_prefAutoConnect) ?? false;
      _savedSsid   = prefs.getString(_prefWifiSsid);
    });
  }

  Future<void> _onWifiConnected(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefWifiSsid, ssid);
    if (mounted) setState(() => _savedSsid = ssid);
  }

  void _showCalibrationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalibrationSheet(
        ble: widget.ble,
        profileService: _profileService,
        activeCalibration: _activeCalibration,
        onProfilesChanged: _refreshProfileCount,
      ),
    );
  }

  void _showWifiConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WifiConfigSheet(
        ble: widget.ble,
        currentSsid: _savedSsid,
        onConnected: _onWifiConnected,
      ),
    );
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
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.tune,
                    iconColor: AppTheme.primary,
                    title: 'Calibration Presets',
                    subtitle: _profileCount == 0
                        ? 'No presets saved'
                        : '$_profileCount preset${_profileCount == 1 ? '' : 's'} saved',
                    onTap: () => _showCalibrationSheet(context),
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
                    icon: Icons.wifi,
                    iconColor: AppTheme.primary,
                    title: 'WiFi Configuration',
                    subtitle: _savedSsid != null
                        ? 'Connected to "$_savedSsid"'
                        : 'Not configured',
                    onTap: () => _showWifiConfigSheet(context),
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
                    icon: Icons.terminal,
                    iconColor: AppTheme.primary,
                    title: 'Serial Monitor',
                    subtitle: 'Debug — live LOG: messages from glove',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SerialMonitorScreen(ble: widget.ble),
                      ),
                    ),
                  ),
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
    // Bit order: Pinky(4) Ring(3) Middle(2) Index(1) Thumb(0) — 1=bent, 0=straight
    // Each entry: [gesture label, 5-bit string, action text, icon]
    const sections = [
      {
        'title': 'TV Remote',
        'items': [
          ["ASL 'D'",   '11101', 'Navigate UP',   AppIcons.pointUp  ],
          ["ASL '2'",   '11001', 'Navigate DOWN', AppIcons.thumbsDown],
          ["ASL 'F'",   '00011', 'Navigate LEFT', AppIcons.tv       ],
          ["ASL 'B'",   '00001', 'Navigate RIGHT',AppIcons.tv       ],
          ["ASL 'I'",   '01111', 'OK / Select',   AppIcons.peaceSign],
          ["ASL 'K'",   '11000', 'Volume UP',     AppIcons.thumbsUp ],
          ["ASL 'L'",   '11100', 'Volume DOWN',   AppIcons.thumbsDown],
          ['Fist',      '11111', 'Back',          AppIcons.fist     ],
          ["ASL 'W'",   '10001', 'Home',          AppIcons.handOpen ],
          ["ASL 'Y'",   '01110', 'Netflix',       AppIcons.netflix  ],
          ['Middle only','00100','TV Power ON',   AppIcons.tv       ],
        ],
      },
      {
        'title': 'Smart Light',
        'items': [
          ['Ring + Thumb',        '01001', 'Light ON',  AppIcons.lightbulb],
          ['Ring + Middle + Thumb','01101','Light OFF', AppIcons.lightbulb],
        ],
      },
      {
        'title': 'Smart Fan',
        'items': [
          ['P + R + M + Index', '11110', 'Fan ON',  AppIcons.fan],
          ['Ring + Middle',     '01100', 'Fan OFF', AppIcons.fan],
        ],
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
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
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text('Gesture Guide',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Spacer(),
                  Text('P  R  M  I  T',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        (section['title'] as String).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    for (final item in section['items'] as List) ...[
                      _GestureRow(
                        label:  item[0] as String,
                        bits:   item[1] as String,
                        action: item[2] as String,
                        icon:   item[3] as String,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ],
              ),
            ),
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

// ── Calibration bottom sheet ──────────────────────────────────────────────────

class _CalibrationSheet extends StatefulWidget {
  final BleService ble;
  final ProfileService profileService;
  final CalibrationData? activeCalibration;
  final VoidCallback onProfilesChanged;

  const _CalibrationSheet({
    required this.ble,
    required this.profileService,
    required this.activeCalibration,
    required this.onProfilesChanged,
  });

  @override
  State<_CalibrationSheet> createState() => _CalibrationSheetState();
}

class _CalibrationSheetState extends State<_CalibrationSheet> {
  List<GloveProfile> _profiles = [];
  GloveProfile? _lastCal;
  bool _calibrating = false;
  CalibrationData? _pendingCal;
  StreamSubscription<CalibrationData>? _calSub;
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  // Load-confirmation tracking
  String? _loadingPreset;  // name of the preset currently being loaded
  String? _resultPreset;   // name of the preset whose result is showing
  bool?   _loadResult;     // true = success, false = timeout/fail
  Timer?  _loadTimeout;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _calSub = widget.ble.calibrationStream.listen(_onCal);
  }

  @override
  void dispose() {
    _calSub?.cancel();
    _loadTimeout?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await widget.profileService.loadAll();
    final lastCal  = await widget.profileService.loadLastCalibration();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _lastCal  = lastCal;
    });
  }

  void _onCal(CalibrationData data) {
    if (!mounted) return;
    _loadTimeout?.cancel();
    if (_loadingPreset != null) {
      // This is a LOAD: echo — show success on that tile.
      final name = _loadingPreset!;
      setState(() {
        _loadingPreset = null;
        _resultPreset  = name;
        _loadResult    = true;
        _calibrating   = false;
      });
      _loadProfiles(); // refresh last-cal timestamp
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _resultPreset = null; _loadResult = null; });
      });
    } else {
      // This is a fresh calibration result — show the save-as-preset form.
      setState(() {
        _calibrating = false;
        _pendingCal  = data;
        _nameCtrl.text = 'Preset ${_profiles.length + 1}';
      });
      _loadProfiles(); // refresh last-cal entry
    }
  }

  Future<void> _recalibrate() async {
    // Auto-backup the current active calibration before overwriting it.
    if (widget.activeCalibration != null) {
      final now  = DateTime.now();
      final name = 'Backup ${now.month}/${now.day} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';
      await widget.profileService.save(GloveProfile(
        name: name,
        calibration: widget.activeCalibration!,
        savedAt: now,
      ));
      await _loadProfiles();
      widget.onProfilesChanged();
    }
    setState(() { _calibrating = true; _pendingCal = null; });
    await widget.ble.startCalibration();

    if (!mounted) return;
    await showCalibrationProgressDialog(context, widget.ble);
    if (mounted) setState(() => _calibrating = false);
  }

  Future<void> _savePreset() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _pendingCal == null) return;
    setState(() => _saving = true);
    await widget.profileService.save(GloveProfile(
      name: name,
      calibration: _pendingCal!,
      savedAt: DateTime.now(),
    ));
    setState(() { _saving = false; _pendingCal = null; });
    await _loadProfiles();
    widget.onProfilesChanged();
  }

  Future<void> _loadPreset(GloveProfile p) async {
    setState(() { _loadingPreset = p.name; _resultPreset = null; _loadResult = null; });
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() { _loadingPreset = null; _resultPreset = p.name; _loadResult = false; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _resultPreset = null; _loadResult = null; });
      });
    });
    await widget.ble.loadProfile(p.calibration);
  }

  Future<void> _deletePreset(GloveProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('Remove "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.profileService.delete(p.name);
    await _loadProfiles();
    widget.onProfilesChanged();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.ble.status == BleStatus.connected;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Calibration Presets',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: (!connected || _calibrating) ? null : _recalibrate,
                  icon: _calibrating
                      ? const SizedBox(
                          width: 13, height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync, size: 15),
                  label: Text(_calibrating ? 'Calibrating…' : 'Recalibrate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // ── Glove-not-connected warning ───────────────────────────────
          if (!connected)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 5),
                  Text(
                    'Connect your glove to recalibrate',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),

          // ── Save new preset form (appears after CAL: received) ───────
          if (_pendingCal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F9EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2E9E5B).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 15, color: Color(0xFF2E9E5B)),
                        SizedBox(width: 6),
                        Text(
                          'Calibration complete!',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF2E9E5B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Preset name',
                        labelStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _savePreset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          _saving ? 'Saving…' : 'Save as Preset',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Saved presets label ──────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'SAVED PRESETS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // ── Preset list ──────────────────────────────────────────────
          Expanded(
            child: (_lastCal == null && _profiles.isEmpty)
                ? const Center(
                    child: Text(
                      'No presets saved yet.\nRecalibrate to create your first preset.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Pinned "Last Calibration" — always first, never deletable
                      if (_lastCal != null) ...[
                        _PresetTile(
                          profile:   _lastCal!,
                          canLoad:   connected,
                          pinned:    true,
                          isLoading: _loadingPreset == ProfileService.lastCalName,
                          loadResult: _resultPreset == ProfileService.lastCalName
                              ? _loadResult : null,
                          onLoad:   () => _loadPreset(_lastCal!),
                          onDelete: null,
                        ),
                        if (_profiles.isNotEmpty)
                          const SizedBox(height: 8),
                      ],
                      // Named presets
                      ..._profiles.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PresetTile(
                          profile:    p,
                          canLoad:    connected,
                          pinned:     false,
                          isLoading:  _loadingPreset == p.name,
                          loadResult: _resultPreset == p.name
                              ? _loadResult : null,
                          onLoad:   () => _loadPreset(p),
                          onDelete: () => _deletePreset(p),
                        ),
                      )),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Preset tile ───────────────────────────────────────────────────────────────

class _PresetTile extends StatelessWidget {
  final GloveProfile profile;
  final bool canLoad;
  final bool pinned;        // true = "Last Calibration" — no delete button
  final bool isLoading;     // LOAD: in flight
  final bool? loadResult;   // null = idle, true = success, false = fail
  final VoidCallback onLoad;
  final VoidCallback? onDelete;

  const _PresetTile({
    required this.profile,
    required this.canLoad,
    required this.pinned,
    required this.isLoading,
    required this.loadResult,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Result colour used for both the icon badge and the border flash.
    final Color? resultColor = loadResult == null
        ? null
        : loadResult!
            ? const Color(0xFF2E9E5B)
            : Colors.red.shade600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: resultColor ?? const Color(0xFF483912),
          width: resultColor != null ? 1.5 : 1,
        ),
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
          // ── Icon badge ─────────────────────────────────────────────
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (resultColor ?? AppTheme.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF483912)),
            ),
            child: Icon(
              pinned ? Icons.history : Icons.tune,
              color: resultColor ?? AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // ── Name + timestamp ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: resultColor ?? AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (pinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('AUTO',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _fmt(profile.savedAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // ── Delete button (hidden for pinned) ───────────────────────
          if (!pinned && onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 28, height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 15, color: Colors.red),
              ),
            ),

          // ── Load button / spinner / result icon ─────────────────────
          SizedBox(
            width: 56,
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                  )
                : loadResult != null
                    ? Center(
                        child: Icon(
                          loadResult!
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 20,
                          color: resultColor,
                        ),
                      )
                    : TextButton(
                        onPressed: canLoad ? onLoad : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          disabledForegroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                                color: canLoad
                                    ? AppTheme.primary
                                    : Colors.grey.shade300),
                          ),
                        ),
                        child: const Text('Load',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Gesture guide row ─────────────────────────────────────────────────────────

class _GestureRow extends StatelessWidget {
  final String label;   // e.g. "ASL 'D'"
  final String bits;    // 5-char binary string, MSB=Pinky, LSB=Thumb
  final String action;  // e.g. "Navigate UP"
  final String icon;    // AppIcons constant

  const _GestureRow({
    required this.label,
    required this.bits,
    required this.action,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF483912)),
            ),
            child: Center(
              child: Icon(_iconData(icon), color: AppTheme.primary, size: 18),
            ),
          ),
          const SizedBox(width: 10),

          // Label + action
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppTheme.textPrimary)),
                Text(action,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),

          // Finger-pattern dots (● = bent, ○ = straight)
          Row(
            children: List.generate(5, (i) {
              final bent = bits[i] == '1';
              return Container(
                width: 14, height: 14,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bent
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.0),
                  border: Border.all(
                    color: bent
                        ? AppTheme.primary
                        : Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Map AppIcons SVG strings back to a Material icon for display without Iconify.
  IconData _iconData(String svgConst) {
    if (svgConst == AppIcons.lightbulb)   return Icons.lightbulb_outline;
    if (svgConst == AppIcons.fan)          return Icons.air;
    if (svgConst == AppIcons.tv)           return Icons.tv_outlined;
    if (svgConst == AppIcons.netflix)      return Icons.play_circle_outline;
    if (svgConst == AppIcons.thumbsUp)     return Icons.thumb_up_outlined;
    if (svgConst == AppIcons.thumbsDown)   return Icons.thumb_down_outlined;
    if (svgConst == AppIcons.fist)         return Icons.back_hand_outlined;
    if (svgConst == AppIcons.handOpen)     return Icons.pan_tool_outlined;
    if (svgConst == AppIcons.pointUp)      return Icons.touch_app_outlined;
    if (svgConst == AppIcons.peaceSign)    return Icons.front_hand_outlined;
    return Icons.gesture;
  }
}

// ── WiFi config sheet ─────────────────────────────────────────────────────────

enum _WifiState { idle, sending, success, fail }

class _WifiConfigSheet extends StatefulWidget {
  final BleService ble;
  final String? currentSsid;
  final ValueChanged<String> onConnected;

  const _WifiConfigSheet({
    required this.ble,
    required this.currentSsid,
    required this.onConnected,
  });

  @override
  State<_WifiConfigSheet> createState() => _WifiConfigSheetState();
}

class _WifiConfigSheetState extends State<_WifiConfigSheet> {
  final _ssidCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _obscurePass = true;
  _WifiState _state = _WifiState.idle;
  StreamSubscription<String>? _wifiSub;

  bool get _pipeInPassword => _passCtrl.text.contains('|');
  bool get _connected       => widget.ble.status == BleStatus.connected;

  @override
  void initState() {
    super.initState();
    if (widget.currentSsid != null) _ssidCtrl.text = widget.currentSsid!;
    _passCtrl.addListener(() => setState(() {}));
    _wifiSub = widget.ble.wifiStream.listen(_onWifiResult);
  }

  @override
  void dispose() {
    _wifiSub?.cancel();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onWifiResult(String result) {
    if (!mounted) return;
    setState(() => _state =
        result == 'OK' ? _WifiState.success : _WifiState.fail);
    if (_state == _WifiState.success) {
      widget.onConnected(_ssidCtrl.text.trim());
    }
  }

  Future<void> _send() async {
    final ssid = _ssidCtrl.text.trim();
    final pass = _passCtrl.text;
    if (ssid.isEmpty) return;
    setState(() => _state = _WifiState.sending);
    await widget.ble.sendWifiCredentials(ssid, pass);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _connected &&
        _ssidCtrl.text.trim().isNotEmpty &&
        !_pipeInPassword &&
        _state != _WifiState.sending;

    return Padding(
      // Shift sheet up when keyboard appears.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFF483912)),
                ),
                child: const Icon(Icons.wifi,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'WiFi Configuration',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ]),
            const SizedBox(height: 6),

            // ── Current network badge ────────────────────────────────
            if (widget.currentSsid != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(children: [
                  const Icon(Icons.check_circle,
                      size: 13, color: Color(0xFF2E9E5B)),
                  const SizedBox(width: 5),
                  Text(
                    'Glove is on "${widget.currentSsid}"',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF2E9E5B)),
                  ),
                ]),
              ),
            const SizedBox(height: 18),

            // ── Not-connected warning ────────────────────────────────
            if (!_connected)
              _InfoBanner(
                icon: Icons.bluetooth_disabled,
                color: Colors.orange.shade700,
                message: 'Connect your glove via Bluetooth first.',
              ),

            // ── SSID field ───────────────────────────────────────────
            _sheetLabel('Network name (SSID)'),
            const SizedBox(height: 6),
            TextField(
              controller: _ssidCtrl,
              enabled: _state != _WifiState.sending,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecor('e.g. HomeNetwork'),
            ),
            const SizedBox(height: 14),

            // ── Password field ───────────────────────────────────────
            _sheetLabel('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _passCtrl,
              enabled: _state != _WifiState.sending,
              obscureText: _obscurePass,
              decoration: _fieldDecor('Enter password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),

            // ── Pipe character warning ───────────────────────────────
            if (_pipeInPassword)
              _InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                message:
                    'Password contains "|" which is a reserved separator. '
                    'Please use a different password.',
                topPadding: 10,
              ),

            const SizedBox(height: 20),

            // ── Status feedback ──────────────────────────────────────
            if (_state == _WifiState.success)
              _InfoBanner(
                icon: Icons.check_circle,
                color: const Color(0xFF2E9E5B),
                message:
                    'Connected! Glove is now on "${_ssidCtrl.text.trim()}".',
              ),
            if (_state == _WifiState.fail)
              _InfoBanner(
                icon: Icons.error_outline,
                color: Colors.red.shade700,
                message: 'Connection failed. Check the SSID and password'
                    ' and try again.',
              ),

            const SizedBox(height: 6),

            // ── Connect button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSend ? _send : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _state == _WifiState.success
                      ? const Color(0xFF2E9E5B)
                      : AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _state == _WifiState.sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _state == _WifiState.fail
                            ? 'Retry'
                            : 'Connect',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
      );

  InputDecoration _fieldDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      );
}

// ── Reusable info / warning banner ────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final double topPadding;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.topPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10, top: topPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
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
