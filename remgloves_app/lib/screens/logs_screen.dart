import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _controller = TextEditingController();
  final _collection = FirebaseFirestore.instance.collection('logs');
  List<_FirebaseLog> _logs = [];
  bool _isFetching = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate().toLocal();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, $hour:$min $period';
  }

  Future<void> _addLog() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _collection.add({
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log saved to Firebase.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchLogs() async {
    setState(() => _isFetching = true);
    try {
      final snapshot = await _collection
          .orderBy('timestamp', descending: true)
          .get();
      setState(() {
        _logs = snapshot.docs.map((doc) {
          final data = doc.data();
          return _FirebaseLog(
            message: data['message'] as String? ?? '',
            time: _formatTimestamp(data['timestamp'] as Timestamp?),
          );
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
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
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
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
                  TextButton.icon(
                    onPressed: _isFetching ? null : _fetchLogs,
                    icon: _isFetching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Fetch All', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No logs yet.\nTap "Fetch All" to load from Firebase.',
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
                        child: ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 36, bottom: 16),
                          itemCount: _logs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _LogTile(log: _logs[index]),
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Enter log message...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                      ),
                      style: const TextStyle(fontSize: 13),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addLog(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _addLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add Log', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseLog {
  final String message;
  final String time;

  const _FirebaseLog({required this.message, required this.time});
}

class _LogTile extends StatelessWidget {
  final _FirebaseLog log;

  const _LogTile({required this.log});

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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF483912), width: 1),
            ),
            child: const Center(
              child: Icon(Icons.notes, size: 18, color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log.message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            log.time,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
