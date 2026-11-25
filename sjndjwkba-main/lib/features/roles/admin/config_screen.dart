// lib/features/roles/admin/config_screen.dart
//
// System and Escalation Configuration (Admin only): the escalation timeout
// and the stale-data threshold. Settings live on the server, so a change
// applies without redeploying the app. The master audit log opens from here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/alert_repository.dart';
import '../../../core/data/config_repository.dart';
import '../../../core/data/user_repository.dart';
import '../../../core/models/drainage_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/load_view.dart';
import '../../../shared/widgets/section_heading.dart';
import 'audit_log_screen.dart';
import 'remarks_history_screen.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({
    super.key,
    required this.configs,
    required this.users,
    required this.alerts,
  });

  final ConfigRepository configs;
  final AlertRepository alerts;

  /// Used by the audit log to turn user ids into names.
  final UserRepository users;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final background = Color.alphaBlend(
      scheme.surfaceContainerHighest.withAlpha(90),
      scheme.surface,
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(title: const Text('Config')),
      body: LoadView<SystemConfig>(
        load: configs.fetch,
        builder: (context, config, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
            children: [
              const SectionHeading(
                eyebrow: 'System',
                title: 'Escalation settings',
                subtitle: 'Changes apply to everyone without an app update.',
              ),
              const SizedBox(height: 14),
              _ConfigForm(configs: configs, initial: config),
              const SizedBox(height: 14),
              _AdminHistoryLink(
                title: 'Audit log',
                subtitle: 'Account, role, and system activity.',
                icon: Icons.fact_check_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          AuditLogScreen(configs: configs, users: users),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _AdminHistoryLink(
                title: 'Past response remarks',
                subtitle: 'Review notes recorded on previous incidents.',
                icon: Icons.notes_rounded,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          RemarksHistoryScreen(alerts: alerts, users: users),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigForm extends StatefulWidget {
  const _ConfigForm({required this.configs, required this.initial});

  final ConfigRepository configs;
  final SystemConfig initial;

  @override
  State<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends State<_ConfigForm> {
  late Duration _savedEscalation;
  late Duration _savedStale;
  bool _saving = false;
  String? _error;
  late final TextEditingController _escalationDays;
  late final TextEditingController _escalationHours;
  late final TextEditingController _escalationMinutes;
  late final TextEditingController _staleDays;
  late final TextEditingController _staleHours;
  late final TextEditingController _staleMinutes;

  @override
  void initState() {
    super.initState();
    _savedEscalation = widget.initial.escalationTimeout;
    _savedStale = widget.initial.staleAfter;
    _escalationDays = _controller(_savedEscalation.inDays);
    _escalationHours = _controller(_savedEscalation.inHours % 24);
    _escalationMinutes = _controller(_savedEscalation.inMinutes % 60);
    _staleDays = _controller(_savedStale.inDays);
    _staleHours = _controller(_savedStale.inHours % 24);
    _staleMinutes = _controller(_savedStale.inMinutes % 60);
  }

  TextEditingController _controller(int value) =>
      TextEditingController(text: value.toString());

  @override
  void dispose() {
    _escalationDays.dispose();
    _escalationHours.dispose();
    _escalationMinutes.dispose();
    _staleDays.dispose();
    _staleHours.dispose();
    _staleMinutes.dispose();
    super.dispose();
  }

  Duration? _duration(
    TextEditingController days,
    TextEditingController hours,
    TextEditingController minutes,
  ) {
    final dayValue = int.tryParse(days.text);
    final hourValue = int.tryParse(hours.text);
    final minuteValue = int.tryParse(minutes.text);
    if (dayValue == null ||
        hourValue == null ||
        minuteValue == null ||
        dayValue < 0 ||
        dayValue > 36500 ||
        hourValue < 0 ||
        hourValue > 23 ||
        minuteValue < 0 ||
        minuteValue > 59) {
      return null;
    }
    final value = Duration(
      days: dayValue,
      hours: hourValue,
      minutes: minuteValue,
    );
    return value == Duration.zero ? null : value;
  }

  Duration? get _escalation =>
      _duration(_escalationDays, _escalationHours, _escalationMinutes);
  Duration? get _stale => _duration(_staleDays, _staleHours, _staleMinutes);

  bool get _changed =>
      _escalation != _savedEscalation || _stale != _savedStale;

  void _setDuration(
    Duration duration,
    TextEditingController days,
    TextEditingController hours,
    TextEditingController minutes,
  ) {
    days.text = duration.inDays.toString();
    hours.text = (duration.inHours % 24).toString();
    minutes.text = (duration.inMinutes % 60).toString();
  }

  Future<void> _save() async {
    final escalation = _escalation;
    final stale = _stale;
    if (escalation == null || stale == null) {
      setState(() {
        _error =
            'Enter a positive duration. Hours must be 0–23 and minutes 0–59.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final stored = await widget.configs.update(
        SystemConfig(
          escalationTimeout: escalation,
          staleAfter: stale,
        ),
      );
      if (!mounted) return;
      setState(() {
        _savedEscalation = stored.escalationTimeout;
        _savedStale = stored.staleAfter;
        _setDuration(
          _savedEscalation,
          _escalationDays,
          _escalationHours,
          _escalationMinutes,
        );
        _setDuration(
          _savedStale,
          _staleDays,
          _staleHours,
          _staleMinutes,
        );
        _saving = false;
      });
      showAppToast(context, 'Settings saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Timers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DurationEditor(
            label: 'Escalation timeout',
            help: 'How long an unacknowledged alert waits before it moves '
                'to the next level.',
            days: _escalationDays,
            hours: _escalationHours,
            minutes: _escalationMinutes,
            enabled: !_saving,
            onChanged: () => setState(() => _error = null),
          ),
          const Divider(height: 28),
          _DurationEditor(
            label: 'Stale data after',
            help: 'How long without a node report before the app shows '
                '"No recent data".',
            days: _staleDays,
            hours: _staleHours,
            minutes: _staleMinutes,
            enabled: !_saving,
            onChanged: () => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            InlineError(message: _error!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: (_saving || !_changed) ? null : _save,
            style: bigFilledStyle(),
            child: _saving ? const ButtonSpinner() : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _AdminHistoryLink extends StatelessWidget {
  const _AdminHistoryLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Open $title',
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _DurationEditor extends StatelessWidget {
  const _DurationEditor({
    required this.label,
    required this.help,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String help;
  final TextEditingController days;
  final TextEditingController hours;
  final TextEditingController minutes;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          '$help Enter days, hours, and minutes directly.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _DurationPartField(label: 'Days', controller: days, enabled: enabled, onChanged: onChanged)),
            const SizedBox(width: 8),
            Expanded(child: _DurationPartField(label: 'Hours', controller: hours, enabled: enabled, onChanged: onChanged)),
            const SizedBox(width: 8),
            Expanded(child: _DurationPartField(label: 'Minutes', controller: minutes, enabled: enabled, onChanged: onChanged)),
          ],
        ),
      ],
    );
  }
}

class _DurationPartField extends StatelessWidget {
  const _DurationPartField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: label),
      );
}
