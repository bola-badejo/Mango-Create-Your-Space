// Creator Studio: becoming a contributor, setting up, and running your
// content from one dashboard.
//
//   Not registered: a 3-step setup (what you'll share, your profile, review),
//   created on the server so nobody can mark themselves verified.
//   Registered: profile, totals, MangoCoin earned, quick uploads, and every
//   item you've shared with Edit and Delete.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Media/compose/mango_uploader.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

import 'content_editor.dart';
import 'content_schema.dart';

const _roleInfo = {
  'creator': ('Creator', 'Share songs, podcasts, films, books and vines. Fans earn you MangoCoin when they listen, watch and read.', Icons.brush_rounded),
  'distributor': ('Distributor', 'Release music, films and books on behalf of artists and labels.', Icons.local_shipping_rounded),
  'vendor': ('Vendor', 'Sell products from your own storefront.', Icons.storefront_rounded),
};

String _roleKey(String title) => title.toLowerCase().contains('vendor')
    ? 'vendor'
    : title.toLowerCase().contains('distrib')
        ? 'distributor'
        : 'creator';

/// Opens the studio for a role ("Creator", "Distributor", "Vendor").
class StudioEntry extends StatelessWidget {
  const StudioEntry({super.key, required this.roleTitle});

  final String roleTitle;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final role = _roleKey(roleTitle);
    if (uid == null) return const Scaffold(body: MangoStateView(kind: MangoStateKind.permissionDenied, title: 'Sign in first', message: 'Sign in to open your studio.'));
    final idField = {'creator': 'creatorID', 'distributor': 'distributorID', 'vendor': 'vendorID'}[role]!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: MangoLoadingRegion(label: 'Opening studio', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))));
        final contributorId = '${snap.data!.data()?[idField] ?? ''}';
        return MangoStateSwitcher(
          child: contributorId.isEmpty
              ? StudioOnboarding(key: const ValueKey('onboard'), role: role)
              : StudioDashboard(key: ValueKey(contributorId), role: role, contributorId: contributorId),
        );
      },
    );
  }
}

// ---------------------------------------------------------- onboarding
class StudioOnboarding extends StatefulWidget {
  const StudioOnboarding({super.key, required this.role});

  final String role;

  @override
  State<StudioOnboarding> createState() => _StudioOnboardingState();
}

class _StudioOnboardingState extends State<StudioOnboarding> {
  int _step = 0;
  final _name = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  final _bio = TextEditingController();
  final Set<String> _categories = {};
  ComposedMedia? _avatar;
  ComposedMedia? _banner;
  String? _error;
  double? _progress;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  List<String> get _categoryOptions => switch (widget.role) {
        'vendor' => const ['Fashion', 'Beauty', 'Art', 'Books', 'Electronics', 'Home', 'Food', 'Services'],
        'distributor' => const ['Music', 'Film', 'Books', 'Label', 'Publisher'],
        _ => const ['Music', 'Podcasts', 'Film', 'Writing', 'Photography', 'Comedy', 'Education', 'Art'],
      };

  Future<void> _create() async {
    setState(() => _error = null);
    String? avatarUrl;
    String? bannerUrl;
    if (_avatar != null) {
      avatarUrl = (await MangoUploader.uploadWithRetry(bytes: _avatar!.bytes, contentType: _avatar!.mime, path: MangoUploader.userPath('contributor', 'jpg'), onProgress: (p) => setState(() => _progress = p / 2))).url;
    }
    if (_banner != null) {
      bannerUrl = (await MangoUploader.uploadWithRetry(bytes: _banner!.bytes, contentType: _banner!.mime, path: MangoUploader.userPath('contributor', 'jpg'), onProgress: (p) => setState(() => _progress = 0.5 + p / 2))).url;
    }
    await MangoLedgerClient.instance.call('contributorRegister', {
      'role': widget.role,
      'name': _name.text.trim(),
      'bio': _bio.text.trim(),
      'categories': _categories.toList(),
      if (avatarUrl != null) 'profileImageUrl': avatarUrl,
      if (bannerUrl != null) 'bannerImageUrl': bannerUrl,
    });
    if (mounted) MangoAnnounce.polite(context, 'Your studio is ready');
  }

