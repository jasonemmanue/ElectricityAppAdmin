import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether an incoming admin alert is allowed to ring "urgently"
/// (full-screen intent + alarm category, which bypasses Do Not Disturb) or
/// should arrive as a normal, silent-ish notification.
///
/// Two independent gates:
///  * the "Alertes urgentes" switch in Settings — a hard off-switch;
///  * quiet hours — a nightly window during which nothing rings, so a 3 a.m.
///    appointment doesn't wake the electrician up.
///
/// Everything is persisted in SharedPreferences so the FCM handler can read it
/// without a BuildContext (notifications arrive with no UI attached).
class AlertPolicy extends ChangeNotifier {
  AlertPolicy._();
  static final AlertPolicy instance = AlertPolicy._();

  static const _kUrgentEnabled = 'adminUrgentAlertsEnabled';
  static const _kQuietEnabled = 'adminQuietHoursEnabled';
  static const _kQuietStartMin = 'adminQuietStartMinutes';
  static const _kQuietEndMin = 'adminQuietEndMinutes';

  bool _urgentEnabled = true;
  bool _quietEnabled = true;
  // Defaults: 22:00 → 07:00
  int _quietStartMinutes = 22 * 60;
  int _quietEndMinutes = 7 * 60;
  bool _loaded = false;

  bool get urgentEnabled => _urgentEnabled;
  bool get quietEnabled => _quietEnabled;
  bool get isLoaded => _loaded;
  TimeOfDay get quietStart =>
      TimeOfDay(hour: _quietStartMinutes ~/ 60, minute: _quietStartMinutes % 60);
  TimeOfDay get quietEnd =>
      TimeOfDay(hour: _quietEndMinutes ~/ 60, minute: _quietEndMinutes % 60);

  Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    _urgentEnabled = p.getBool(_kUrgentEnabled) ?? true;
    _quietEnabled = p.getBool(_kQuietEnabled) ?? true;
    _quietStartMinutes = p.getInt(_kQuietStartMin) ?? 22 * 60;
    _quietEndMinutes = p.getInt(_kQuietEndMin) ?? 7 * 60;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setUrgentEnabled(bool v) async {
    _urgentEnabled = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kUrgentEnabled, v);
  }

  Future<void> setQuietEnabled(bool v) async {
    _quietEnabled = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kQuietEnabled, v);
  }

  Future<void> setQuietStart(TimeOfDay t) async {
    _quietStartMinutes = t.hour * 60 + t.minute;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setInt(_kQuietStartMin, _quietStartMinutes);
  }

  Future<void> setQuietEnd(TimeOfDay t) async {
    _quietEndMinutes = t.hour * 60 + t.minute;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setInt(_kQuietEndMin, _quietEndMinutes);
  }

  /// True when [now] falls inside the quiet window. Handles windows that wrap
  /// past midnight (22:00 → 07:00), which is the common case.
  bool isWithinQuietHours([DateTime? now]) {
    if (!_quietEnabled) return false;
    final t = now ?? DateTime.now();
    final cur = t.hour * 60 + t.minute;
    if (_quietStartMinutes == _quietEndMinutes) return false; // empty window
    if (_quietStartMinutes < _quietEndMinutes) {
      // Same-day window, e.g. 01:00 → 06:00
      return cur >= _quietStartMinutes && cur < _quietEndMinutes;
    }
    // Wraps midnight, e.g. 22:00 → 07:00
    return cur >= _quietStartMinutes || cur < _quietEndMinutes;
  }

  /// The single question the FCM handler asks. Reads straight from
  /// SharedPreferences so it works in a background isolate where the in-memory
  /// singleton may not have been hydrated.
  static Future<bool> shouldRingUrgently() async {
    final p = await SharedPreferences.getInstance();
    final urgent = p.getBool(_kUrgentEnabled) ?? true;
    if (!urgent) return false;

    final quiet = p.getBool(_kQuietEnabled) ?? true;
    if (!quiet) return true;

    final start = p.getInt(_kQuietStartMin) ?? 22 * 60;
    final end = p.getInt(_kQuietEndMin) ?? 7 * 60;
    if (start == end) return true;

    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    final inQuiet = start < end
        ? (cur >= start && cur < end)
        : (cur >= start || cur < end);
    return !inQuiet;
  }
}
