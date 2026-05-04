import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';

const String _tvIcon =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
    '<path fill="currentColor" d="M21 17H3V5h18m0-2H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>'
    '</svg>';

const String _fanIcon =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
    '<path fill="currentColor" d="M12 11a1 1 0 0 0-1 1a1 1 0 0 0 1 1a1 1 0 0 0 1-1a1 1 0 0 0-1-1m.5-9c4.5 0 4.61 3.57 2.25 4.75c-.99.49-1.43 1.54-1.62 2.47c.48.2.9.51 1.22.91c3.7-2 7.68-1.21 7.68 2.37c0 4.5-3.57 4.6-4.75 2.23c-.5-.99-1.56-1.43-2.49-1.62c-.2.48-.51.89-.91 1.23c1.99 3.69 1.2 7.66-2.38 7.66c-4.5 0-4.59-3.58-2.23-4.76c.98-.49 1.42-1.53 1.62-2.45c-.49-.2-.92-.52-1.24-.92C5.96 15.85 2 15.07 2 11.5C2 7 5.56 6.89 6.74 9.26c.5.99 1.55 1.42 2.48 1.61c.19-.48.51-.9.92-1.22C8.15 5.96 8.94 2 12.5 2"/>'
    '</svg>';

const String _lightIcon =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
    '<path fill="currentColor" d="M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7m3 18v1a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-1h6m-1-3H9v-1.97l.67-.41A5 5 0 0 0 12 4a5 5 0 0 0-5 5c0 1.88 1.04 3.56 2.67 4.44l.33.19V16h4v-.38l.33-.19A5.52 5.52 0 0 0 17 12.19V15z"/>'
    '</svg>';

const _fingerLabels = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];

String _inferDevice(String cmd) {
  final lower = cmd.toLowerCase();
  if (lower.startsWith('tv')) return 'tv';
  if (lower.startsWith('fan')) return 'fan';
  if (lower.startsWith('light')) return 'light';
  return 'general';
}

List<int>? _parseIntList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => (e as num).toInt()).toList();
  }
  return null;
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  StreamSubscription<DatabaseEvent>? _sub;
  List<_RtdbLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final ref = FirebaseDatabase.instance.ref('gestures');

    _sub = ref.orderByChild('t').limitToLast(100).onValue.listen((event) {
      final raw = event.snapshot.value;
      final parsed = <_RtdbLog>[];
      if (raw is Map) {
        raw.forEach((key, val) {
          if (val is Map) {
            final cmd = val['cmd'] as String? ?? '';
            parsed.add(_RtdbLog(
              message: cmd,
              timestamp: val['t'] as int? ?? 0,
              device: _inferDevice(cmd),
              calMin: _parseIntList(val['calMin']),
              calMax: _parseIntList(val['calMax']),
            ));
          }
        });
        parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      if (mounted) {
        setState(() {
          _logs = parsed;
          _loading = false;
        });
      }
    }, onError: (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RTDB error: $e')),
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _formatTimestamp(int ms) {
    if (ms == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $hour:$min $period';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'No logs yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ScrollbarTheme(
                          data: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all(
                                const Color(0xFFFDBF25)),
                            trackColor: WidgetStateProperty.all(
                                AppTheme.background),
                            trackBorderColor:
                                WidgetStateProperty.all(Colors.transparent),
                            thickness: WidgetStateProperty.all(10),
                            radius: const Radius.circular(10),
                            trackVisibility: WidgetStateProperty.all(true),
                            thumbVisibility: WidgetStateProperty.all(true),
                            crossAxisMargin: 8,
                            mainAxisMargin: 8,
                          ),
                          child: Scrollbar(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 36, bottom: 16),
                              itemCount: _logs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _LogTile(
                                  log: log,
                                  time: _formatTimestamp(log.timestamp),
                                );
                              },
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

class _RtdbLog {
  final String message;
  final int timestamp;
  final String device;
  final List<int>? calMin;
  final List<int>? calMax;

  const _RtdbLog({
    required this.message,
    required this.timestamp,
    required this.device,
    this.calMin,
    this.calMax,
  });
}

class _LogTile extends StatelessWidget {
  final _RtdbLog log;
  final String time;

  const _LogTile({required this.log, required this.time});

  String _icon() {
    switch (log.device) {
      case 'tv':
        return _tvIcon;
      case 'fan':
        return _fanIcon;
      case 'light':
        return _lightIcon;
      default:
        return AppIcons.chartLine;
    }
  }

  Color _color() {
    switch (log.device) {
      case 'tv':
        return const Color(0xFFF5A623);
      case 'fan':
        return const Color(0xFF29B6F6);
      case 'light':
        return const Color(0xFFF5A623);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon();
    final color = _color();
    final hasCalibration =
        log.calMin != null && log.calMax != null &&
        log.calMin!.length == 5 && log.calMax!.length == 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF483912), width: 1),
            ),
            child: Center(
              child: Iconify(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (hasCalibration) ...[
                  const SizedBox(height: 6),
                  _CalRow(label: 'Min', values: log.calMin!, color: color),
                  const SizedBox(height: 3),
                  _CalRow(label: 'Max', values: log.calMax!, color: color),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalRow extends StatelessWidget {
  final String label;
  final List<int> values;
  final Color color;

  const _CalRow({
    required this.label,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fingerLabels[i],
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${values[i]}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
