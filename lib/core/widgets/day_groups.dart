import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_fmt.dart';

/// Months contain independently collapsible days. Only current month/today
/// open by default. A local month-boundary timer resets month expansion.
class DayGroups<T> extends StatefulWidget {
  const DayGroups({
    super.key,
    required this.items,
    required this.dateOf,
    required this.groupBuilder,
    this.noun = 'سجل',
    this.searching = false,
    this.oldestFirst = false,
  });
  final List<T> items;
  final DateTime? Function(T) dateOf;
  final Widget Function(List<T>) groupBuilder;
  final String noun;
  final bool searching;
  final bool oldestFirst;
  @override
  State<DayGroups<T>> createState() => _DayGroupsState<T>();
}

class _DayGroupsState<T> extends State<DayGroups<T>> {
  final _months = <String, bool>{};
  final _days = <String, bool>{};
  Timer? _timer;
  String _currentMonth = '';
  String _month(DateTime d) => DateFmt.isoDate(d).substring(0, 7);
  @override
  void initState() {
    super.initState();
    _currentMonth = _month(DateTime.now());
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(
      DateTime(now.year, now.month + 1).difference(now) +
          const Duration(milliseconds: 50),
      () {
        if (!mounted) return;
        setState(() {
          _currentMonth = _month(DateTime.now());
          _months.clear();
        });
        _schedule();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DayGroups<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searching != widget.searching) {
      _months.clear();
      _days.clear();
    }
  }

  int _sort(String a, String b) {
    if (a == 'غير محدد') return a == b ? 0 : 1;
    if (b == 'غير محدد') return -1;
    return widget.oldestFirst ? a.compareTo(b) : b.compareTo(a);
  }

  Widget _tile({
    required String id,
    required bool expanded,
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueChanged<bool> changed,
    required List<Widget> children,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ExpansionTile(
      key: ValueKey('$id-$expanded'),
      initiallyExpanded: expanded,
      onExpansionChanged: changed,
      maintainState: false,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: AppColors.primary, size: 18),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      children: children,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = _month(now);
    if (_currentMonth != current) {
      _currentMonth = current;
      _months.clear();
      _schedule();
    }
    final today = DateFmt.isoDate(now);
    final groups = <String, Map<String, List<T>>>{};
    for (final item in widget.items) {
      final date = widget.dateOf(item);
      final month = date == null ? 'غير محدد' : _month(date);
      final day = date == null ? 'غير محدد' : DateFmt.isoDate(date);
      groups.putIfAbsent(month, () => {}).putIfAbsent(day, () => []).add(item);
    }
    final months = groups.keys.toList()..sort(_sort);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final month in months)
          _tile(
            id: 'month-$month',
            expanded: _months[month] ?? (widget.searching || month == current),
            title: month == 'غير محدد'
                ? 'دون تاريخ'
                : 'شهر ${month.replaceAll('-', '/')} ${month == current ? '— الحالي' : ''}',
            subtitle:
                '${groups[month]!.values.fold<int>(0, (n, rows) => n + rows.length)} ${widget.noun} • ${groups[month]!.length} يوم',
            icon: Icons.calendar_month_outlined,
            changed: (v) => setState(() => _months[month] = v),
            children: [
              for (final day in (groups[month]!.keys.toList()..sort(_sort)))
                _tile(
                  id: 'day-$day',
                  expanded: _days[day] ?? (widget.searching || day == today),
                  title: day == 'غير محدد'
                      ? 'تاريخ غير محدد'
                      : '${day == today ? 'اليوم' : 'يوم'} ${day.replaceAll('-', '/')}',
                  subtitle: '${groups[month]![day]!.length} ${widget.noun}',
                  icon: Icons.today_outlined,
                  changed: (v) => setState(() => _days[day] = v),
                  children: [widget.groupBuilder(groups[month]![day]!)],
                ),
            ],
          ),
      ],
    );
  }
}

