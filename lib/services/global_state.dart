// lib/services/global_state.dart
import 'package:flutter/foundation.dart'; // Assurez-vous que cette ligne est correcte

class GlobalState with ChangeNotifier {
  static final GlobalState _instance = GlobalState._internal();
  factory GlobalState() => _instance;
  GlobalState._internal();

  bool _isChatScreenActive = false;
  String? _activeChatUserId;
  bool _isAppInForeground = false;

  bool get isChatScreenActive => _isChatScreenActive;
  String? get activeChatUserId => _activeChatUserId;
  bool get isAppInForeground => _isAppInForeground;

  void setChatScreenActive(bool isActive, {String? userId}) {
    _isChatScreenActive = isActive;
    _activeChatUserId = userId;
    notifyListeners();
  }

  void setAppInForeground(bool isInForeground) {
    _isAppInForeground = isInForeground;
    notifyListeners();
  }
}