import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/status_colors.dart';
import 'widgets/app_card.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = StatusColors.on(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.stage,
    required this.title,
    required this.countdownText,
    required this.onOpen,
  });

  final int stage;
  final String title;
  final String countdownText;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = context.status.forStage(stage);
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      accent: color,
      onTap: onOpen,
      semanticLabel: '$title. $countdownText. Open alert details.',
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(90)),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  countdownText,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  'View details',
                  style: text.labelLarge?.copyWith(color: scheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class WaterLevelGauge extends StatelessWidget {
  const WaterLevelGauge({
    super.key,
    required this.currentStage,
    this.isStale = false,
  });

  final int currentStage;
  final bool isStale;

  String _stageLabel() {
    if (isStale) return 'Status unknown (stale data)';
    switch (currentStage) {
      case 1:
        return 'Stage 1 — Elevated water';
      case 2:
        return 'Stage 2 — Clog warning';
      case 3:
        return 'Stage 3 — Critical (over curb)';
      default:
        return 'All normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = isStale
        ? context.status.stale
        : context.status.forStage(currentStage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (index) {
            final barStage = index + 1;
            final isFilled = !isStale && currentStage >= barStage;
            final barColor = isFilled
                ? context.status.forStage(barStage)
                : context.colors.outlineVariant;

            return Expanded(
              child: Container(
                height: 16,
                margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _stageLabel(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TimelineStep {
  const TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
  });

  final String title;
  final String subtitle;
  final bool isCompleted;
}

class EscalationTimeline extends StatelessWidget {
  const EscalationTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final dotColor = step.isCompleted
            ? context.colors.primary
            : context.colors.outline;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.isCompleted
                            ? dotColor
                            : context.colors.surface,
                        border: Border.all(color: dotColor, width: 2),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: context.colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: step.isCompleted
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: step.isCompleted
                              ? context.colors.onSurface
                              : context.colors.onSurfaceVariant,
                        ),
                      ),
                      if (step.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          step.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({super.key, required this.lastSeenText});

  final String lastSeenText;

  @override
  Widget build(BuildContext context) {
    final color = context.status.stale;
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors_off_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No recent data. This is not an all-clear.',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  lastSeenText,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
