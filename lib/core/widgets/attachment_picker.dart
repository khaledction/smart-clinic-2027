import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../theme/app_colors.dart';
import 'attachment_viewer.dart';

/// اختيار مرفق ثم «معاينة» أو «تحميل» أو «إلغاء».
/// • مرفق واحد: زر «معاينة المرفق» يفتح المعاينة مباشرة.
/// • أكثر من مرفق: تظهر القائمة؛ يُحدَّد المرفق بالدائرة، أو بالضغط على اسمه
///   فتظهر خيارات: معاينة / تحميل / إلغاء.
class AttachmentPicker extends StatefulWidget {
  const AttachmentPicker({super.key, required this.files});

  final List<ViewerFile> files;

  /// يختار مكان الحفظ. قابل للاستبدال في الاختبارات.
  static Future<String?> Function(String fileName) pickSaveTarget = (name) =>
      FilePicker.platform.saveFile(dialogTitle: 'تحميل المرفق', fileName: name);

  /// زر «معاينة المرفق»: مباشرة لمرفق واحد، وإلا قائمة الاختيار.
  static Future<void> preview(BuildContext context, List<ViewerFile> files) {
    if (files.length == 1) return AttachmentViewer.show(context, files);
    return show(context, files);
  }

  static Future<void> show(BuildContext context, List<ViewerFile> files) =>
      showDialog<void>(
        context: context,
        builder: (_) => AttachmentPicker(files: files),
      );

  /// يحفظ نسخة من المرفق في المكان الذي يختاره المستخدم.
  /// يعيد المسار، أو null إذا أُلغي الاختيار.
  static Future<String?> download(ViewerFile file) async {
    var target = await pickSaveTarget(path.basename(file.name));
    if (target == null) return null;
    if (path.extension(target).isEmpty) {
      target = '$target${path.extension(file.name)}';
    }
    await File(target).writeAsBytes(await file.load(), flush: true);
    return target;
  }

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

enum _Choice { preview, download }

class _AttachmentPickerState extends State<AttachmentPicker> {
  int _selected = 0;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  List<ViewerFile> get _files => widget.files;

  Future<void> _preview(int i) =>
      AttachmentViewer.show(context, _files, initial: i);

  Future<void> _download(int i) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final saved = await AttachmentPicker.download(_files[i]);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = saved == null ? null : 'تم تحميل المرفق إلى: $saved';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = 'تعذر تحميل المرفق: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// خيارات المرفق عند الضغط على اسمه.
  Future<void> _options(int i) async {
    setState(() => _selected = i);
    final f = _files[i];
    final choice = await showDialog<_Choice>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('attOptions'),
        title: Row(
          children: [
            Icon(_iconFor(f), color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(child: Text(f.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: const Text('ماذا تريد أن تفعل بهذا المرفق؟'),
        actions: [
          FilledButton.icon(
            key: const Key('attOptPreview'),
            onPressed: () => Navigator.pop(ctx, _Choice.preview),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('معاينة'),
          ),
          FilledButton.icon(
            key: const Key('attOptDownload'),
            onPressed: () => Navigator.pop(ctx, _Choice.download),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('تحميل'),
          ),
          TextButton.icon(
            key: const Key('attOptCancel'),
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _Choice.preview:
        await _preview(i);
      case _Choice.download:
        await _download(i);
      case null:
        break;
    }
  }

  static IconData _iconFor(ViewerFile f) =>
      f.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined;

  @override
  Widget build(BuildContext context) {
    final empty = _files.isEmpty;
    return AlertDialog(
      key: const Key('attachmentPicker'),
      title: Row(
        children: [
          const Icon(Icons.photo_library_outlined, color: AppColors.navy),
          const SizedBox(width: 8),
          Text(empty ? 'المرفقات' : 'المرفقات (${_files.length})'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: empty
            ? const Text('لا توجد مرفقات لهذا الفحص.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: RadioGroup<int>(
                      groupValue: _selected,
                      onChanged: (v) {
                        if (v != null) setState(() => _selected = v);
                      },
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _files.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final f = _files[i];
                          final sel = i == _selected;
                          return Material(
                            color: sel
                                ? AppColors.navy.withValues(alpha: 0.07)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: sel
                                    ? AppColors.navy
                                    : AppColors.navy.withValues(alpha: 0.15),
                              ),
                            ),
                            child: ListTile(
                              key: Key('attRow$i'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Radio<int>(
                                    key: Key('attRadio$i'),
                                    activeColor: AppColors.navy,
                                    value: i,
                                  ),
                                  Icon(_iconFor(f), color: AppColors.navy),
                                ],
                              ),
                              title: Text(
                                f.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              subtitle: Text(f.isPdf ? 'ملف PDF' : 'صورة'),
                              trailing: const Icon(Icons.more_horiz),
                              onTap: _busy ? null : () => _options(i),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _isError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 18,
                          color: _isError ? Colors.red : AppColors.paid,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _message!,
                            key: const Key('attMessage'),
                            style: TextStyle(
                              color: _isError ? Colors.red : AppColors.paid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        if (!empty) ...[
          FilledButton.icon(
            key: const Key('attPreview'),
            onPressed: _busy ? null : () => _preview(_selected),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('معاينة المرفق'),
          ),
          FilledButton.icon(
            key: const Key('attDownload'),
            onPressed: _busy ? null : () => _download(_selected),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: const Text('تحميل المرفق'),
          ),
        ],
        TextButton.icon(
          key: const Key('attCancel'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('إلغاء'),
        ),
      ],
    );
  }
}

