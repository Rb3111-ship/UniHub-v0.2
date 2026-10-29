import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Small, dependency-free charts for the organizer statistics.

/// Coloured dots with labels, e.g. "Registered  Confirmed  Came".
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final (label, color) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

/// One horizontal bar: [value] out of [max], with the number at the end.
class HBar extends StatelessWidget {
  const HBar({super.key, required this.value, required this.max, required this.color, this.label, this.height = 10});

  final num value;
  final num max;
  final Color color;
  final String? label; // shown in front of the bar
  final double height;

  @override
  Widget build(BuildContext context) {
    final share = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (label != null)
            SizedBox(width: 28, child: Text(label!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: math.max(share * c.maxWidth, value > 0 ? 3 : 0),
                  height: height,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text('$value', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Vertical bars with a label under each and the value on top.
class VBars extends StatelessWidget {
  const VBars({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.maxValue,
    this.valueText,
    this.height = 150,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final double? maxValue;
  final String Function(double)? valueText;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = maxValue ?? values.fold<double>(0, math.max);
    final many = values.length > 12;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: many ? 1 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!many && values[i] > 0)
                      FittedBox(
                        child: Text(valueText?.call(values[i]) ?? values[i].round().toString(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: top <= 0 ? 0 : (values[i] / top).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: FittedBox(
                        child: Text(labels[i], style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
