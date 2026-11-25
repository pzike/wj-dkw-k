import 'package:flutter/material.dart';

import '../../../core/data/alert_repository.dart';
import '../../../core/data/user_repository.dart';
import '../../../core/models/drainage_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../history/response_metrics.dart';

class RemarksHistoryScreen extends StatefulWidget {
  const RemarksHistoryScreen({
    super.key,
    required this.alerts,
    required this.users,
  });

  final AlertRepository alerts;
  final UserRepository users;

  @override
  State<RemarksHistoryScreen> createState() => _RemarksHistoryScreenState();
}

class _RemarksHistoryScreenState extends State<RemarksHistoryScreen> {
  static const int _pageSize = 50;

  final List<DrainageAlert> _alerts = [];
  final Map<String, PersonSummary> _names = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final page = await widget.alerts.fetchHistory(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _alerts
          ..clear()
          ..addAll(page);
        _hasMore = page.length >= _pageSize;
        _error = null;
        _loading = false;
      });
      await _loadNames(page);
    } catch (error) {
      if (!mounted) return;
      if (_alerts.isEmpty) {
        setState(() {
          _error = error;
          _loading = false;
        });
      } else {
        showAppToast(context, errorText(error));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _alerts.isEmpty) return;
    final before = _alerts.last.pagingTime;
    if (before == null) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await widget.alerts.fetchHistory(
        limit: _pageSize,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        _alerts.addAll(page);
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
      await _loadNames(page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showAppToast(context, errorText(error));
    }
  }

  Future<void> _loadNames(List<DrainageAlert> alerts) async {
    final ids = <String>{
      for (final alert in alerts)
        for (final remark in alert.remarks)
          if (!_names.containsKey(remark.authorId)) remark.authorId,
    };
    if (ids.isEmpty) return;
    try {
      final names = await widget.users.lookup(ids);
      if (!mounted) return;
      setState(() => _names.addAll(names));
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final remarks = [
      for (final alert in _alerts)
        for (final remark in alert.remarks)
          _RemarkRecord(alert: alert, remark: remark),
    ]..sort((a, b) => b.remark.at.compareTo(a.remark.at));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Past response remarks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _alerts.isEmpty
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load past remarks',
                  message: errorText(_error!),
                  actionLabel: 'Try again',
                  onAction: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _refresh();
                  },
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      AppCard(
                        accent: scheme.primary,
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, color: scheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Remarks from completed and active incidents, '
                                'newest first.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (remarks.isEmpty)
                        const EmptyState(
                          icon: Icons.notes_rounded,
                          title: 'No remarks found',
                          message: 'Response notes will appear here after they '
                              'are added to an incident.',
                        )
                      else
                        for (final record in remarks) ...[
                          _RemarkCard(
                            record: record,
                            author: nameOf(_names, record.remark.authorId),
                          ),
                          const SizedBox(height: 10),
                        ],
                      if (_hasMore)
                        OutlinedButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          style: bigOutlinedStyle(),
                          child: _loadingMore
                              ? const ButtonSpinner(onFilled: false)
                              : const Text('Load older remarks'),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _RemarkRecord {
  const _RemarkRecord({required this.alert, required this.remark});

  final DrainageAlert alert;
  final AlertRemark remark;
}

class _RemarkCard extends StatelessWidget {
  const _RemarkCard({required this.record, required this.author});

  final _RemarkRecord record;
  final String author;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = Theme.of(context).textTheme;
    final color = context.status.forStage(record.alert.stage);

    return AppCard(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppPill(
                label: 'Stage ${record.alert.stage}',
                color: color,
                icon: Icons.water_outlined,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  formatDateTime(record.remark.at),
                  textAlign: TextAlign.end,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(record.remark.text, style: text.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  author,
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                'Node ${record.alert.nodeId}',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
