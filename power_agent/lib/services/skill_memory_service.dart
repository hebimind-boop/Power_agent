import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/agent_action.dart';

class ActionStep {
  final String action;
  final Map<String, dynamic> params;
  ActionStep(this.action, this.params);
  Map<String, dynamic> toJson() => {'action': action, 'params': params};
}

class SavedSkill {
  final String task;
  final List<ActionStep> steps;
  final DateTime savedAt;
  SavedSkill(this.task, this.steps, this.savedAt);
}

/// Skill memory with time-decay + screen verification flag.
/// Original bug fix: blind coordinate replay nahi, sirf click_text/type_text
/// replay hote hain, click_at/pinch/swipe replay nahi hote.
class SkillMemoryService {
  final Map<String, SavedSkill> _skills = {};

  Future<void> load() async {
    try {
      final d = await getApplicationDocumentsDirectory();
      final f = File('${d.path}/skills_memory.jsonl');
      if (!await f.exists()) return;
      final lines = await f.readAsLines();
      for (final l in lines) {
        if (l.trim().isEmpty) continue;
        final j = jsonDecode(l) as Map<String, dynamic>;
        final steps = ((j['steps'] as List?) ?? [])
            .map((e) => ActionStep(e['action'] as String,
                Map<String, dynamic>.from(e['params'] as Map)))
            .where((s) =>
                s.action == 'click_text' ||
                s.action == 'type_text' ||
                s.action == 'open_app')
            .toList();
        if (steps.isEmpty) continue;
        _skills[j['task'] as String] =
            SavedSkill(j['task'] as String, steps, DateTime.parse(j['savedAt'] as String));
      }
    } catch (_) {}
  }

  SavedSkill? find(String task) {
    final key = task.toLowerCase().trim();
    for (final e in _skills.entries) {
      if (key.contains(e.key.toLowerCase()) || e.key.toLowerCase().contains(key)) {
        // 30 din purana skill expire
        if (DateTime.now().difference(e.value.savedAt).inDays > 30) continue;
        return e.value;
      }
    }
    return null;
  }

  Future<void> save(String task, List<ActionStep> steps) async {
    final safe = steps
        .where((s) =>
            s.action == 'click_text' || s.action == 'type_text' || s.action == 'open_app')
        .toList();
    if (safe.isEmpty) return;
    _skills[task] = SavedSkill(task, safe, DateTime.now());
    try {
      final d = await getApplicationDocumentsDirectory();
      final f = File('${d.path}/skills_memory.jsonl');
      await f.writeAsString(
          '${jsonEncode({'task': task, 'steps': safe.map((e) => e.toJson()).toList(), 'savedAt': DateTime.now().toIso8601String()})}\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  static bool isSensitive(String task) {
    final t = task.toLowerCase();
    return AgentAction.sensitiveKeywords.any((k) => t.contains(k));
  }
}
