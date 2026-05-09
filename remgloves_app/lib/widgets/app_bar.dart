import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import 'connect-glove-dialog.dart';

class RemGloveAppBar extends StatefulWidget implements PreferredSizeWidget {
  final BleService ble;

  const RemGloveAppBar({super.key, required this.ble});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 52);

  @override
  State<RemGloveAppBar> createState() => _RemGloveAppBarState();
}

class _RemGloveAppBarState extends State<RemGloveAppBar> {
  late BleStatus _status;
  StreamSubscription<BleStatus>? _sub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _status = widget.ble.status;
    _sub = widget.ble.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      if (s == BleStatus.connected) {
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      } else {
        _ticker?.cancel();
        _ticker = null;
      }
    });
    if (_status == BleStatus.connected) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _onIndicatorTap() {
    if (_status != BleStatus.connected) {
      showConnectGloveDialog(context, widget.ble);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status == BleStatus.connected;
    final busy =
        _status == BleStatus.scanning || _status == BleStatus.connecting;

    final Color pillColor = connected
        ? AppTheme.connectionbox
        : busy
            ? AppTheme.primary.withValues(alpha: 0.55)
            : Colors.grey;

    final String pillLabel = connected
        ? 'Connected'
        : busy
            ? 'Scanning…'
            : 'Disconnected';

    return Container(
      color: AppTheme.primary,
      child: SafeArea(
        child: Column(
          children: [
            // ── Title row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SvgPicture.string(
                    '''
                    <svg xmlns="http://www.w3.org/2000/svg" width="38" height="45" viewBox="0 0 38 45" fill="none">
                    <path d="M15.298 12.9031C19.0973 10.6481 23.9303 11.9432 26.093 15.7957L31.4631 25.3621C33.6255 29.2149 32.2985 34.1666 28.4992 36.4217L23.9836 39.1014C22.8383 39.7811 21.599 40.1353 20.3674 40.1971C19.4903 41.3579 17.9094 41.7846 16.5256 41.1346L4.91425 35.6805C3.29408 34.9194 2.55974 32.9714 3.27362 31.3299C3.98764 29.6887 5.87918 28.9753 7.49921 29.7361L10.2912 31.0476L7.81952 26.6424C5.65694 22.7895 6.98394 17.8379 10.7834 15.5828L15.298 12.9031Z"
                    stroke="#483912" stroke-width="2" fill="none"/>
                    <path d="M28.5542 1.45686C33.3972 2.30665 36.6347 6.58973 35.7856 11.0234C35.5084 12.4704 34.828 13.7528 33.8717 14.7968C33.9118 14.6447 33.9492 14.491 33.9791 14.3348C34.8285 9.90099 31.1952 5.54769 25.8639 4.6122C23.4629 4.19091 21.1279 4.53688 19.2079 5.44685C20.989 2.48608 24.6979 0.780362 28.5542 1.45686Z"
                    fill="#483912"/>
                    </svg>
                    ''',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'RemGlove',
                    style: TextStyle(
                      color: AppTheme.logotext,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _onIndicatorTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            pillLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Device info row ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth,
                      color: AppTheme.textPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.ble.connectedDeviceId ?? '—',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.ble.connectedAt != null
                        ? _formatDuration(
                            DateTime.now().difference(widget.ble.connectedAt!))
                        : '—',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
