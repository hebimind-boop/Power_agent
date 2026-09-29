import 'package:flutter_test/flutter_test.dart';
import 'package:power_agent/services/ai_service.dart';
import 'package:power_agent/models/agent_action.dart';

void main() {
  test('balanced-brace extractor nested JSON nikalta hai', () {
    final raw = 'soch <think>x</think> ```json\n{"action":"click_text","params":{"text":"OK"},"reasoning":"hi","is_complete":false}\n``` done';
    final j = AiService.extractJson(raw);
    expect(j?['action'], 'click_text');
  });

  test('truncated JSON null deta hai (auto-brace hack nahi)', () {
    final raw = '{"action":"click_text","params":{"text":"OK"';
    expect(AiService.extractJson(raw), isNull);
  });

  test('naye gestures allowlist me hain', () {
    for (final a in ['double_tap', 'long_press', 'pinch', 'open_recents']) {
      expect(AgentAction.availableActions.contains(a), isTrue);
    }
  });
}
