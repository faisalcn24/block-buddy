import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/platform/native_bridge.dart';
import '../core/platform/platform_data.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  Map<String, dynamic> data = const {};
  bool loading = true;
  String? error;
  Timer? _poll;

  bool get ready => data['ready'] == true;
  bool get walking => data['walking'] == true;
  int get blockedCount => data.integer('blockedCount');
  Map<String, bool> get permissions => Map<String, bool>.from(
        (data['permissions'] as Map?) ?? const {},
      );

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await refresh(freshUsage: true);
  }

  Future<void> refresh({bool freshUsage = false}) async {
    try {
      data = await NativeBridge.snapshot(freshUsage: freshUsage);
      error = null;
      _updatePolling();
    } on PlatformException catch (exception) {
      error = exception.message ?? exception.code;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> act(String method, [Map<String, Object?>? arguments]) async {
    try {
      await NativeBridge.call(method, arguments);
      await refresh(freshUsage: true);
    } on PlatformException catch (exception) {
      error = exception.message ?? exception.code;
      notifyListeners();
    }
  }

  void _updatePolling() {
    final grantExpires = data.integer('grantExpiresAt');
    final active =
        walking || grantExpires > DateTime.now().millisecondsSinceEpoch;
    if (active && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    } else if (!active) {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(freshUsage: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }
}