  @override
  Widget build(BuildContext context) {
    final (title, blurb, icon) = _roleInfo[widget.role]!;
    final c = context.colors;
    final steps = ['What you\'ll share', 'Your profile', 'Review'];
    return Scaffold(
      appBar: AppBar(title: Text('Become a $title')),
      body: MangoContentWidth(
        maxWidth: 640,
        child: ListView(padding: const EdgeInsets.symmetric(vertical: MangoSpace.s4), children: [
          Text('Step ${_step + 1} of 3 · ${steps[_step]}', style: context.type.labelLarge?.copyWith(color: c.textSecondary)),
          const SizedBox(height: MangoSpace.s2),
          LinearProgressIndicator(value: (_step + 1) / 3, semanticsLabel: 'Progress'),
          const SizedBox(height: MangoSpace.s6),
          MangoStateSwitcher(child: KeyedSubtree(key: ValueKey(_step), child: switch (_step) {
            0 => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 48, color: c.textBrand),
                const SizedBox(height: MangoSpace.s3),
                Text('As a $title on Mango', style: context.type.headlineSmall),
                const SizedBox(height: MangoSpace.s2),
                Text(blurb, style: context.type.bodyLarge),
                const SizedBox(height: MangoSpace.s4),
                for (final type in roleContent[widget.role]!)
                  ListTile(contentPadding: EdgeInsets.zero, leading: Icon(_iconFor(type), color: c.textBrand), title: Text(contentTypes[type]!.label), subtitle: const Text('Upload, edit and delete anytime')),
              ]),
            1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  MangoPressable(
                    semanticLabel: _avatar == null ? 'Add profile photo' : 'Change profile photo',
                    onTap: () async {
                      final m = await MangoComposer.pick(context, crop: CropShape.square, allowCaption: false, actionLabel: 'Use');
                      if (m != null) setState(() => _avatar = m);
                    },
                    child: CircleAvatar(radius: 40, backgroundColor: c.surfaceSelected, backgroundImage: _avatar == null ? null : MemoryImage(_avatar!.bytes), child: _avatar == null ? Icon(Icons.add_a_photo_rounded, color: c.textBrand) : null),
                  ),
                  const SizedBox(width: MangoSpace.s4),
                  Expanded(
                    child: MangoButton(
                      label: _banner == null ? 'Add a banner' : 'Change banner',
                      icon: Icons.panorama_rounded,
                      variant: MangoButtonVariant.secondary,
                      size: MangoButtonSize.medium,
                      onPressed: () async {
                        final m = await MangoComposer.pick(context, crop: CropShape.landscape, allowCaption: false, actionLabel: 'Use');
                        if (m != null) setState(() => _banner = m);
                      },
                    ),
                  ),
                ]),
                if (_banner != null) Padding(padding: const EdgeInsets.only(top: MangoSpace.s3), child: ClipRRect(borderRadius: BorderRadius.circular(MangoRadius.md), child: AspectRatio(aspectRatio: 16 / 9, child: Image.memory(_banner!.bytes, fit: BoxFit.cover)))),
                const SizedBox(height: MangoSpace.s4),
                MangoTextField(label: widget.role == 'vendor' ? 'Store name' : (widget.role == 'distributor' ? 'Label or company' : 'Stage name'), controller: _name, required: true, onChanged: (_) => setState(() {})),
                const SizedBox(height: MangoSpace.s3),
                MangoTextField(label: 'Bio', controller: _bio, maxLines: 4, helperText: 'Tell fans what you make'),
                const SizedBox(height: MangoSpace.s3),
                Text('Categories', style: context.type.titleSmall),
                const SizedBox(height: MangoSpace.s2),
                Wrap(spacing: MangoSpace.s2, runSpacing: MangoSpace.s2, children: [
                  for (final cat in _categoryOptions)
                    FilterChip(label: Text(cat), selected: _categories.contains(cat), onSelected: (v) => setState(() => v ? _categories.add(cat) : _categories.remove(cat))),
                ]),
              ]),
            _ => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 28, backgroundImage: _avatar == null ? null : MemoryImage(_avatar!.bytes), child: _avatar == null ? const Icon(Icons.person_rounded) : null),
                  title: Text(_name.text.trim(), style: context.type.titleLarge),
                  subtitle: Text(title),
                ),
                if (_bio.text.trim().isNotEmpty) Text(_bio.text.trim()),
                if (_categories.isNotEmpty) Padding(padding: const EdgeInsets.only(top: MangoSpace.s2), child: Text(_categories.join(' · '), style: context.type.bodySmall)),
                const SizedBox(height: MangoSpace.s4),
                Text('Your studio is created on Mango\'s servers. You can edit your profile anytime.', style: context.type.bodySmall?.copyWith(color: c.textSecondary)),
                if (_progress != null && _progress! < 1) Padding(padding: const EdgeInsets.only(top: MangoSpace.s3), child: LinearProgressIndicator(value: _progress, semanticsLabel: 'Uploading photos')),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: MangoSpace.s3), child: Text(_error!, style: TextStyle(color: c.error))),
              ]),
          })),
          const SizedBox(height: MangoSpace.s6),
          Row(children: [
            if (_step > 0) Expanded(child: MangoButton(label: 'Back', variant: MangoButtonVariant.tertiary, onPressed: () => setState(() => _step -= 1))),
            if (_step > 0) const SizedBox(width: MangoSpace.s3),
            Expanded(
              child: _step < 2
                  ? MangoButton(label: 'Continue', onPressed: _step == 1 && _name.text.trim().length < 2 ? null : () => setState(() => _step += 1))
                  : MangoButton(label: 'Create my studio', icon: Icons.rocket_launch_rounded, showSuccess: true, successLabel: 'Studio ready', onPressed: _create, onError: (e) => setState(() => _error = e.toString())),
            ),
          ]),
        ]),
      ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      'song' => Icons.music_note_rounded,
      'podcast' => Icons.podcasts_rounded,
      'movie' => Icons.movie_rounded,
      'book' => Icons.menu_book_rounded,
      'product' => Icons.shopping_bag_rounded,
      _ => Icons.videocam_rounded,
    };

