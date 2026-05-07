import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';
import '../services/ai_summary_service.dart';

const String _tvIcon = AppIcons.tv;

const String _fanIcon = AppIcons.fan;

const String _lightIcon = AppIcons.lightbulb;

const _fingerLabels = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];

// ── Range options ─────────────────────────────────────────────────────────────

enum _Range { day, week, month }

extension _RangeLabel on _Range {
  String get label {
    switch (this) {
      case _Range.day:
        return 'Today';
      case _Range.week:
        return '7 Days';
      case _Range.month:
        return '30 Days';
    }
  }

  int get milliseconds {
    switch (this) {
      case _Range.day:
        return const Duration(days: 1).inMilliseconds;
      case _Range.week:
        return const Duration(days: 7).inMilliseconds;
      case _Range.month:
        return const Duration(days: 30).inMilliseconds;
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _inferDevice(String cmd) {
  final lower = cmd.toLowerCase();
  if (lower.startsWith('tv')) return 'TV';
  if (lower.startsWith('fan')) return 'Fan';
  if (lower.startsWith('light')) return 'Light';
  return 'General';
}

List<int>? _parseIntList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => (e as num).toInt()).toList();
  }
  return null;
}

// ── Data model ────────────────────────────────────────────────────────────────

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

// ── Summary cache (per range, lives for the day) ─────────────────────────────

class _SummaryCache {
  final String summary;
  final DateTime fetchedAt;
  final int logCount;
  final Map<String, int> deviceCounts;
  final int calibrationCount;

  _SummaryCache({
    required this.summary,
    required this.fetchedAt,
    required this.logCount,
    required this.deviceCounts,
    required this.calibrationCount,
  });

  bool get isToday {
    final now = DateTime.now();
    return fetchedAt.year == now.year &&
        fetchedAt.month == now.month &&
        fetchedAt.day == now.day;
  }

  String get fetchedAtLabel {
    final h = fetchedAt.hour > 12
        ? fetchedAt.hour - 12
        : (fetchedAt.hour == 0 ? 12 : fetchedAt.hour);
    final period = fetchedAt.hour >= 12 ? 'PM' : 'AM';
    final m = fetchedAt.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  // Live feed (last 100)
  StreamSubscription<DatabaseEvent>? _sub;
  List<_RtdbLog> _logs = [];
  bool _logsLoading = true;

  // Analytics
  _Range _selectedRange = _Range.week;
  final Map<_Range, _SummaryCache> _cache = {};
  bool _summaryLoading = false;
  String? _summaryError;
  final Set<_Range> _upToDateRanges = {};

  _SummaryCache? get _currentCache => _cache[_selectedRange];
  bool get _isUpToDate => _upToDateRanges.contains(_selectedRange);

  @override
  void initState() {
    super.initState();
    _startLiveFeed();
    _autoLoadIfNeeded();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Live feed (real-time, last 100) ────────────────────────────────────────

  void _startLiveFeed() {
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
          _logsLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) {
        setState(() => _logsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RTDB error: $e')),
        );
      }
    });
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  // Called on init: only fetches if no today's cache exists for this range.
  void _autoLoadIfNeeded() {
    final cached = _cache[_selectedRange];
    if (cached == null || !cached.isToday) {
      _doFetch(checkForChanges: false);
    }
  }

  // Called by the manual refresh button.
  Future<void> _refreshAnalytics() async {
    _doFetch(checkForChanges: true);
  }

