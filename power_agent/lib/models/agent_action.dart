class AgentAction {
  final String action;
  final Map<String, dynamic> params;
  final String reasoning;
  final bool isComplete;

  AgentAction({
    required this.action,
    required this.params,
    required this.reasoning,
    required this.isComplete,
  });

  // Original se powerful: naye gestures + vision actions included.
  static const List<String> availableActions = [
    'click_text',
    'click_at', // x,y in 0..1000 relative coords (density independent)
    'double_tap',
    'long_press',
    'type_text',
    'press_enter',
    'scroll',
    'swipe', // with durationMs
    'pinch', // pinch_in / pinch_out
    'press_back',
    'press_home',
    'open_recents',
    'open_notifications',
    'open_app',
    'open_url',
    'wait',
    'done',
  ];

  static const List<String> sensitiveKeywords = [
    'pay', 'payment', 'upi', 'transfer', 'buy', 'order',
    'delete', 'format', 'call', 'sms',
  ];
}
