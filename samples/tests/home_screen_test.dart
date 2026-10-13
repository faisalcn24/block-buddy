import 'package:blockbuddy/src/app/app_controller.dart';
import 'package:blockbuddy/src/app/block_buddy_app.dart';
import 'package:blockbuddy/src/features/app_picker/presentation/apps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_states.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.beta.blockbuddy/platform');

  testWidgets('home renders the saved state', (tester) async {
    final invokedCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method != 'snapshot') invokedCalls.add(call);
        return homeState({'scheduleEnabled': true});
      },
    );

    await tester.pumpWidget(const BlockBuddyApp(initialRoute: '/'));
    await tester.pumpAndSettle();

    expect(find.text('BlockBuddy'), findsOneWidget);
    expect(find.text('Thriving'), findsOneWidget);
    expect(find.text('Choose apps to block'), findsOneWidget);
    expect(find.text('App stats'), findsOneWidget);
    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Daily limit'), findsNothing);
    expect(find.text('Schedule'), findsNothing);
    expect(find.text('Walk to unlock'), findsNothing);
    expect(find.text('No apps blocked yet.'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Blocking rules'), findsOneWidget);
    expect(find.text('App unlock methods'), findsOneWidget);

    await tester.tap(find.text('Blocking rules'));
    await tester.pumpAndSettle();
    expect(find.text('Daily limit'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(
      find.text('Block selected apps from 10:00 PM to 7:00 AM.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Daily limit'));
    await tester.pumpAndSettle();
    expect(invokedCalls.where((call) => call.method == 'setDailyLimitRule'),
        isEmpty);
    final slider = tester.widget<Slider>(
      find.byKey(const Key('daily-limit-slider')),
    );
    expect(slider.max, 240);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-daily-limit-rule')));
    await tester.pumpAndSettle();
    expect(
      invokedCalls.any(
        (call) =>
            call.method == 'setDailyLimitRule' &&
            (call.arguments as Map)['dailyEnabled'] == true &&
            (call.arguments as Map)['dailyLimitMinutes'] == 60,
      ),
      isTrue,
    );
    expect(
      invokedCalls.where((call) => call.method == 'setScheduleRule'),
      isEmpty,
    );

    await tester.tap(find.text('Blocking rules'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('App unlock methods'));
    await tester.tap(find.text('App unlock methods'));
    await tester.pumpAndSettle();
    expect(find.text('Walk to unlock'), findsOneWidget);
    expect(
      find.text('Walk 500 steps to unlock all blocked apps for 15 minutes.'),
      findsOneWidget,
    );
    expect(find.text('Ask a Buddy'), findsOneWidget);

    await tester.tap(find.text('App unlock methods'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App stats'));
    await tester.pumpAndSettle();
    expect(find.text('No apps blocked yet.'), findsOneWidget);

    await tester.tap(find.text('Buddies'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cat-buddy-card')), findsOneWidget);
    expect(find.text('Your buddies'), findsOneWidget);
    expect(find.text('Add a friend'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Your pairing code'), findsNothing);
    expect(
      find.text('Your cat is thriving • 90% chance of approving your request'),
      findsOneWidget,
    );
  });

  testWidgets('debug menu exposes cat and usage testing actions',
      (tester) async {
    final invokedMethods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        invokedMethods.add(call.method);
        return homeState();
      },
    );

    await tester.pumpWidget(const BlockBuddyApp(initialRoute: '/'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();

    expect(find.text('Reset cat state'), findsOneWidget);
    expect(find.text('Ruin cat state (testing)'), findsOneWidget);
    expect(find.text('Add 5 minutes of usage'), findsOneWidget);

    await tester.tap(find.text('Add 5 minutes of usage'));
    await tester.pumpAndSettle();
    expect(invokedMethods, contains('addDebugUsage'));

    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ruin cat state (testing)'));
    await tester.pumpAndSettle();
    expect(invokedMethods, contains('ruinCat'));
  });

  testWidgets('a gesture starting on the home cat purrs without scrolling',
      (tester) async {
    final invokedCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method != 'snapshot') invokedCalls.add(call);
        return homeState();
      },
    );

    await tester.pumpWidget(const BlockBuddyApp(initialRoute: '/'));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const PageStorageKey<String>('home-tab')),
        matching: find.byType(Scrollable),
      ),
    );
    final before = scrollable.position.pixels;

    await tester.drag(find.byKey(const Key('home-cat')), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, before);
    expect(
      invokedCalls.where(
        (call) =>
            call.method == 'playSound' &&
            (call.arguments as Map)['name'] == 'purr',
      ),
      hasLength(1),
    );
  });

  testWidgets('daily limit and schedule have independent daily locks',
      (tester) async {
    final invokedCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method != 'snapshot') invokedCalls.add(call);
        return homeState({
          'dailyLimitEnabled': true,
          'dailyLimitMinutes': 240,
          'dailyRuleChangeAllowed': false,
          'scheduleRuleChangeAllowed': true,
          'usageAvailable': true,
        });
      },
    );

    await tester.pumpWidget(const BlockBuddyApp(initialRoute: '/'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blocking rules'));
    await tester.pumpAndSettle();

    expect(
      find.text('Daily limit changed today. Try again tomorrow.'),
      findsOneWidget,
    );
    expect(
      find.text('You can change the schedule once per day.'),
      findsOneWidget,
    );
    final dailySwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Daily limit'),
    );
    expect(dailySwitch.onChanged, isNull);
    final scheduleSwitchFinder =
        find.widgetWithText(SwitchListTile, 'Schedule');
    final scheduleSwitch = tester.widget<SwitchListTile>(scheduleSwitchFinder);
    expect(scheduleSwitch.onChanged, isNotNull);
    final slider = tester.widget<Slider>(
      find.byKey(const Key('daily-limit-slider')),
    );
    expect(slider.max, 240);
    expect(slider.onChanged, isNull);
    final dailySave = tester.widget<FilledButton>(
      find.byKey(const Key('save-daily-limit-rule')),
    );
    expect(dailySave.onPressed, isNull);

    await tester.ensureVisible(scheduleSwitchFinder);
    await tester.pumpAndSettle();
    await tester.tap(scheduleSwitchFinder);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-schedule-rule')));
    await tester.pumpAndSettle();
    final scheduleSave = tester.widget<FilledButton>(
      find.byKey(const Key('save-schedule-rule')),
    );
    expect(scheduleSave.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('save-schedule-rule')));
    await tester.pumpAndSettle();
    expect(
      invokedCalls.any(
        (call) =>
            call.method == 'setScheduleRule' &&
            (call.arguments as Map)['scheduleEnabled'] == true,
      ),
      isTrue,
    );
    expect(
      invokedCalls.where((call) => call.method == 'setDailyLimitRule'),
      isEmpty,
    );
  });

  testWidgets('daily limit shows combined blocked-app usage on Home',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'appIcon') return null;
        return homeState({
          'blockedCount': 2,
          'dailyLimitEnabled': true,
          'usageAvailable': true,
          'todayUsage': [
            {
              'package': 'com.example.instagram',
              'label': 'Instagram',
              'millis': 30 * 60 * 1000,
            },
            {
              'package': 'com.example.youtube',
              'label': 'YouTube',
              'millis': 10 * 60 * 1000,
            },
          ],
          'totalToday': 40 * 60 * 1000,
        });
      },
    );

    await tester.pumpWidget(const BlockBuddyApp(initialRoute: '/'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-usage-card')), findsOneWidget);
    expect(find.text('Daily usage'), findsOneWidget);
    expect(find.text('All blocked apps'), findsNothing);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('40m of 1h'), findsOneWidget);
  });

  testWidgets('app picker keeps blocked apps on top with remove buttons',
      (tester) async {
    final invokedCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        invokedCalls.add(call);
        return switch (call.method) {
          'apps' => [
              {
                'package': 'com.example.instagram',
                'label': 'Instagram',
                'blocked': true,
              },
              {
                'package': 'com.example.youtube',
                'label': 'YouTube',
                'blocked': false,
              },
            ],
          'snapshot' => <String, Object>{
              'ready': true,
              'permissions': <String, bool>{},
              'blockedCount': 0,
            },
          _ => null,
        };
      },
    );
    final controller = AppController();

    await tester.pumpWidget(
      MaterialApp(home: AppsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blocked apps'), findsOneWidget);
    expect(find.text('Add apps'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blocked-app-com.example.instagram')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('available-app-com.example.youtube')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('remove-blocked-com.example.instagram')),
    );
    await tester.pumpAndSettle();

    expect(
      invokedCalls.any(
        (call) =>
            call.method == 'toggleApp' &&
            (call.arguments as Map)['package'] == 'com.example.instagram',
      ),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('blocked-app-com.example.instagram')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('available-app-com.example.instagram')),
      findsOneWidget,
    );

    controller.dispose();
  });

  testWidgets('stats tab shows a seven-day graph for every blocked app',
      (tester) async {
    final days = [
      {'label': 'Yesterday', 'millis': 1800000},
      {'label': 'Today', 'millis': 3600000},
    ];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'appIcon') return null;
        return homeState({
          'blockedCount': 2,
          'usageAvailable': true,
          'history': days,
          'appHistory': [
            {
              'package': 'com.example.instagram',
              'label': 'Instagram',
              'millis': 2400000,
              'history': days,
            },
            {
              'package': 'com.example.youtube',
              'label': 'YouTube',
              'millis': 1200000,
              'history': days,
            },
          ],
          'totalToday': 3600000,
        });
      },
    );

    await tester.pumpWidget(const BlockBuddyApp(initialRoute: '/'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('usage-chart-com.example.instagram')),
      findsNothing,
    );

    await tester.tap(find.text('App stats'));
    await tester.pumpAndSettle();

    expect(find.text('All blocked apps — last 7 days'), findsOneWidget);
    expect(find.text('By app'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('usage-chart-com.example.instagram')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('usage-chart-com.example.youtube')),
      findsOneWidget,
    );
  });
}