  Future<void> _doFetch({required bool checkForChanges}) async {
    if (_summaryLoading) return;
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final start = now - _selectedRange.milliseconds;

      final ref = FirebaseDatabase.instance.ref('gestures');
      final snapshot =
          await ref.orderByChild('t').startAt(start).endAt(now).get();

      final raw = snapshot.value;
      final deviceCounts = <String, int>{};
      final commandCounts = <String, int>{};
      int total = 0;
      int calibrations = 0;

      if (raw is Map) {
        raw.forEach((_, val) {
          if (val is Map) {
            total++;
            final cmd = val['cmd'] as String? ?? '';
            final device = _inferDevice(cmd);
            deviceCounts[device] = (deviceCounts[device] ?? 0) + 1;
            if (cmd.isNotEmpty) {
              commandCounts[cmd] = (commandCounts[cmd] ?? 0) + 1;
            }
            if (val['calMin'] != null) calibrations++;
          }
        });
      }

      if (!mounted) return;

      // If manual refresh and count hasn't changed — no need to call Gemini.
      if (checkForChanges) {
        final cached = _cache[_selectedRange];
        if (cached != null && cached.logCount == total) {
          setState(() {
            _summaryLoading = false;
            _upToDateRanges.add(_selectedRange);
          });
          return;
        }
      }

      if (total == 0) {
        setState(() {
          _cache[_selectedRange] = _SummaryCache(
            summary: 'No gestures recorded in this period.',
            fetchedAt: DateTime.now(),
            logCount: 0,
            deviceCounts: {},
            calibrationCount: 0,
          );
          _upToDateRanges.remove(_selectedRange);
          _summaryLoading = false;
        });
        return;
      }

      final summaryText = await AiSummaryService.summarize(LogSummaryInput(
        totalCount: total,
        deviceCounts: deviceCounts,
        commandCounts: commandCounts,
        calibrationCount: calibrations,
        rangeStart: DateTime.fromMillisecondsSinceEpoch(start),
        rangeEnd: DateTime.fromMillisecondsSinceEpoch(now),
      ));

      if (mounted) {
        setState(() {
          _cache[_selectedRange] = _SummaryCache(
            summary: summaryText,
            fetchedAt: DateTime.now(),
            logCount: total,
            deviceCounts: deviceCounts,
            calibrationCount: calibrations,
          );
          _upToDateRanges.remove(_selectedRange);
          _summaryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = e.toString();
          _summaryLoading = false;
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  Color _deviceColor(String device) {
    switch (device) {
      case 'TV':
        return const Color(0xFFF5A623);
      case 'Fan':
        return const Color(0xFF29B6F6);
      case 'Light':
        return const Color(0xFFFDD835);
      default:
        return AppTheme.primary;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RemGloveAppBar(),
      backgroundColor: AppTheme.primary,
      body: RoundedBody(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildAnalyticsSection()),
            SliverToBoxAdapter(child: _buildHistoryHeader()),
            _buildLogsList(),
          ],
        ),
      ),
    );
  }

  // ── Analytics section ──────────────────────────────────────────────────────

  Widget _buildAnalyticsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsHeader(),
          const SizedBox(height: 12),
          _buildRangeChips(),
          const SizedBox(height: 12),
          if ((_currentCache?.logCount ?? 0) > 0) ...[
            _buildStatRow(),
            const SizedBox(height: 12),
          ],
          _buildSummaryCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Row(
      children: [
        const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        if (_summaryLoading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          )
        else if (_isUpToDate)
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Colors.green)
        else
          GestureDetector(
            onTap: _refreshAnalytics,
            child: const Icon(Icons.refresh_rounded,
                size: 20, color: AppTheme.textSecondary),
          ),
      ],
    );
  }

  Widget _buildRangeChips() {
    return Row(
      children: _Range.values.map((range) {
        final selected = range == _selectedRange;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              if (!selected) {
                setState(() => _selectedRange = range);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.textPrimary,
                ),
              ),
              child: Text(
                range.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatRow() {
    final cache = _currentCache;
    final deviceCounts = cache?.deviceCounts ?? {};
    final topDevice = deviceCounts.entries.isEmpty
        ? null
        : (deviceCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;

    return Row(
      children: [
        _StatChip(
          label: 'Total',
          value: '${cache?.logCount ?? 0}',
          color: AppTheme.primary,
        ),
        const SizedBox(width: 8),
        if (topDevice != null) ...[
          _StatChip(
            label: 'Top Device',
            value: topDevice.key,
            color: _deviceColor(topDevice.key),
          ),
          const SizedBox(width: 8),
        ],
        _StatChip(
          label: 'Calibrations',
          value: '${cache?.calibrationCount ?? 0}',
          color: Colors.purple.shade300,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF483912), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _summaryLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                    SizedBox(height: 8),
                    Text(
                      'Generating summary…',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : _summaryError != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Could not load summary.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summaryError!,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _refreshAnalytics,
                      child: const Text(
                        'Tap to retry',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              : _currentCache == null
                  ? Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Tap ↻ to generate your first summary for this period.',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isUpToDate
                                  ? Icons.check_circle_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 14,
                              color: _isUpToDate
                                  ? Colors.green
                                  : AppTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isUpToDate
                                  ? 'Up to date · ${_selectedRange.label}'
                                  : 'AI Summary · ${_selectedRange.label}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isUpToDate
                                    ? Colors.green
                                    : AppTheme.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Updated ${_currentCache!.fetchedAtLabel}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentCache!.summary,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                              height: 1.5),
                        ),
                      ],
                    ),
    );
  }

  // ── History section ────────────────────────────────────────────────────────

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  SliverList _buildLogsList() {
    if (_logsLoading) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ),
        ]),
      );
    }

    if (_logs.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No logs yet.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _logs.length) {
            return const SizedBox(height: 16);
          }
          final log = _logs[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _LogTile(
              log: log,
              time: _formatTimestamp(log.timestamp),
            ),
          );
        },
        childCount: _logs.length + 1,
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color == AppTheme.primary ? AppTheme.primary : color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Log tile ──────────────────────────────────────────────────────────────────

