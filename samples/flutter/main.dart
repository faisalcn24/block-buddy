import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'src/app/block_buddy_app.dart';
import 'src/core/platform/native_bridge.dart';
import 'src/features/buddies/data/buddy_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final initialRoute = PlatformDispatcher.instance.defaultRouteName;
  final uri = Uri.tryParse(initialRoute);

  NativeBridge.initialize(
    initialBlockedPackage:
        uri?.path == '/block' ? uri?.queryParameters['package'] : null,
  );
  unawaited(BuddyService.instance.initialize());

  runApp(BlockBuddyApp(initialRoute: initialRoute));
}
