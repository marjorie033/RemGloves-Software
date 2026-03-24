import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../widgets/rounded_body.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../theme/app_icons.dart';


class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

//Example or how it should be showed on the app
  static const List<_LogEntry> _logs = [
  _LogEntry(icon: AppIcons.lightbulb,   iconColor: Color(0xFFF5A623), title: 'Light Status: OFF', subtitle: 'Voice Command',    time: '10:05 AM'),
  _LogEntry(icon: AppIcons.fan,         iconColor: Color(0xFF29B6F6), title: 'Fan Status: ON',    subtitle: 'Voice Command',    time: '10:00 AM'),
  _LogEntry(icon: AppIcons.tv,          iconColor: Color(0xFFF5A623), title: 'TV Status: OFF',    subtitle: 'Voice Command',    time: '1:01 AM'),
  _LogEntry(icon: AppIcons.netflix,     iconColor: Color(0xFFE53935), title: 'Watching Netflix',  subtitle: 'Voice Command',    time: '11:58 AM'),
  _LogEntry(icon: AppIcons.tv,          iconColor: Color(0xFFF5A623), title: 'TV Status: ON',     subtitle: 'Voice Command',    time: '1:16 PM'),
  _LogEntry(icon: AppIcons.lightbulb,   iconColor: Color(0xFFF5A623), title: 'Light Status: ON',  subtitle: 'Gesture Command',  time: '2:30 PM'),
  _LogEntry(icon: AppIcons.fan,         iconColor: Color(0xFF29B6F6), title: 'Fan Speed: High',   subtitle: 'Gesture Command',  time: '3:10 PM'),
  _LogEntry(icon: AppIcons.tv,          iconColor: Color(0xFFF5A623), title: 'TV Volume: 20',     subtitle: 'Voice Command',    time: '4:45 PM'),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RemGloveAppBar(),
      backgroundColor: AppTheme.primary,
      body: RoundedBody(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ScrollbarTheme(
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
                  itemBuilder: (context, index) => _LogTile(entry: _logs[index]),
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

class _LogEntry {
  final String icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const _LogEntry({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class _LogTile extends StatelessWidget {
  final _LogEntry entry;

  const _LogTile({required this.entry});

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
            color: Colors.black.withOpacity(0.05),
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
              color: entry.iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF483912), width: 1),

            ),
            child: Center(
            child: Iconify(
              entry.icon, 
              color: entry.iconColor, 
              size: 14),
          ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.time,
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