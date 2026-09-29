import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';
import 'screen_automation_service.dart';
import 'task_executor.dart';
import 'skill_memory_service.dart';
import '../models/chat_message.dart';

class PowerAgentApp extends StatelessWidget {
  const PowerAgentApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerAgent',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final List<ChatMessage> _msgs = [];
  final _ai = AiService();
  final _screen = ScreenAutomationService();
  final _skills = SkillMemoryService();
  TaskExecutor? _exec;
  bool _busy = false;
  String _status = 'Ready';
  bool _vision = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    await _ai.loadFromPrefs({
      'base_url': p.getString('base_url') ?? 'https://openrouter.ai/api/v1',
      'api_key': p.getString('api_key') ?? '',
      'model': p.getString('model') ?? 'openai/gpt-oss-120b:free',
    });
    _ai.maxSteps = p.getInt('max_steps') ?? 30;
    _ai.useVision = p.getBool('vision') ?? true;
    _vision = _ai.useVision;
    await _skills.load();
    setState(() => _status = await _screen.isServiceRunning()
        ? 'Accessibility ON'
        : 'Accessibility OFF — Settings me on karo');
  }

  Future<void> _run() async {
    final goal = _ctrl.text.trim();
    if (goal.isEmpty || _busy) return;
    if ((await SharedPreferences.getInstance()).getString('api_key') == null ||
        (await SharedPreferences.getInstance()).getString('api_key')!.isEmpty) {
      setState(() {
        _msgs.add(ChatMessage(role: 'assistant', content: 'Pehle Settings me API key dalo.'));
      });
      _openSettings();
      return;
    }
    setState(() {
      _busy = true;
      _msgs.add(ChatMessage(role: 'user', content: goal));
      _status = 'Working...';
    });
    _ctrl.clear();
    _exec = TaskExecutor(
      ai: _ai,
      screen: _screen,
      confirmSensitive: (desc) async {
        if (!mounted) return false;
        final r = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Sensitive action?'),
            content: Text(desc),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Deny')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Allow')),
            ],
          ),
        );
        return r ?? false;
      },
    );
    final skill = _skills.find(goal);
    final res = await _exec!.executeTask(
      goal,
      replayPrefix: skill?.steps.map((e) => ActionStep(e.action, e.params)).toList() ?? [],
      onStep: (s, a) => setState(() => _status = 'Step $s: $a'),
    );
    if (res.success) await _skills.save(goal, []);
    setState(() {
      _busy = false;
      _status = res.success ? 'Done' : 'Failed';
      _msgs.add(ChatMessage(role: 'assistant', content: res.summary));
    });
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerAgent'),
        actions: [
          Row(children: [
            const Text('Vision'),
            Switch(value: _vision, onChanged: (v) async {
              setState(() => _vision = v);
              _ai.useVision = v;
              (await SharedPreferences.getInstance()).setBool('vision', v);
            }),
          ]),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Text(_status),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                final me = m.role == 'user';
                return Align(
                  alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Card(
                    color: me ? Theme.of(context).colorScheme.primaryContainer : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(m.content),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: () => _exec?.cancel(), child: const Text('Cancel')),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Goal likho: WhatsApp kholo aur...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _run(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _run, child: const Text('Go')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _model = TextEditingController();
  int _steps = 30;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _url.text = p.getString('base_url') ?? 'https://openrouter.ai/api/v1';
        _key.text = p.getString('api_key') ?? '';
        _model.text = p.getString('model') ?? 'openai/gpt-oss-120b:free';
        _steps = p.getInt('max_steps') ?? 30;
      });
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('base_url', _url.text.trim());
    await p.setString('api_key', _key.text.trim());
    await p.setString('model', _model.text.trim());
    await p.setInt('max_steps', _steps);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'Base URL')),
          TextField(controller: _key, decoration: const InputDecoration(labelText: 'API Key'), obscureText: true),
          TextField(controller: _model, decoration: const InputDecoration(labelText: 'Model')),
          const SizedBox(height: 12),
          Text('Max steps: $_steps (hard cap 60)'),
          Slider(value: _steps.toDouble(), min: 5, max: 60, divisions: 11,
              onChanged: (v) => setState(() => _steps = v.toInt())),
          const SizedBox(height: 8),
          const Text('Free ke liye: OpenRouter account → API key → model openai/gpt-oss-120b:free'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
