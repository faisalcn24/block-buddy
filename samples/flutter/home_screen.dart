import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/platform/native_bridge.dart';
import '../../../core/platform/platform_data.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/widgets/notice_card.dart';
import '../../app_picker/presentation/apps_screen.dart';
import '../../buddies/presentation/buddies_screen.dart';
import '../../buddies/presentation/buddy_challenge.dart';
import '../../stats/presentation/stats_view.dart';
import 'home_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final health = data.decimal('health', 1);
    final mood = data.text('mood', 'Thriving');
    final blocking = data['blockingEnabled'] != false;
    final dailyLimitEnabled = data['dailyLimitEnabled'] == true;
    final grantExpires = data.integer('grantExpiresAt');
    final minutesLeft = math.max(
      0,
      ((grantExpires - DateTime.now().millisecondsSinceEpoch) / 60000).ceil(),
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BlockBuddy'),
          actions: [
            if (kDebugMode)
              PopupMenuButton<String>(
                onSelected: controller.act,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'resetCat',
                    child: Text('Reset cat state'),
                  ),
                  const PopupMenuItem(
                    value: 'ruinCat',
                    child: Text('Ruin cat state (testing)'),
                  ),
                  if (!Platform.isIOS)
                    const PopupMenuItem(
                      value: 'addDebugUsage',
                      child: Text('Add 5 minutes of usage'),
                    ),
                ],
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Home'),
              Tab(text: 'App stats'),
              Tab(text: 'Buddies'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              ListView(
                key: const PageStorageKey<String>('home-tab'),
                // Leave enough scroll range for the system navigation area
                // and Android's optional floating accessibility shortcut.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Mascot(
                          health: health,
                          size: 144,
                          walking: controller.walking,
                          onRub: () =>
                              NativeBridge.call('playSound', {'name': 'purr'}),
                        ),
                        const SizedBox(height: 8),
                        Text(mood,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (Platform.isAndroid) ...[
                          const SizedBox(height: 8),
                          CheerUpAdButton(controller: controller),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (dailyLimitEnabled) ...[
                    DailyUsageCard(data: data),
                    const SizedBox(height: 12),
                  ],
                  if (!blocking)
                    const NoticeCard(
                      title: 'Blocking is off',
                      body:
                          'Blocked apps open normally. Your list is still saved.',
                      error: true,
                    ),
                  if (controller.walking) WalkCard(data: data),
                  if (minutesLeft > 0)
                    Card(
                      child: ListTile(
                        title: Text(
                            'Unlocked for $minutesLeft more minute${minutesLeft == 1 ? '' : 's'}.'),
                        trailing: TextButton(
                          onPressed: () => controller.act('endGrant'),
                          child: const Text('End now'),
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AppsScreen(controller: controller),
                        ),
                      );
                      controller.refresh();
                    },
                    child: Text(controller.blockedCount == 0
                        ? 'Choose apps to block'
                        : 'Edit blocked apps'),
                  ),
                  if (Platform.isIOS &&
                      controller.blockedCount > 0 &&
                      !controller.walking &&
                      minutesLeft == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => controller.act('startWalk'),
                            child: const Text('Start walking to unlock'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => showBuddyUnlock(
                              context,
                              controller,
                              health,
                              mood,
                            ),
                            icon: const Icon(Icons.people_outline),
                            label: const Text('Ask a buddy to unlock'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => controller.act(
                      'setBlocking',
                      {'enabled': !blocking},
                    ),
                    child: Text(blocking ? 'Stop blocking' : 'Start blocking'),
                  ),
                  const SizedBox(height: 20),
                  ExpandableSection(
                    storageKey: 'blocking-rules',
                    title: 'Blocking rules',
                    child: BlockingRules(controller: controller),
                  ),
                  const SizedBox(height: 12),
                  ExpandableSection(
                    storageKey: 'unlock-methods',
                    title: 'App unlock methods',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StepGoal(
                          value: data.integer('stepGoal', 500),
                          onChanged: (goal) =>
                              controller.act('setStepGoal', {'goal': goal}),
                        ),
                        const Divider(height: 32),
                        const BuddyMethodInfo(),
                      ],
                    ),
                  ),
                  if (controller.error case final error?)
                    _errorText(context, error),
                ],
              ),
              ListView(
                key: const PageStorageKey<String>('app-stats-tab'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: controller.blockedCount == 0
                          ? const Text('No apps blocked yet.')
                          : StatsView(data: data),
                    ),
                  ),
                  if (controller.error case final error?)
                    _errorText(context, error),
                ],
              ),
              BuddiesScreen(
                health: health,
                mood: mood,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _errorText(BuildContext context, String error) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        error,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
