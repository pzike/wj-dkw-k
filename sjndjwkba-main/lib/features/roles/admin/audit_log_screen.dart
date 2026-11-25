// lib/features/roles/admin/audit_log_screen.dart
//
// Master audit log (Admin only): role changes, escalations, and credit
// changes, newest first. Names come from the user repository.

import 'package:flutter/material.dart';

import '../../../core/data/config_repository.dart';
import '../../../core/data/user_repository.dart';
import '../../../core/models/drainage_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_heading.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.configs, required this.users});

  final ConfigRepository configs;
  final UserRepository users;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  static const int _pageSize = 50;

  final List<TimelineEntry> _entries = <TimelineEntry>[];
  Map<String, PersonSummary> _names = <String, PersonSummary>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final page = await widget.configs.fetchAuditLog(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page);
        _hasMore = page.length >= _pageSize;
        _error = null;
        _loading = false;
      });
      await _loadNames(page);
    } catch (e) {
      if (!mounted) return;
      if (_entries.isEmpty) {
        setState(() {
          _error = e;
          _loading = false;
        });
      } else {
        showAppToast(context, errorText(e));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _entries.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.configs.fetchAuditLog(
        limit: _pageSize,
        before: _entries.last.at,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
      await _loadNames(page);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showAppToast(context, errorText(e));
    }
  }

  Future<void> _loadNames(List<TimelineEntry> page) async {
    final ids = <String>{
      for (final e in page)
        if (e.actorId != null && !_names.containsKey(e.actorId)) e.actorId!,
    };
    if (ids.isEmpty) return;
    try {
      final found = await widget.users.lookup(ids);
      if (!mounted) return;
      setState(() => _names = <String, PersonSummary>{..._names, ...found});
    } catch (_) {
      // Entries show "Unknown person" for ids the server did not return.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final background = Color.alphaBlend(
      scheme.surfaceContainerHighest.withAlpha(90),
      scheme.surface,
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(title: const Text('Audit log')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load the audit log',
        message: errorText(_error!),
        actionLabel: 'Try again',
        onAction: () {
          setState(() {
            _error = null;
            _loading = true;
          });
          _refresh();
        },
      );
    }

    final scheme = context.colors;
    final text = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase();
    final visibleEntries = _entries.where((entry) {
      if (query.isEmpty) return true;
      final actor =
          entry.actorId == null ? '' : nameOf(_names, entry.actorId!);
      return '${entry.label} $actor ${formatDateTime(entry.at)}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
        children: [
          const SectionHeading(
            eyebrow: 'System',
            title: 'Audit log',
            subtitle: 'A searchable timeline of system activity.',
          ),
          const SizedBox(height: 14),
          AppCard(
            accent: scheme.primary,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_entries.length} events loaded · newest first',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search loaded events',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (visibleEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No matching events',
                message: 'Try another search or load older events.',
              ),
            )
          else
            for (final entry in visibleEntries) ...[
              _AuditEventCard(
                entry: entry,
                actor: entry.actorId == null
                    ? null
                    : nameOf(_names, entry.actorId!),
              ),
              const SizedBox(height: 10),
            ],
          if (_hasMore)
            OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              style: bigOutlinedStyle(),
              child: _loadingMore
                  ? const ButtonSpinner(onFilled: false)
                  : const Text('Load older events'),
            ),
        ],
      ),
    );
  }
}

class _AuditEventCard extends StatelessWidget {
  const _AuditEventCard({required this.entry, required this.actor});

  final TimelineEntry entry;
  final String? actor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;
    final label = entry.label.toLowerCase();
    final icon = label.contains('role') || label.contains('account')
        ? Icons.manage_accounts_outlined
        : label.contains('escalat') || label.contains('alert')
            ? Icons.warning_amber_rounded
            : label.contains('remark')
                ? Icons.notes_rounded
                : Icons.fact_check_outlined;
    final color = label.contains('critical')
        ? context.status.stage3
        : label.contains('role') || label.contains('account')
            ? scheme.primary
            : label.contains('escalat') || label.contains('alert')
                ? context.status.stage2
                : scheme.secondary;

    return AppCard(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (actor != null)
                      AppPill(
                        label: actor!,
                        icon: Icons.person_outline_rounded,
                      ),
                    Text(
                      formatDateTime(entry.at),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
