import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class LogSummaryInput {
  final int totalCount;
  final Map<String, int> deviceCounts;
  final Map<String, int> commandCounts;
  final int calibrationCount;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const LogSummaryInput({
    required this.totalCount,
    required this.deviceCounts,
    required this.commandCounts,
    required this.calibrationCount,
    required this.rangeStart,
    required this.rangeEnd,
  });
}

class AiSummaryService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash-lite:generateContent';

  static Future<String> summarize(LogSummaryInput input) async {
    final prompt = _buildPrompt(input);
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 300,
      },
    });

    for (int attempt = 0; attempt < 2; attempt++) {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 429 && attempt == 0) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }

      if (response.statusCode != 200) {
        throw Exception('Gemini error ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      return text?.trim() ?? 'No summary available.';
    }

    throw Exception('Rate limit exceeded. Please wait a moment and try again.');
  }

  static String _buildPrompt(LogSummaryInput input) {
    final deviceLines = input.deviceCounts.entries
        .map((e) => '  - ${e.key}: ${e.value} gestures')
        .join('\n');

    final topCommands = (input.commandCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => '  - "${e.key}": ${e.value}x')
        .join('\n');

    return '''
You are an analytics assistant for a smart glove app called RemGloves that controls home devices via hand gestures.

Summarize the following gesture log data in 3–4 concise sentences. Focus on usage patterns, most active device, and any notable behavior. Be friendly and clear — the audience is the glove user.

Data:
- Period: ${_fmt(input.rangeStart)} to ${_fmt(input.rangeEnd)}
- Total gestures: ${input.totalCount}
- Calibration events: ${input.calibrationCount}
- By device:
$deviceLines
- Top commands:
$topCommands

Write the summary now:''';
  }

  static String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
