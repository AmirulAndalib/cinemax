import 'dart:math' as math;

import 'package:flutter/material.dart';

class WellnessBarDatum {
  const WellnessBarDatum({required this.label, required this.value});

  final String label;
  final int value;
}

class WellnessBarChart extends StatelessWidget {
  const WellnessBarChart({
    required this.data,
    required this.color,
    super.key,
    this.height = 176,
  });

  final List<WellnessBarDatum> data;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        data.fold<int>(0, (max, item) => math.max(max, item.value));
    final semantics = data
        .map((item) => '${item.label}: ${_duration(item.value)}')
        .join(', ');
    return Semantics(
      label: 'Viewing time chart. $semantics',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                painter: _BarChartPainter(
                  data: data,
                  maxValue: maxValue,
                  color: color,
                  gridColor: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: .45),
                  labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  textDirection: Directionality.of(context),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class WellnessDonutChart extends StatelessWidget {
  const WellnessDonutChart({
    required this.values,
    required this.colors,
    required this.centerLabel,
    super.key,
    this.size = 144,
  });

  final List<int> values;
  final List<Color> colors;
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return Semantics(
      label: '$centerLabel. Total ${_duration(total)}',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _DonutPainter(
                values: values,
                colors: colors,
                emptyColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            Center(
              child: Text(
                centerLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WellnessHeatmap extends StatelessWidget {
  const WellnessHeatmap({required this.values, super.key});

  final List<List<int>> values;

  static const _days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxValue = values.expand((row) => row).fold<int>(
          0,
          (max, value) => math.max(max, value),
        );
    return Semantics(
      label: 'Viewing time by weekday and hour',
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 22),
              for (final hour in const <String>['12a', '6a', '12p', '6p'])
                Expanded(
                  child: Text(
                    hour,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var day = 0; day < 7; day++) ...[
            Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    _days[day],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (var hour = 0; hour < 24; hour++)
                  Expanded(
                    child: Container(
                      height: 15,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: maxValue == 0
                              ? .04
                              : .06 + .88 * values[day][hour] / maxValue,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    required this.textDirection,
  });

  final List<WellnessBarDatum> data;
  final int maxValue;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 24.0;
    final chartHeight = size.height - labelHeight;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var line = 0; line <= 3; line++) {
      final y = chartHeight * line / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (data.isEmpty) return;
    final slot = size.width / data.length;
    final barWidth = math.max(3.0, math.min(22.0, slot * .62));
    final paint = Paint()..color = color;
    for (var index = 0; index < data.length; index++) {
      final ratio = maxValue == 0 ? 0.0 : data[index].value / maxValue;
      final barHeight = math.max(
        data[index].value == 0 ? 0.0 : 3.0,
        chartHeight * ratio,
      );
      final left = slot * index + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, chartHeight - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
      if (data.length <= 14 || index.isEven) {
        final text = TextPainter(
          text: TextSpan(
            text: data[index].label,
            style: TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: textDirection,
          maxLines: 1,
        )..layout(maxWidth: slot);
        text.paint(
          canvas,
          Offset(slot * index + (slot - text.width) / 2, chartHeight + 7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.color != color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.emptyColor,
  });

  final List<int> values;
  final List<Color> colors;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * .14;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    if (total <= 0) {
      paint.color = emptyColor;
      canvas.drawArc(arcRect, 0, math.pi * 2, false, paint);
      return;
    }
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      if (values[index] <= 0) continue;
      final sweep = math.pi * 2 * values[index] / total;
      paint.color = colors[index % colors.length];
      canvas.drawArc(arcRect, start, math.max(0, sweep - .035), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

String _duration(int milliseconds) {
  final minutes = Duration(milliseconds: milliseconds).inMinutes;
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return hours == 0 ? '${remainder}m' : '${hours}h ${remainder}m';
}
