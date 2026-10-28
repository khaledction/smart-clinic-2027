import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../theme/app_colors.dart';

/// ملف قابل للمعاينة (صورة أو PDF). يُحمَّل عند الحاجة فقط.
class ViewerFile {
  const ViewerFile({required this.name, required this.load});

  final String name;
  final Future<Uint8List> Function() load;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// نافذة «معاينة الصور أو PDF» مع التكبير والتصغير:
/// • دولاب الفأرة للتكبير/التصغير، والسحب لتحريك الصورة.
/// • لوحة المفاتيح: «+» للتكبير و«−» للتصغير (ومنها Fn + و Fn − في
///   الحواسيب المحمولة، وأزرار الـ Numpad، ومع Ctrl أيضاً)، و«0» لإعادة الحجم.
class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer({super.key, required this.files, this.initial = 0});

  final List<ViewerFile> files;
  final int initial;

  static Future<void> show(
    BuildContext context,
    List<ViewerFile> files, {
    int initial = 0,
  }) => showDialog<void>(
    context: context,
    builder: (_) => AttachmentViewer(files: files, initial: initial),
  );

  @override
  State<AttachmentViewer> createState() => AttachmentViewerState();
}

@visibleForTesting
class AttachmentViewerState extends State<AttachmentViewer> {
  static const minScale = 0.5;
  static const maxScale = 8.0;
  static const step = 1.25;

  final _controller = TransformationController();
  final _focus = FocusNode(debugLabel: 'attachmentViewer');
  late int _index = widget.initial.clamp(0, widget.files.length - 1);
  int _page = 0;
  Size _viewport = Size.zero;

  /// صفحات الملف الحالي كصور (صورة واحدة، أو صفحات PDF).
  late Future<List<Uint8List>> _pages = _loadPages();

  double get scale => _controller.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTransform() {
    if (mounted) setState(() {});
  }

  Future<List<Uint8List>> _loadPages() async {
    final file = widget.files[_index];
    final bytes = await file.load();
    if (!file.isPdf) return [bytes];
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: 144)) {
      pages.add(await page.toPng());
    }
    if (pages.isEmpty) throw StateError('ملف PDF فارغ');
    return pages;
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _page = 0;
      _controller.value = Matrix4.identity();
      _pages = _loadPages();
    });
    _focus.requestFocus();
  }

  /// تكبير/تصغير حول منتصف منطقة العرض.
  void zoomBy(double factor) {
    final current = scale;
    final target = (current * factor).clamp(minScale, maxScale);
    final f = target / current;
    if (f == 1) return;
    final c = _viewport.center(Offset.zero);
    final zoom = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    _controller.value = zoom.multiplied(_controller.value);
  }

  void resetZoom() => _controller.value = Matrix4.identity();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final char = event.character;
    if (key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        key == LogicalKeyboardKey.equal ||
        char == '+' ||
        char == '=') {
      zoomBy(step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        char == '-' ||
        char == '−') {
      zoomBy(1 / step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      resetZoom();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final file = widget.files[_index];
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.frame),
      ),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.88,
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(file),
              if (widget.files.length > 1) _fileStrip(),
              Expanded(child: _body()),
              _hint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(ViewerFile file) => Container(
    color: AppColors.headerTint,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        Icon(
          file.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          color: AppColors.navy,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'معاينة الصور أو PDF — ${file.name}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
        IconButton.filled(
          key: const Key('zoomOut'),
          tooltip: 'تصغير (−)',
          style: _iconStyle,
          onPressed: () => zoomBy(1 / step),
          icon: const Icon(Icons.zoom_out),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '${(scale * 100).round()}%',
            key: const Key('zoomLabel'),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.filled(
          key: const Key('zoomIn'),
          tooltip: 'تكبير (+)',
          style: _iconStyle,
          onPressed: () => zoomBy(step),
          icon: const Icon(Icons.zoom_in),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'الحجم الأصلي (0)',
          style: _iconStyle,
          onPressed: resetZoom,
          icon: const Icon(Icons.fit_screen_outlined),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('إغلاق'),
        ),
      ],
    ),
  );

  static final _iconStyle = IconButton.styleFrom(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    fixedSize: const Size.square(40),
  );

  Widget _fileStrip() => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < widget.files.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                avatar: Icon(
                  widget.files[i].isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 16,
                ),
                label: Text(widget.files[i].name),
                selected: i == _index,
                onSelected: (_) => _select(i),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _body() => FutureBuilder<List<Uint8List>>(
    future: _pages,
    builder: (context, s) {
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'تعذّر عرض الملف هنا. يمكنك حفظ نسخة منه وفتحها من «المرفقات».\n${s.error}',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final pages = s.data!;
      final page = _page.clamp(0, pages.length - 1);
      return Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                _viewport = c.biggest;
                return ColoredBox(
                  color: const Color(0xFFEFF3F7),
                  child: InteractiveViewer(
                    key: const Key('attachmentZoom'),
                    transformationController: _controller,
                    minScale: minScale,
                    maxScale: maxScale,
                    boundaryMargin: const EdgeInsets.all(400),
                    child: SizedBox(
                      width: c.maxWidth,
                      height: c.maxHeight,
                      child: Image.memory(
                        pages[page],
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Text('صيغة الصورة غير مدعومة')),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (pages.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: page == 0
                        ? null
                        : () => setState(() {
                            _page = page - 1;
                            resetZoom();
                          }),
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('الصفحة السابقة'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('صفحة ${page + 1} من ${pages.length}'),
                  ),
                  TextButton.icon(
                    onPressed: page >= pages.length - 1
                        ? null
                        : () => setState(() {
                            _page = page + 1;
                            resetZoom();
                          }),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('الصفحة التالية'),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _hint() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: AppColors.headerTint,
    child: const Text(
      'للتكبير: دولاب الفأرة أو مفتاح +   •   للتصغير: مفتاح −   •   مفتاح 0 للحجم الأصلي   •   اسحب لتحريك الصورة',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );
}

