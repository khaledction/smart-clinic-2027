import '../../core/widgets/shell_nav.dart';
import '../sessions/sessions_screen.dart';
import '../../core/widgets/patient_link.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/appointment.dart';
import '../../data/providers/appointments_provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/repositories/visit_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _reports = ReportsRepository();
  final _visitsRepo = VisitRepository();
  final _apptRepo = AppointmentRepository();

  Map<String, num> _stats = {};
  List<Appointment> _today = [];
  List<Map<String, Object?>> _followUps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _reports.dashboardNumbers();
    final now = DateTime.now();
    final appts = await _apptRepo.forDay(now);
    final followUps = await _visitsRepo.dueFollowUps(withinDays: 7);

    if (!mounted || !context.mounted) return;
    setState(() {
      _stats = stats;
      _today = appts;
      _followUps = followUps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'en_US');
    final appointments = context.watch<AppointmentsProvider>();
    context.watch<SettingsProvider>();

    if (_loading) return const Center(child: CircularProgressIndicator());

    final checkupList = _today.where((a) => a.isCheckup).toList();
    final sessionList = _today.where((a) => a.isSession).toList();
    final otherList = _today
        .where((a) => !a.isCheckup && !a.isSession)
        .toList();
    final checkups = _DayCount.of(checkupList);
    final sessions = _DayCount.of(sessionList);
    // تقسيم جلسات اليوم حسب الخدمة (القاعدة نفسها في شاشة الجلسات):
    // EMS ← الاسم يحوي EMS، سحب فقرات ← يحوي «سحب» أو «فقر».
    bool isEms(Appointment a) =>
        (a.sessionName ?? '').toLowerCase().contains('ems');
    bool isTraction(Appointment a) {
      final n = a.sessionName ?? '';
      return !isEms(a) && (n.contains('سحب') || n.contains('فقر'));
    }

    final emsList = sessionList.where(isEms).toList();
    final tractionList = sessionList.where(isTraction).toList();
    final otherSessions = sessionList
        .where((a) => !isEms(a) && !isTraction(a))
        .toList();

    void openSessions(String title, String filter) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionsScreen(title: title, serviceFilter: filter),
      ),
    );

    void openAppointments() {
      appointments.goToToday();
      ShellNav.open(1);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth > 1100 ? 6 : (c.maxWidth > 720 ? 3 : 2);
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 76,
                ),
                children: [
                  StatCard(
                    key: const Key('statCheckups'),
                    title: 'مواعيد المعاينات اليوم',
                    value: '${checkups.active}',
                    icon: Icons.medical_services_outlined,
                    color: AppColors.primary,
                    footer: _DoneFooter(
                      done: checkups.done,
                      pending: checkups.pending,
                    ),
                    onTap: () {
                      appointments.goToToday();
                      ShellNav.open(1);
                    },
                  ),
                  StatCard(
                    key: const Key('statSessions'),
                    title: 'مواعيد الجلسات اليوم',
                    value: '${sessions.active}',
                    icon: Icons.bolt_outlined,
                    color: AppColors.accent,
                    footer: _DoneFooter(
                      done: sessions.done,
                      pending: sessions.pending,
                    ),
                    onTap: () {
                      appointments.goToToday();
                      ShellNav.open(1);
                    },
                  ),
                  StatCard(
                    title: 'إجمالي المرضى',
                    value: '${_stats['patientsTotal'] ?? 0}',
                    icon: Icons.people_outline,
                    onTap: () => ShellNav.open(1),
                  ),
                  StatCard(
                    title: 'مرضى جدد هذا الشهر',
                    value: '${_stats['newPatientsMonth'] ?? 0}',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () => ShellNav.open(1),
                  ),
                  StatCard(
                    title: 'إيراد المعاينات اليوم',
                    value: currency.format(
                      _stats['incomeConsultationToday'] ?? 0,
                    ),
                    icon: Icons.payments_outlined,
                    color: AppColors.primary,
                    subtitle:
                        'الشهر: ${currency.format(_stats['incomeConsultationMonth'] ?? 0)}',
                    onTap: () => ShellNav.open(4),
                  ),
                  StatCard(
                    title: 'إيراد الجلسات اليوم',
                    value: currency.format(_stats['incomeSessionToday'] ?? 0),
                    icon: Icons.payments_outlined,
                    color: AppColors.accent,
                    subtitle:
                        'الشهر: ${currency.format(_stats['incomeSessionMonth'] ?? 0)}',
                    onTap: () => ShellNav.open(4),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // ------------ مواعيد معاينات اليوم | جلسة EMS | جلسة سحب فقرات
          LayoutBuilder(
            builder: (context, c) {
              final checkupCard = _TodayAppointmentsCard(
                key: const Key('todayCheckups'),
                title: 'مواعيد معاينات اليوم',
                icon: Icons.medical_services_outlined,
                color: AppColors.primary,
                items: checkupList,
                count: checkups,
                emptyMessage: 'لا توجد مواعيد معاينات لهذا اليوم',
                onOpen: openAppointments,
              );
              final emsCard = _TodayAppointmentsCard(
                key: const Key('todayEms'),
                title: 'جلسة EMS',
                icon: Icons.bolt_outlined,
                color: AppColors.accent,
                items: emsList,
                count: _DayCount.of(emsList),
                emptyMessage: 'لا توجد جلسات EMS لهذا اليوم',
                openTooltip: 'فتح جلسات EMS',
                onOpen: () => openSessions('جلسة EMS', 'ems'),
              );
              final tractionCard = _TodayAppointmentsCard(
                key: const Key('todayTraction'),
                title: 'جلسة سحب فقرات',
                icon: Icons.airline_seat_flat_outlined,
                color: AppColors.accent,
                items: tractionList,
                count: _DayCount.of(tractionList),
                emptyMessage: 'لا توجد جلسات سحب فقرات لهذا اليوم',
                openTooltip: 'فتح جلسات سحب الفقرات',
                onOpen: () => openSessions('جلسة سحب فقرات', 'traction'),
              );
              final cards = [checkupCard, emsCard, tractionCard];
              if (c.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
                ],
              );
            },
          ),
          // جلسات اليوم التي لا تتبع EMS ولا سحب الفقرات (إن وُجدت).
          if (otherSessions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TodayAppointmentsCard(
              key: const Key('todayOtherSessions'),
              title: 'جلسات أخرى اليوم',
              icon: Icons.more_horiz,
              color: AppColors.textSecondary,
              items: otherSessions,
              count: _DayCount.of(otherSessions),
              emptyMessage: '',
              onOpen: openAppointments,
            ),
          ],
          const SizedBox(height: 10),

          // ------------------ مواعيد قديمة بلا نوع + المراجعات المستحقة
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 1000;
              final otherCard = otherList.isEmpty
                  ? null
                  : _TodayAppointmentsCard(
                      key: const Key('todayUnknown'),
                      title: 'مواعيد اليوم غير محددة النوع',
                      icon: Icons.help_outline,
                      color: AppColors.textSecondary,
                      items: otherList,
                      count: _DayCount.of(otherList),
                      emptyMessage: '',
                      onOpen: openAppointments,
                    );

              final followCard = SectionCard(
                title: 'مراجعات مستحقة',
                icon: Icons.follow_the_signs_outlined,
                child: _followUps.isEmpty
                    ? const EmptyState(
                        message: 'لا توجد مراجعات مستحقة خلال أسبوع',
                        icon: Icons.done_all_rounded,
                      )
                    : Column(
                        children: _followUps.map((f) {
                          final name = (f['full_name'] as String?) ?? '—';
                          final due = DateFmt.parse(f['due_date'] as String?);
                          final phone = f['phone'] as String?;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.person_outline,
                              size: 19,
                              color: AppColors.warning,
                            ),
                            title: PatientLink(
                              patientId: f['patient_id'] as int,
                              name: name,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            subtitle: Text(
                              '${due == null ? '' : 'الموعد: ${DateFmt.date(due)}  •  '}'
                              '${phone?.isNotEmpty == true ? phone! : 'بدون هاتف'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              );

              if (otherCard == null) return followCard;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: otherCard),
                    const SizedBox(width: 10),
                    Expanded(child: followCard),
                  ],
                );
              }
              return Column(
                children: [otherCard, const SizedBox(height: 10), followCard],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// عدّاد مواعيد اليوم لنوع واحد: «تمت» و«لم تتم بعد».
/// الملغاة ومن لم يحضر لا تُحسب في أي منهما.
class _DayCount {
  const _DayCount(this.done, this.pending);

  factory _DayCount.of(List<Appointment> list) => _DayCount(
    list.where((a) => a.status == 'done').length,
    list.where((a) => a.status == 'scheduled' || a.status == 'arrived').length,
  );

  final int done;
  final int pending;
  int get active => done + pending;
}

/// سطر «تمت: N • لم تتم بعد: M» بلونين هادئين.
class _DoneFooter extends StatelessWidget {
  const _DoneFooter({required this.done, required this.pending});

  final int done;
  final int pending;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      children: [
        TextSpan(
          text: 'تمت: $done',
          style: const TextStyle(color: AppColors.success),
        ),
        const TextSpan(
          text: '  •  ',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        TextSpan(
          text: 'لم تتم بعد: $pending',
          style: const TextStyle(color: AppColors.warning),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

/// نافذة مواعيد اليوم لنوع واحد (معاينات أو جلسات) بالتصميم نفسه.
class _TodayAppointmentsCard extends StatelessWidget {
  const _TodayAppointmentsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.count,
    required this.emptyMessage,
    required this.onOpen,
    this.openTooltip = 'فتح شاشة المواعيد',
  });

  final String openTooltip;

  final String title;
  final IconData icon;
  final Color color;
  final List<Appointment> items;
  final _DayCount count;
  final String emptyMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: title,
    icon: icon,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _DoneFooter(done: count.done, pending: count.pending),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: openTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new, size: 18),
        ),
      ],
    ),
    child: items.isEmpty
        ? EmptyState(message: emptyMessage, icon: Icons.event_busy_outlined)
        : Column(
            children: [
              for (final a in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      DateFmt.time(a.startAt),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                  ),
                  title: PatientLink(
                    patientId: a.patientId,
                    name: a.patientName ?? '—',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  subtitle: Text(
                    [
                      a.kindLabel,
                      if (a.reason?.isNotEmpty == true) a.reason!,
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: StatusChip(
                    label: a.statusLabel,
                    color: AppColors.forAppointmentStatus(a.status),
                  ),
                ),
            ],
          ),
  );
}
