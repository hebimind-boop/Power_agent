import 'package:flutter/material.dart';
import 'main.dart' show HomeScreen;

/// Stable overlay entry. Original me overlay disabled tha.
/// Yahan foreground-service + manifest entry ke saath wapas enable.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OverlayApp());
}

class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: OverlayBubble());
  }
}

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});
  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble> {
  bool _open = false;
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _open
          ? Container(
              width: 300,
              height: 380,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Padding(
                        padding: EdgeInsets.all(8), child: Text('PowerAgent'))),
                      IconButton(
                          icon: const Icon(Icons.minimize),
                          onPressed: () => setState(() => _open = false)),
                    ],
                  ),
                  Expanded(child: Center(child: Text(_ctrl.text.isEmpty ? 'Goal likho' : _ctrl.text))),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      Expanded(child: TextField(controller: _ctrl)),
                      IconButton(icon: const Icon(Icons.send), onPressed: () {}),
                    ]),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onTap: () => setState(() => _open = true),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: Colors.indigo, shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy, color: Colors.white),
              ),
            ),
    );
  }
}
