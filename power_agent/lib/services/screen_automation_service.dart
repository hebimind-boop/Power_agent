import 'package:flutter/services.dart';

/// Native bridge. Original se antar:
/// - durationMs wala swipe, longPress, doubleTap, pinch, openRecents expose
/// - har call par timeout + typed result (bool/String), silent-false nahi
/// - relative 0..1000 coords ko native pixels me badalna native side par
class ScreenAutomationService {
  static const MethodChannel _ch = MethodChannel('com.poweragent/accessibility');
  static const Duration _timeout = Duration(seconds: 5);

  Future<bool> ping() async {
    try {
      final r = await _ch.invokeMethod('ping').timeout(_timeout);
      return r == 'pong' || r == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      return await _ch.invokeMethod<bool>('isServiceRunning').timeout(_timeout) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> dumpScreen() async {
    try {
      final r = await _ch.invokeMethod('dumpScreen').timeout(_timeout);
      return r is String ? r : '';
    } catch (e) {
      throw Exception('dumpScreen failed: $e');
    }
  }

  Future<String?> takeScreenshot() async {
    try {
      return await _ch.invokeMethod<String>('takeScreenshot').timeout(const Duration(seconds: 8));
    } catch (_) {
      return null; // vision optional hai -> null par text-only continue
    }
  }

  Future<bool> clickByText(String text) =>
      _bool('clickByText', {'text': text});

  /// x,y: 0..1000 relative (original absolute-pixel bug fix)
  Future<bool> clickAt(int x, int y) => _bool('clickAt', {'x': x, 'y': y});

  Future<bool> doubleTap(int x, int y) => _bool('doubleTap', {'x': x, 'y': y});

  Future<bool> longPress(int x, int y, [int durationMs = 800]) =>
      _bool('longPressAt', {'x': x, 'y': y, 'durationMs': durationMs});

  Future<bool> typeText(String text, [String? hint]) =>
      _bool('typeText', {'text': text, 'hint': hint ?? ''});

  Future<bool> pressEnter() => _bool('pressEnter', {});

  Future<bool> scroll(String direction) =>
      _bool('scroll', {'direction': direction}); // up|down|left|right

  Future<bool> swipe(int x1, int y1, int x2, int y2, [int durationMs = 300]) =>
      _bool('swipe', {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'durationMs': durationMs});

  /// scale: 0.5 = zoom-out(pinch-in), 2.0 = zoom-in(pinch-out)
  Future<bool> pinch(int x, int y, double scale, [int durationMs = 400]) =>
      _bool('pinch', {'x': x, 'y': y, 'scale': scale, 'durationMs': durationMs});

  Future<bool> pressBack() => _bool('pressBack', {});
  Future<bool> pressHome() => _bool('pressHome', {});
  Future<bool> openRecents() => _bool('openRecents', {});
  Future<bool> openNotifications() => _bool('openNotifications', {});

  Future<String> currentPackage() async {
    try {
      final r = await _ch.invokeMethod('getCurrentPackage').timeout(_timeout);
      return r is String ? r : '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> _bool(String m, Map<String, dynamic> a) async {
    try {
      final r = await _ch.invokeMethod(m, a).timeout(_timeout);
      return r == true;
    } catch (e) {
      throw Exception('$m failed: $e');
    }
  }
}
