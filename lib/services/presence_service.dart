import 'dart:async';

import 'package:flutter/widgets.dart';

import '../providers/auth_provider.dart';
import 'chat_service.dart';

/// Keeps the user marked Online while the app is in the foreground and
/// they are logged in. Stops when the app backgrounds or they sign out.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const Duration _interval = Duration(seconds: 45);

  Timer? _timer;
  AuthProvider? _auth;
  bool _listening = false;
  bool _foreground = true;

  void attach(AuthProvider auth) {
    _auth = auth;
    if (!_listening) {
      WidgetsBinding.instance.addObserver(this);
      _listening = true;
    }
    auth.addListener(_onAuthChanged);
    _sync();
  }

  void detach() {
    _auth?.removeListener(_onAuthChanged);
    _auth = null;
    stop();
    if (_listening) {
      WidgetsBinding.instance.removeObserver(this);
      _listening = false;
    }
  }

  void _onAuthChanged() => _sync();

  void _sync() {
    final loggedIn = _auth?.isLoggedIn == true;
    if (loggedIn && _foreground) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_timer != null) return;
    _beat();
    _timer = Timer.periodic(_interval, (_) => _beat());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _beat() async {
    if (_auth?.isLoggedIn != true || !_foreground) return;
    await ChatService.sendPresenceHeartbeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _sync();
    } else {
      stop();
    }
  }
}