// ----------------------------------------------------------- dashboard
class StudioDashboard extends StatelessWidget {
  const StudioDashboard({super.key, required this.role, required this.contributorId});

  final String role;
  final String contributorId;

  @override
  Widget build(BuildContext context) {
    final types = roleContent[role]!;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: types.length,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'studio-upload',
          onPressed: () => _chooseUpload(context, types),
          icon: const Icon(Icons.cloud_upload_rounded),
          label: const Text('Upload'),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              title: Text('${_roleInfo[role]!.$1} Studio'),
              actions: [MangoIconButton(icon: Icons.edit_rounded, semanticLabel: 'Edit profile', onPressed: () => _editProfile(context))],
              flexibleSpace: FlexibleSpaceBar(background: _Header(contributorId: contributorId, uid: uid, types: types)),
              bottom: TabBar(isScrollable: types.length > 3, tabs: [for (final t in types) Tab(text: '${contentTypes[t]!.label}s')]),
            ),
          ],
          body: TabBarView(children: [for (final t in types) _ContentList(type: contentTypes[t]!, uid: uid)]),
        ),
      ),
    );
  }

  void _chooseUpload(BuildContext context, List<String> types) {
    if (types.length == 1) {
      Get.to(() => ContentEditorScreen(type: contentTypes[types.first]!));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('What are you sharing?', style: context.type.titleLarge)),
          for (final t in types)
            ListTile(
              leading: Icon(_iconFor(t)),
              title: Text(contentTypes[t]!.label),
              onTap: () {
                Navigator.pop(sheet);
                Get.to(() => ContentEditorScreen(type: contentTypes[t]!));
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final ref = FirebaseFirestore.instance.collection('contributors').doc(contributorId);
    final d = (await ref.get()).data() ?? const <String, dynamic>{};
    if (!context.mounted) return;
    final bio = TextEditingController(text: '${d['bio'] ?? ''}');
    String? avatar = d['profileImageUrl'] as String?;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(MangoSpace.s4, MangoSpace.s4, MangoSpace.s4, MediaQuery.viewInsetsOf(sheet).bottom + MangoSpace.s4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            MangoPressable(
              semanticLabel: 'Change profile photo',
              onTap: () async {
                final m = await MangoComposer.pick(sheet, crop: CropShape.square, allowCaption: false, actionLabel: 'Use');
                if (m == null) return;
                final up = await MangoUploader.uploadWithRetry(bytes: m.bytes, contentType: m.mime, path: MangoUploader.userPath('contributor', 'jpg'));
                setLocal(() => avatar = up.url);
              },
              child: CircleAvatar(radius: 40, backgroundImage: (avatar ?? '').isEmpty ? null : CachedNetworkImageProvider(avatar!), child: (avatar ?? '').isEmpty ? const Icon(Icons.add_a_photo_rounded) : null),
            ),
            const SizedBox(height: MangoSpace.s3),
            MangoTextField(label: 'Bio', controller: bio, maxLines: 4),
            const SizedBox(height: MangoSpace.s3),
            MangoButton(label: 'Save', expand: true, onPressed: () async {
              await ref.update({'bio': bio.text.trim(), if (avatar != null) 'profileImageUrl': avatar, 'updatedAt': DateTime.now().millisecondsSinceEpoch});
              if (sheet.mounted) Navigator.pop(sheet);
            }),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.contributorId, required this.uid, required this.types});

  final String contributorId;
  final String uid;
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('contributors').doc(contributorId).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? const <String, dynamic>{};
        final name = '${d['stageName'] ?? d['storeName'] ?? d['distributorLabel'] ?? d['fullName'] ?? ''}';
        final banner = '${d['bannerImageUrl'] ?? ''}';
        final avatar = '${d['profileImageUrl'] ?? ''}';
        return Stack(fit: StackFit.expand, children: [
          if (banner.isNotEmpty) CachedNetworkImage(imageUrl: banner, fit: BoxFit.cover) else ColoredBox(color: c.surfaceSelected),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, c.bgPrimary.withValues(alpha: 0.95)]))),
          Positioned(
            left: MangoSpace.s4,
            right: MangoSpace.s4,
            bottom: 56,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              CircleAvatar(radius: 32, backgroundImage: avatar.isEmpty ? null : CachedNetworkImageProvider(avatar), child: avatar.isEmpty ? const Icon(Icons.person_rounded) : null),
              const SizedBox(width: MangoSpace.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.titleLarge)),
                    if (d['isVerified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 18, color: c.textBrand)),
                  ]),
                  _Stats(uid: uid, types: types),
                ]),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.uid, required this.types});

  final String uid;
  final List<String> types;

  Future<(int, int, String)> _load() async {
    var items = 0;
    var reach = 0;
    for (final t in types) {
      final ct = contentTypes[t]!;
      final q = await FirebaseFirestore.instance.collection(ct.collection).where(ct.queryField, isEqualTo: uid).limit(200).get();
      items += q.size;
      for (final d in q.docs) {
        final v = d.data()[ct.statKey];
        if (v is num) reach += v.toInt();
      }
    }
    final acct = (await FirebaseFirestore.instance.collection('ledger_accounts').doc(uid).get()).data();
    final bal = Decimal.fromBigInt(BigInt.tryParse('${acct?['balance'] ?? '0'}') ?? BigInt.zero).toFixed(2);
    return (items, reach, bal);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(int, int, String)>(
      future: _load(),
      builder: (context, s) {
        final (items, reach, bal) = s.data ?? (0, 0, '—');
        return Text('$items items · $reach plays and views · $bal MNG earned', style: context.type.bodySmall?.copyWith(color: context.colors.textSecondary));
      },
    );
  }
}

