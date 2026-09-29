import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AiResponse {
  final String content;
  final int totalTokens;
  AiResponse(this.content, this.totalTokens);
}

class ProviderConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  ProviderConfig({required this.baseUrl, required this.apiKey, required this.model});
}

/// Multi-provider AI service with vision + fallback.
/// Original se antar:
/// - sirf ek provider nahi, primary + fallback chain
/// - screenshot (base64 jpeg) + UI tree dono bhejta hai (vision)
/// - robust JSON extractor (balanced braces), auto-'}' hack hataya
/// - stream leak fix (client hamesha close)
class AiService {
  String _baseUrl = 'https://openrouter.ai/api/v1';
  String _apiKey = '';
  String _model = 'openai/gpt-oss-120b:free';
  List<ProviderConfig> _fallbacks = [];
  int maxSteps = 30;
  double temperature = 0.2;
  int maxTokens = 1024;
  bool useVision = true;

  Future<void> loadFromPrefs(Map<String, String> prefs) async {
    if (prefs['base_url'] != null) _baseUrl = prefs['base_url']!;
    if (prefs['api_key'] != null) _apiKey = prefs['api_key']!;
    if (prefs['model'] != null) _model = prefs['model']!;
  }

  void setFallbacks(List<ProviderConfig> f) => _fallbacks = f;

  String _endpoint(String base) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (b.endsWith('/chat/completions')) return b;
    return '$b/chat/completions';
  }

  Map<String, String> _headers(String key) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://power-agent.local',
        'X-Title': 'PowerAgent',
      };

  /// Vision message: text tree + optional screenshot.
  /// OpenAI vision format: content = [{type:text},{type:image_url}]
  Map<String, dynamic> _taskPayload({
    required String system,
    required String task,
    required String screenTree,
    required String prevResult,
    String? screenshotBase64,
    required ProviderConfig p,
  }) {
    final userText = 'TASK: $task\nSCREEN:\n$screenTree\nPREVIOUS_RESULT: $prevResult';
    List<Map<String, dynamic>> content = [
      {'type': 'text', 'text': userText}
    ];
    if (FeatureFlags.visionModeEnabled &&
        useVision &&
        screenshotBase64 != null &&
        screenshotBase64.isNotEmpty) {
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$screenshotBase64'}
      });
    }
    return {
      'model': p.model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': content},
      ],
    };
  }

  Future<AiResponse> sendTaskMessage({
    required String system,
    required String task,
    required String screenTree,
    required String prevResult,
    String? screenshotBase64,
  }) async {
    final chain = [
      ProviderConfig(baseUrl: _baseUrl, apiKey: _apiKey, model: _model),
      ..._fallbacks,
    ];
    Object? lastErr;
    for (var i = 0; i < chain.length; i++) {
      final p = chain[i];
      // vision fail hua to text-only retry ke liye 2 attempt
      for (var visionTry = 0; visionTry < 2; visionTry++) {
        final withShot = visionTry == 0 ? screenshotBase64 : null;
        try {
          final res = await _postOnce(
            system: system,
            task: task,
            screenTree: screenTree,
            prevResult: prevResult,
            screenshotBase64: withShot,
            p: p,
          );
          return res;
        } catch (e) {
          lastErr = e;
          // 400 vision error -> text-only retry, warna next provider
          if (e.toString().contains('400') && visionTry == 0) continue;
          break;
        }
      }
      if (!FeatureFlags.multiProviderFallbackEnabled) break;
    }
    throw lastErr ?? Exception('All AI providers failed');
  }

  Future<AiResponse> _postOnce({
    required String system,
    required String task,
    required String screenTree,
    required String prevResult,
    required ProviderConfig p,
    String? screenshotBase64,
  }) async {
    final client = http.Client();
    try {
      final resp = await client
          .post(Uri.parse(_endpoint(p.baseUrl)),
              headers: _headers(p.apiKey),
              body: jsonEncode(_taskPayload(
                  system: system,
                  task: task,
                  screenTree: screenTree,
                  prevResult: prevResult,
                  screenshotBase64: screenshotBase64,
                  p: p)))
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        throw Exception('${resp.statusCode}: ${resp.body.substring(0, resp.body.length > 300 ? 300 : resp.body.length)}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = j['choices'] as List;
      final content = (choices[0]['message']['content'] ?? '') as String;
      final usage = j['usage'] as Map<String, dynamic>?;
      return AiResponse(_stripThink(content).trim(), (usage?['total_tokens'] ?? 0) as int);
    } finally {
      client.close(); // leak fix: original me early-throw par close miss hota tha
    }
  }

  static String _stripThink(String s) =>
      s.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');

  /// Robust balanced-brace JSON extractor (original ka first-{..last-} greedy fix).
  static Map<String, dynamic>? extractJson(String raw) {
    var s = _stripThink(raw).trim();
    s = s.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = s.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inStr = false;
    var esc = false;
    for (var i = start; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
      } else {
        if (c == '"') inStr = true;
        if (c == '{') depth++;
        if (c == '}') {
          depth--;
          if (depth == 0) {
            try {
              return jsonDecode(s.substring(start, i + 1)) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          }
        }
      }
    }
    return null;
  }
}
