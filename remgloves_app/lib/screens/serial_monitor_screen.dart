import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class SerialMonitorScreen extends StatefulWidget {
  final BleService ble;
  const SerialMonitorScreen({super.key, required this.ble});

  @override
  State<SerialMonitorScreen> createState() => _SerialMonitorScreenState();
}

class _SerialMonitorScreenState extends State<SerialMonitorScreen> {
  final _entries   = <_LogEntry>[];
  StreamSubscription<String>? _sub;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _sub = widget.ble.logStream.listen(_onLog);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onLog(String msg) {
    if (!mounted) return;
    setState(() =>
        _entries.add(_LogEntry(message: msg, time: DateTime.now())));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clear() => setState(() => _entries.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serial Monitor',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            Text(
              '${_entries.length} message${_entries.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: 'Clear',
            color: _entries.isEmpty ? Colors.white24 : Colors.white60,
            onPressed: _entries.isEmpty ? null : _clear,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _entries.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal,
              size: 52,
              color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          const Text(
            'Waiting for LOG: messages…',
            style: TextStyle(
                fontSize: 13,
                color: Colors.white38,
                fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          Text(
            widget.ble.status == BleStatus.connected
                ? 'Glove connected — trigger calibration or another event.'
                : 'Connect your glove to start receiving logs.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      itemCount: _entries.length,
      itemBuilder: (_, i) {
        final e = _entries[i];
        final ts =
            '${e.time.hour.toString().padLeft(2, '0')}:'
            '${e.time.minute.toString().padLeft(2, '0')}:'
            '${e.time.second.toString().padLeft(2, '0')}.'
            '${(e.time.millisecond ~/ 10).toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  ts,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.white24,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Message
              Expanded(
                child: Text(
                  e.message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                    color: _msgColor(e.message),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _msgColor(String msg) {
    if (msg.contains('Calibration done!') || msg.contains('OK')) {
      return const Color(0xFF4ADE80); // green — success
    }
    if (msg.startsWith('[') && msg.contains('/3]')) {
      return const Color(0xFF60A5FA); // blue — phase headers
    }
    if (msg.startsWith('=====')) {
      return const Color(0xFFFBBF24); // amber — section dividers
    }
    if (msg.contains('FAIL') || msg.contains('Error')) {
      return const Color(0xFFF87171); // red — errors
    }
    return Colors.white70;
  }
}

class _LogEntry {
  final String message;
  final DateTime time;
  const _LogEntry({required this.message, required this.time});
}
