import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters/duration_format.dart';
import '../../../core/platform/platform_data.dart';
import '../../../core/widgets/app_icon.dart';

class StatsView extends StatelessWidget {
  const StatsView({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (data['usageAvailable'] != true) {
      return const Text(
        'Usage history is unavailable on this platform or permission is off.',
      );
    }
    final today = data.rows('todayUsage');
    final history = data.rows('history');
    final appHistory = data.rows('appHistory');
    final total = data.integer('totalToday');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time on blocked apps',
            style: Theme.of(context).textTheme.titleMedium),
        Text(formatUsageDuration(total),
            style: Theme.of(context).textTheme.headlineSmall),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('All blocked apps — last 7 days'),
          SizedBox(
            width: double.infinity,
            child: _UsageChart(days: history),
          ),
        ],
        if (appHistory.isNotEmpty) ...[
          const Divider(height: 32),
          Text('By app', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var index = 0; index < appHistory.length; index++) ...[
            _AppUsageChart(data: appHistory[index]),
            if (index < appHistory.length - 1) const Divider(height: 32),
          ],
        ] else
          for (final row in today) _UsageRow(data: row),
      ],
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (data['package'] case final String packageName) ...[
              AppIcon(packageName: packageName, size: 36),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(data.text('label'))),
            const SizedBox(width: 12),
            Text(formatUsageDuration(data.integer('millis'))),
          ],
        ),
      );
}

class _AppUsageChart extends StatelessWidget {
  const _AppUsageChart({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final packageName = data.text('package');
    final days = data.rows('history');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (packageName.isNotEmpty) ...[
              AppIcon(packageName: packageName, size: 40),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                data.text('label'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatUsageDuration(data.integer('millis')),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'today',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 8),
          _UsageChart(
            key: ValueKey<String>('usage-chart-$packageName'),
            days: days,
          ),
        ],
      ],
    );
  }
}

const _chartAxisWidth = 36.0;
const _hourMillis = 3600000.0;

class _UsageChart extends StatelessWidget {
  const _UsageChart({super.key, required this.days});
  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 132,
            child: CustomPaint(
              painter: _UsagePainter(
                days,
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.outlineVariant,
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: _chartAxisWidth),
              for (final day in days)
                Expanded(
                  child: Text(
                    day.text('label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ],
      );
}

class _UsagePainter extends CustomPainter {
  _UsagePainter(this.days, this.line, this.grid, this.axisLabel);
  final List<Map<String, dynamic>> days;
  final Color line;
  final Color grid;
  final Color axisLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const top = 10.0;
    const bottom = 10.0;
    final height = size.height - top - bottom;
    final values = days.map((day) => day.decimal('millis')).toList();
    final maxValue = math.max(1.0, values.reduce(math.max));
    final maxHours = math.max(1, (maxValue / _hourMillis).ceil());
    final stepHours = math.max(1, (maxHours / 4).ceil());
    final chartMaxHours = ((maxHours + stepHours - 1) ~/ stepHours) * stepHours;
    final chartMaxValue = chartMaxHours * _hourMillis;
    final plotWidth = size.width - _chartAxisWidth;
    final columnWidth = plotWidth / values.length;
    final left = _chartAxisWidth + columnWidth / 2;
    final lineWidth = plotWidth - columnWidth;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var hour = 0; hour <= chartMaxHours; hour += stepHours) {
      final y = top + height * (1 - hour / chartMaxHours);
      canvas.drawLine(
        Offset(_chartAxisWidth, y),
        Offset(size.width, y),
        gridPaint,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${hour}h',
          style: TextStyle(color: axisLabel, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _chartAxisWidth - 6);
      final labelY = (y - label.height / 2)
          .clamp(0.0, size.height - label.height)
          .toDouble();
      label.paint(
        canvas,
        Offset(_chartAxisWidth - label.width - 6, labelY),
      );
    }
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? _chartAxisWidth + plotWidth / 2
          : left + lineWidth * i / (values.length - 1);
      final y = top + height * (1 - values[i] / chartMaxValue);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    canvas.drawPath(path, linePaint);
    final pointPaint = Paint()..color = line;
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_UsagePainter oldDelegate) => oldDelegate.days != days;
}
