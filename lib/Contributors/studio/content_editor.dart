// One editor for every kind of creator content: upload something new, or
// edit and replace files on something you already shared. Photos go through
// the Mango composer (crop, filters, adjustments); every file shows its own
// progress; replaced files are removed from Storage after saving.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Media/compose/mango_uploader.dart';

import 'content_schema.dart';

class ContentEditorScreen extends StatefulWidget {
  const ContentEditorScreen({super.key, required this.type, this.docId});

  final ContentType type;

  /// Null to create; an id to edit.
  final String? docId;

  @override
  State<ContentEditorScreen> createState() => _ContentEditorScreenState();
}

class _ContentEditorScreenState extends State<ContentEditorScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _values = {};
  final Map<String, ComposedMedia> _pending = {};
  final Map<String, double> _progress = {};
  Map<String, dynamic> _existing = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  ContentType get t => widget.type;
  bool get _editing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    for (final f in t.fields) {
      if (f.kind != FieldKind.toggle && f.kind != FieldKind.choice) _text[f.key] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    if (_editing) {
      final d = (await FirebaseFirestore.instance.collection(t.collection).doc(widget.docId).get()).data();
      if (d == null) {
        setState(() {
          _loading = false;
          _error = 'This item no longer exists.';
        });
        return;
      }
      _existing = d;
      for (final f in t.fields) {
        final v = d[f.key];
        if (_text.containsKey(f.key)) {
          _text[f.key]!.text = v == null ? '' : (v is List ? v.join(', ') : '$v');
        } else {
          _values[f.key] = v;
        }
      }
    } else {
      final name = FirebaseAuth.instance.currentUser?.displayName ?? '';
      if (_text['host'] != null) _text['host']!.text = name;
      if (_text['author'] != null) _text['author']!.text = name;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile(FileSpec f) async {
    final m = await MangoComposer.pick(context, allow: f.allow, crop: f.crop, allowCaption: false, actionLabel: 'Use');
    if (m == null) return;
    final ok = f.allow.contains(ComposeKind.image) && m.kind == MediaKind.image ||
        f.allow.contains(ComposeKind.video) && m.kind == MediaKind.video ||
        f.allow.contains(ComposeKind.audio) && m.kind == MediaKind.audio ||
        f.allow.contains(ComposeKind.document) && m.kind == MediaKind.document;
    if (!ok) {
      if (mounted) MangoToast.show(context, message: '${f.label} needs a different kind of file.', kind: MangoToastKind.error);
      return;
    }
    setState(() => _pending[f.key] = m);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      MangoToast.show(context, message: 'Check the highlighted fields.', kind: MangoToastKind.error);
      return;
    }
    for (final f in t.files) {
      if (f.required && _pending[f.key] == null && '${_existing[f.key] ?? ''}'.isEmpty) {
        MangoToast.show(context, message: 'Add the ${f.label.toLowerCase()} to continue.', kind: MangoToastKind.error);
        return;
      }
    }
    for (final f in t.fields) {
      if (f.kind == FieldKind.choice && f.required && (_values[f.key] == null || '${_values[f.key]}'.isEmpty)) {
        MangoToast.show(context, message: 'Choose a ${f.label.toLowerCase()}.', kind: MangoToastKind.error);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = FirebaseAuth.instance.currentUser!;
    final uploadedPaths = <String>[];
    final replaced = <String>[];
    try {
      final data = <String, dynamic>{};
      for (final f in t.fields) {
        switch (f.kind) {
          case FieldKind.number:
            final raw = _text[f.key]!.text.trim();
            if (raw.isNotEmpty) data[f.key] = f.key == 'releaseYear' ? raw : num.tryParse(raw) ?? 0;
          case FieldKind.tags:
            data[f.key] = _text[f.key]!.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(20).toList();
          case FieldKind.toggle:
            data[f.key] = _values[f.key] == true;
          case FieldKind.choice:
            data[f.key] = _values[f.key];
          default:
            data[f.key] = _text[f.key]!.text.trim();
        }
      }
      // Upload new files.
      for (final f in t.files) {
        final m = _pending[f.key];
        if (m == null) continue;
        final up = await MangoUploader.uploadWithRetry(
          bytes: m.bytes,
          contentType: m.mime,
          path: MangoUploader.contentPath(t.id, MangoUploader.extensionFor(m.mime, m.name)),
          onProgress: (p) => setState(() => _progress[f.key] = p),
        );
        uploadedPaths.add(up.path);
        data[f.key] = up.url;
        if (f.key == 'trackUrl' || f.key == 'audioUrl' || f.key == 'videoUrl' || f.key == 'fileUrl') data['fileSize'] = up.size;
        final old = '${_existing[f.key] ?? ''}';
        if (old.isNotEmpty) replaced.add(old);
      }
      if (t.id == 'product' && data['imageUrl'] != null) data['imageUrls'] = [data['imageUrl']];
      final paths = {...((_existing['storagePaths'] as List?) ?? const []).map((e) => '$e'), ...uploadedPaths};
      final col = FirebaseFirestore.instance.collection(t.collection);
      if (_editing) {
        await col.doc(widget.docId).update({...data, 'storagePaths': paths.toList(), 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        final owner = {for (final f in t.ownerFields) f: user.uid};
        if (t.nameField != null) owner[t.nameField!] = user.displayName ?? '';
        await col.add({
          ...t.defaults,
          ...data,
          ...owner,
          'storagePaths': paths.toList(),
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Remove replaced files we own.
      for (final url in replaced) {
        final p = _pathOf(url);
        if (p != null && (p.startsWith('content/${user.uid}/') || p.startsWith('users/${user.uid}/'))) await MangoUploader.delete(p);
      }
      if (!mounted) return;
      MangoAnnounce.polite(context, _editing ? 'Saved' : '${t.label} published');
      Navigator.pop(context, true);
    } catch (e) {
      // Don't leave orphaned uploads behind.
      for (final p in uploadedPaths) {
        await MangoUploader.delete(p);
      }
      if (mounted) setState(() => _error = e is UploadTooLarge ? e.message : "Couldn't save. ${e.toString().replaceFirst('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _pathOf(String url) {
    final m = RegExp(r'/o/([^?#]+)').firstMatch(url);
    return m == null ? null : Uri.decodeComponent(m.group(1)!);
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete this ${t.label.toLowerCase()}?'),
        content: const Text('It will be removed from Mango, along with its files. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Delete', style: TextStyle(color: context.colors.error))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await FirebaseFirestore.instance.collection(t.collection).doc(widget.docId).delete();
      if (!mounted) return;
      MangoAnnounce.polite(context, 'Deleted');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MangoToast.show(context, message: "Couldn't delete. Try again.", kind: MangoToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit ${t.label.toLowerCase()}' : 'New ${t.label.toLowerCase()}'),
        actions: [
          if (_editing) MangoIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Delete', onPressed: _saving ? null : _delete),
        ],
      ),
      body: _loading
          ? const MangoLoadingRegion(label: 'Loading', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')))
          : Form(
              key: _form,
              child: MangoContentWidth(
                maxWidth: 720,
                child: ListView(padding: const EdgeInsets.symmetric(vertical: MangoSpace.s4), children: [
                  for (final f in t.files) ...[_fileSlot(context, f), const SizedBox(height: MangoSpace.s3)],
                  const SizedBox(height: MangoSpace.s2),
                  for (final f in t.fields) ...[_field(context, f), const SizedBox(height: MangoSpace.s3)],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MangoSpace.s3),
                      child: Semantics(liveRegion: true, child: Text(_error!, style: context.type.bodyMedium?.copyWith(color: context.colors.error))),
                    ),
                  MangoButton(
                    label: _saving ? 'Saving…' : (_editing ? 'Save changes' : 'Publish'),
                    icon: _editing ? Icons.check_rounded : Icons.cloud_upload_rounded,
                    expand: true,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: MangoSpace.s8),
                ]),
              ),
            ),
    );
  }

  Widget _field(BuildContext context, FieldSpec f) {
    final label = f.required ? '${f.label} (required)' : f.label;
    switch (f.kind) {
      case FieldKind.toggle:
        return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), value: _values[f.key] == true, onChanged: (v) => setState(() => _values[f.key] = v));
      case FieldKind.choice:
        final current = f.choices.contains(_values[f.key]) ? _values[f.key] as String : null;
        return DropdownButtonFormField<String>(
          value: current,
          decoration: InputDecoration(labelText: label),
          items: f.choices.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _values[f.key] = v),
          validator: (v) => f.required && (v == null || v.isEmpty) ? 'Choose a ${f.label.toLowerCase()}' : null,
        );
      default:
        return TextFormField(
          controller: _text[f.key],
          maxLength: f.max > 200 ? null : f.max,
          minLines: f.kind == FieldKind.multiline ? 3 : 1,
          maxLines: f.kind == FieldKind.multiline ? 10 : 1,
          keyboardType: f.kind == FieldKind.number ? TextInputType.number : (f.kind == FieldKind.multiline ? TextInputType.multiline : TextInputType.text),
          decoration: InputDecoration(labelText: label, helperText: f.help),
          validator: (v) {
            final s = (v ?? '').trim();
            if (f.required && s.isEmpty) return 'Add the ${f.label.toLowerCase()}';
            if (s.length > f.max) return 'Keep it under ${f.max} characters';
            if (f.kind == FieldKind.number && s.isNotEmpty && num.tryParse(s) == null) return 'Use numbers only';
            return null;
          },
        );
    }
  }

  Widget _fileSlot(BuildContext context, FileSpec f) {
    final c = context.colors;
    final pending = _pending[f.key];
    final existing = '${_existing[f.key] ?? ''}';
    final has = pending != null || existing.isNotEmpty;
    final isImage = f.allow.contains(ComposeKind.image);
    final progress = _progress[f.key];
    Widget preview;
    if (isImage && pending != null) {
      preview = Image.memory(pending.bytes, fit: BoxFit.cover);
    } else if (isImage && existing.isNotEmpty) {
      preview = CachedNetworkImage(imageUrl: existing, fit: BoxFit.cover, memCacheWidth: 300);
    } else {
      preview = Icon(
        f.allow.contains(ComposeKind.audio) ? Icons.audio_file_rounded : f.allow.contains(ComposeKind.video) ? Icons.movie_rounded : Icons.picture_as_pdf_rounded,
        color: has ? c.textBrand : c.textTertiary,
        size: 36,
      );
    }
    return MangoPressable(
      semanticLabel: '${f.label}${f.required ? ', required' : ''}. ${has ? 'Replace' : 'Add'}',
      onTap: _saving ? null : () => _pickFile(f),
      child: Container(
        padding: const EdgeInsets.all(MangoSpace.s3),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(color: has ? c.actionPrimary : c.borderControl),
        ),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(MangoRadius.sm), child: SizedBox(width: 72, height: 72, child: ColoredBox(color: c.bgSecondary, child: Center(child: preview)))),
          const SizedBox(width: MangoSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.required ? '${f.label} *' : f.label, style: context.type.titleSmall),
              Text(
                pending != null ? '${pending.name} · ${(pending.size / (1024 * 1024)).toStringAsFixed(1)} MB' : (existing.isNotEmpty ? 'Current file. Tap to replace' : (f.help ?? 'Tap to add')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodySmall?.copyWith(color: c.textSecondary),
              ),
              if (progress != null && progress < 1) Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: progress, semanticsLabel: 'Uploading ${f.label}')),
            ]),
          ),
          Icon(has ? Icons.swap_horiz_rounded : Icons.add_circle_outline_rounded, color: c.textBrand),
        ]),
      ),
    );
  }
}