class _ContentList extends StatelessWidget {
  const _ContentList({required this.type, required this.uid});

  final ContentType type;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(type.collection).where(type.queryField, isEqualTo: uid).limit(200).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return MangoLoadingRegion(label: 'Loading', child: ListView(children: List.generate(4, (_) => const ListTile(leading: MangoSkeleton(width: 56, height: 56), title: MangoSkeleton(width: 160, height: 14)))));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return MangoStateView(kind: MangoStateKind.empty, title: 'No ${type.label.toLowerCase()}s yet', message: 'Share your first one. You can edit or delete it anytime.', actionLabel: 'Upload', onAction: () => Get.to(() => ContentEditorScreen(type: type)));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final title = '${d[type.titleKey] ?? d['name'] ?? 'Untitled'}';
            final image = '${d[type.imageKey] ?? ((d['imageUrls'] is List && (d['imageUrls'] as List).isNotEmpty) ? (d['imageUrls'] as List).first : '')}';
            final stat = d[type.statKey];
            return MangoAppear.staggered(
              index: i,
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  child: SizedBox(width: 56, height: 56, child: image.isEmpty ? ColoredBox(color: context.colors.surfaceSelected, child: Icon(_iconFor(type.id))) : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, memCacheWidth: 168)),
                ),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${stat is num ? stat.toInt() : 0} ${type.statLabel}'),
                onTap: () => Get.to(() => ContentEditorScreen(type: type, docId: docs[i].id)),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Options for $title',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      Get.to(() => ContentEditorScreen(type: type, docId: docs[i].id));
                    } else if (v == 'delete') {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (dlg) => AlertDialog(
                          title: Text('Delete "$title"?'),
                          content: const Text('It and its files will be removed. This can\'t be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dlg, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(dlg, true), child: Text('Delete', style: TextStyle(color: context.colors.error))),
                          ],
                        ),
                      );
                      if (yes == true) {
                        try {
                          await docs[i].reference.delete();
                          if (context.mounted) MangoToast.show(context, message: 'Deleted', kind: MangoToastKind.success);
                        } catch (_) {
                          if (context.mounted) MangoToast.show(context, message: "Couldn't delete. Try again.", kind: MangoToastKind.error);
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Delete'))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
