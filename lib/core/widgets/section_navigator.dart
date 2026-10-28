import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ChartSection {
  const ChartSection(this.title, this.icon, this.child);
  final String title;
  final IconData icon;
  final Widget child;
}

/// One scrollable page; fields remain mounted when collapsed, so drafts survive.
class SectionNavigator extends StatefulWidget {
  const SectionNavigator({
    super.key,
    required this.sections,
    this.expandAll = false,
  });
  final List<ChartSection> sections;
  final bool expandAll;
  @override
  State<SectionNavigator> createState() => SectionNavigatorState();
}

class SectionNavigatorState extends State<SectionNavigator> {
  late final List<GlobalKey> _keys = List.generate(
    widget.sections.length,
    (_) => GlobalKey(),
  );
  late final Set<int> _open = {
    if (widget.expandAll)
      ...List.generate(widget.sections.length, (i) => i)
    else
      0,
  };
  int _selected = 0;
  void openAll() => setState(
    () => _open.addAll(List.generate(widget.sections.length, (i) => i)),
  );
  Future<void> go(int i) async {
    setState(() {
      _selected = i;
      _open.add(i);
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final ctx = _keys[i].currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final nav = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              // Transparent Material keeps ink/selected paint above the
              // tinted column (ListTile paints on its nearest Material).
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  mouseCursor: SystemMouseCursors.click,
                  selected: _selected == i,
                  selectedTileColor: const Color(0xFFE3F0F4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: Icon(widget.sections[i].icon, size: 20),
                  title: Text(
                    widget.sections[i].title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => go(i),
                ),
              ),
            ),
        ],
      );
      final page = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.sections.length; i++)
              Container(
                key: _keys[i],
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDFE7EE)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: AppColors.headerTint,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        mouseCursor: SystemMouseCursors.click,
                        dense: true,
                        leading: Icon(
                          widget.sections[i].icon,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        title: Text(
                          widget.sections[i].title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => setState(() {
                          _selected = i;
                          if (!_open.add(i)) _open.remove(i);
                        }),
                      ),
                    ),
                    Visibility(
                      visible: _open.contains(i),
                      maintainState: true,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: widget.sections[i].child,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 190,
              margin: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              decoration: BoxDecoration(
                color: AppColors.navColumn,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: nav,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: page),
          ],
        );
      }
      return Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < widget.sections.length; i++)
                  TextButton(
                    onPressed: () => go(i),
                    child: Text(widget.sections[i].title),
                  ),
              ],
            ),
          ),
          Expanded(child: page),
        ],
      );
    },
  );
}

