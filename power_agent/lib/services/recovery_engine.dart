/// Keyword-based recovery. Original se same idea, thoda bada mapping.
class RecoveryEngine {
  static String diagnose({required String lastError, required String screen}) {
    final e = lastError.toLowerCase();
    final s = screen.toLowerCase();
    if (e.contains('not found') || e.contains('no node')) return 'scroll';
    if (s.contains('loading') || s.contains('please wait')) return 'wait';
    if (s.contains('keyboard') || s.contains('input')) return 'press_back';
    if (e.contains('timeout')) return 'wait';
    return 'press_back';
  }
}