class _LogTile extends StatefulWidget {
  final _RtdbLog log;
  final String time;

  const _LogTile({required this.log, required this.time});

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  String _icon() {
    switch (widget.log.device) {
      case 'TV':
        return _tvIcon;
      case 'Fan':
        return _fanIcon;
      case 'Light':
        return _lightIcon;
      default:
        return AppIcons.chartLine;
    }
  }

  Color _color() {
    switch (widget.log.device) {
      case 'TV':
        return const Color(0xFFF5A623);
      case 'Fan':
        return const Color(0xFF29B6F6);
      case 'Light':
        return const Color(0xFFF5A623);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final hasCalibration = widget.log.calMin != null &&
        widget.log.calMax != null &&
        widget.log.calMin!.length == 5 &&
        widget.log.calMax!.length == 5;

    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: hasCalibration ? _toggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF483912), width: 1),
                    ),
                    child: Center(
                      child: Iconify(_icon(), color: color, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.log.message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasCalibration) ...[
                        const SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _expandAnim,
                          builder: (_, _) => Transform.rotate(
                            angle: _expandAnim.value * 3.14159,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (hasCalibration)
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: const Color(0xFF483912).withValues(alpha: 0.2),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calibration',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _CalTable(
                          calMin: widget.log.calMin!,
                          calMax: widget.log.calMax!,
                          color: color,
                        ),
                      ],
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

// ── Calibration table ─────────────────────────────────────────────────────────

class _CalTable extends StatelessWidget {
  final List<int> calMin;
  final List<int> calMax;
  final Color color;

  const _CalTable({
    required this.calMin,
    required this.calMax,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: IntrinsicColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            const SizedBox(),
            ..._fingerLabels.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  f,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ],
        ),
        _buildRow('Min', calMin, color),
        _buildRow('Max', calMax, color),
      ],
    );
  }

  TableRow _buildRow(String label, List<int> values, Color labelColor) {
    return TableRow(
      decoration: BoxDecoration(
        color: labelColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
        ...values.map(
          (v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '$v',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
