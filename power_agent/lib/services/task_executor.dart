import 'dart:async';
import 'ai_service.dart';
import 'screen_automation_service.dart';
import 'recovery_engine.dart';
import 'skill_memory_service.dart', show ActionStep;
import '../models/agent_action.dart';
import '../config/app_config.dart';

const String kTaskSystemPrompt = '''
You are PowerAgent, an Android automation brain.
Return ONLY one JSON object per step: {"action":"...","params":{...},"reasoning":"...","is_complete":false}
Actions: click_text{"text"}, click_at{"x":0-1000,"y":0-1000}, double_tap{"x","y"}, long_press{"x","y","durationMs"}, type_text{"text"}, press_enter{}, scroll{"direction":"down|up|left|right"}, swipe{"x1","y1","x2","y2","durationMs"}, pinch{"x","y","scale"}, press_back{}, press_home{}, open_recents{}, open_notifications{}, open_app{"package_or_name"}, open_url{"url"}, wait{"ms"}, done{"summary"}.
Rules: small steps, if is_complete=true use done. Prefer click_text over click_at. Use vision screenshot when provided.
''';

class TaskResult {
  final bool success;
  final String summary;
  TaskResult(this.success, this.summary);
}

/// Vision-fusion task loop. Original se antar:
/// - screenshot + tree dono LLM ko
/// - hard cap 60 (999 wala battery-blowup fix)
/// - sensitive action par optional confirm callback
/// - repeat-guard + failure recovery
class TaskExecutor {
  final AiService ai;
  final ScreenAutomationService screen;
  final Future<bool> Function(String actionDesc)? confirmSensitive;
  bool _cancel = false;

  TaskExecutor({required this.ai, required this.screen, this.confirmSensitive});

  void cancel() => _cancel = true;

  Future<TaskResult> executeTask(String goal,
      {void Function(int step, String action)? onStep,
      List<ActionStep> replayPrefix = const []}) async {
    if (!await screen.isServiceRunning()) {
      return TaskResult(false, 'Accessibility service OFF hai. On karo.');
    }
    final hardCap = ai.maxSteps > 60 ? 60 : ai.maxSteps;
    String prev = 'START';
    final List<ActionStep> done = [...replayPrefix];

    // skill prefix replay (sirf safe actions)
    for (final s in replayPrefix) {
      if (_cancel) return TaskResult(false, 'Cancelled');
      await _runOne(s.action, s.params);
    }

    for (var step = 0; step < hardCap; step++) {
      if (_cancel) return TaskResult(false, 'Cancelled at step $step');
      await Future.delayed(Duration(milliseconds: step == 0 ? 400 : 1100));

      String tree = '';
      String? shot;
      try {
        tree = await screen.dumpScreen();
      } catch (e) {
        prev = 'SCREEN_ERROR: $e';
        continue;
      }
      if (tree.length > 6000) tree = tree.substring(0, 6000);
      try {
        shot = await screen.takeScreenshot();
      } catch (_) {
        shot = null;
      }

      AiResponse resp;
      try {
        resp = await ai.sendTaskMessage(
            system: kTaskSystemPrompt,
            task: goal,
            screenTree: tree,
            prevResult: prev,
            screenshotBase64: shot);
      } catch (e) {
        prev = 'AI_ERROR: $e';
        if (step > 5) {
          final rec = RecoveryEngine.diagnose(lastError: prev, screen: tree);
          await _runOne(rec, {});
        }
        continue;
      }

      final parsed = AiService.extractJson(resp.content);
      if (parsed == null) {
        prev = 'PARSE_ERROR: JSON nahi mila. Sirf JSON do.';
        continue;
      }
      final action = (parsed['action'] ?? '').toString();
      final params = Map<String, dynamic>.from(parsed['params'] as Map? ?? {});
      final isDone = parsed['is_complete'] == true || action == 'done';
      onStep?.call(step, action);

      if (!AgentAction.availableActions.contains(action)) {
        prev = 'UNKNOWN_ACTION: $action';
        continue;
      }
      if (FeatureFlags.confirmSensitiveActions &&
          SkillMemoryService.isSensitive('$goal $action ${params.toString()}') &&
          action != 'done' &&
          confirmSensitive != null) {
        final ok = await confirmSensitive!('$action ${params.toString()}');
        if (!ok) return TaskResult(false, 'User ne sensitive action deny kiya.');
      }
      if (isDone) {
        return TaskResult(true, (parsed['params'] is Map && (parsed['params']['summary'] != null))
            ? (parsed['params']['summary']).toString()
            : resp.content);
      }
      try {
        final ok = await _runOne(action, params);
        done.add(ActionStep(action, params));
        prev = ok ? 'OK: $action $params' : 'FAIL: $action $params';
        if (!ok) {
          final rec = RecoveryEngine.diagnose(lastError: prev, screen: tree);
          if (rec != action) await _runOne(rec, {});
        }
      } catch (e) {
        prev = 'EXEC_ERROR $action: $e';
      }
    }
    return TaskResult(false, 'Max $hardCap steps khatm. Task adhura.');
  }

  Future<bool> _runOne(String action, Map<String, dynamic> p) async {
    int iv(String k) => (p[k] is num) ? (p[k] as num).toInt() : int.tryParse('${p[k] ?? 0}') ?? 0;
    switch (action) {
      case 'click_text':
        return screen.clickByText('${p['text'] ?? ''}');
      case 'click_at':
        return screen.clickAt(iv('x'), iv('y'));
      case 'double_tap':
        return screen.doubleTap(iv('x'), iv('y'));
      case 'long_press':
        return screen.longPress(iv('x'), iv('y'), iv('durationMs') == 0 ? 800 : iv('durationMs'));
      case 'type_text':
        return screen.typeText('${p['text'] ?? ''}');
      case 'press_enter':
        return screen.pressEnter();
      case 'scroll':
        return screen.scroll('${p['direction'] ?? 'down'}');
      case 'swipe':
        return screen.swipe(iv('x1'), iv('y1'), iv('x2'), iv('y2'),
            iv('durationMs') == 0 ? 300 : iv('durationMs'));
      case 'pinch':
        final s = double.tryParse('${p['scale'] ?? 1.5}') ?? 1.5;
        return screen.pinch(iv('x'), iv('y'), s);
      case 'press_back':
        return screen.pressBack();
      case 'press_home':
        return screen.pressHome();
      case 'open_recents':
        return screen.openRecents();
      case 'open_notifications':
        return screen.openNotifications();
      case 'wait':
        await Future.delayed(Duration(milliseconds: iv('ms') == 0 ? 1000 : iv('ms')));
        return true;
      default:
        return false;
    }
  }
}
