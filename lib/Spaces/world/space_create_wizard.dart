// Guided Space creation: five short steps, each with a guide explaining
// what to do and why. The Space is created on the server, which reserves
// the @handle, sets the owner and lays out a starter world.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/buttons/mango_button.dart';
import 'package:mango/Core/design_system/inputs/mango_text_field.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

import 'space_catalog.dart';
import 'space_world_screen.dart';
import 'space_world_service.dart';

class _Template {
  const _Template(this.id, this.emoji, this.title, this.blurb);
  final String id;
  final String emoji;
  final String title;
  final String blurb;
}

const _templates = [
  _Template('creator', '🎬', 'Creator studio', 'Showcase music, videos and podcasts, and host live sessions.'),
  _Template('music', '🎧', 'Music room', 'A listening room for your tracks. Fans earn while they listen.'),
  _Template('books', '📚', 'Book club', 'Share reading, discuss chapters and meet other readers.'),
  _Template('shop', '🛍️', 'Shop', 'Show products in a space people can walk around.'),
  _Template('community', '🤝', 'Community', 'A home for a group: talk, plan events and meet up live.'),
];

class _Step {
  const _Step(this.title, this.guideTitle, this.guide);
  final String title;
  final String guideTitle;
  final String guide;
}

const _steps = [
  _Step('What is it for?', 'Start with a purpose',
      'Pick the closest fit. It sets up your rooms and a starter layout. You can change everything later.'),
  _Step('Name it', 'Make it findable',
      'Your name is what people see. Your @handle is your link: short, memorable, and only yours.'),
  _Step('Pick a look', 'Set the mood',
      'Choose a starter skin and icon. You can buy more skins, icons and objects in the shop once your Space exists.'),
  _Step('Who can enter?', 'Choose your door',
      'Public Spaces are open to everyone. Members Spaces are for people who join. Private Spaces are invitation only.'),
  _Step('Review', 'Ready to open the doors',
      "Check the details, then create. We'll take you inside and show you how to add content and host a live event."),
];

class SpaceCreateWizard extends StatefulWidget {
  const SpaceCreateWizard({super.key});

  @override
  State<SpaceCreateWizard> createState() => _SpaceCreateWizardState();
}

class _SpaceCreateWizardState extends State<SpaceCreateWizard> {
  int _step = 0;
  String? _template;
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _description = TextEditingController();
  String? _handleStatus; // null = unchecked
  bool _handleOk = false;
  bool _checking = false;
  Timer? _debounce;
  String _skinId = 'skin.meadow';
  String _iconId = 'icon.mango';
  String _visibility = 'public';
  SpaceCatalog? _catalog;
  String? _error;

  @override
  void initState() {
    super.initState();
    SpaceCatalog.load().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
    _name.addListener(_suggestHandle);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _handle.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _handleEdited = false;

  void _suggestHandle() {
    if (_handleEdited) return;
    final suggestion = _name.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    _handle.text = suggestion.length > 30 ? suggestion.substring(0, 30) : suggestion;
    _scheduleCheck();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    setState(() {
      _handleOk = false;
      _handleStatus = null;
    });
    if (_handle.text.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 450), _checkHandle);
  }

  Future<void> _checkHandle() async {
    final text = _handle.text.trim();
    setState(() => _checking = true);
    try {
      final r = await SpaceWorldService.checkHandle(text);
      if (!mounted || _handle.text.trim() != text) return;
      setState(() {
        _handleOk = r['available'] == true;
        _handleStatus = _handleOk ? '@${r['handle']} is available' : (r['reason'] ?? 'Not available') as String;
      });
    } catch (e) {
      if (mounted) setState(() => _handleStatus = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _template != null;
      case 1:
        return _name.text.trim().length >= 3 && _handleOk;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canContinue) return;
    if (_step == 0 && _template != null) {
      // Templates suggest a starting look.
      _skinId = _template == 'music' || _template == 'community' ? 'skin.midnight' : 'skin.meadow';
    }
    setState(() {
      _error = null;
      _step = _step + 1 >= _steps.length ? _steps.length - 1 : _step + 1;
    });
  }

  void _back() {
    if (_step == 0) {
      Get.back();
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _create() async {
    setState(() => _error = null);
    final result = await SpaceWorldService.create({
      'template': _template,
      'title': _name.text.trim(),
      'handle': _handle.text.trim(),
      'description': _description.text.trim(),
      'visibility': _visibility,
      'skinId': _skinId,
      'iconId': _iconId,
    });
    final spaceId = result['spaceId'] as String;
    if (!mounted) return;
    MangoAnnounce.polite(context, 'Space created');
    Get.off(() => SpaceWorldScreen(spaceId: spaceId, showTour: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _steps[_step];
    return Scaffold(
      appBar: AppBar(
        leading: MangoIconButton(
          icon: _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
          semanticLabel: _step == 0 ? 'Close' : 'Back',
          onPressed: _back,
        ),
        title: Text('Create a Space', style: context.type.titleLarge),
      ),
      body: SafeArea(
        child: MangoContentWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: MangoSpace.s2),
              Semantics(
                label: 'Step ${_step + 1} of ${_steps.length}: ${step.title}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Step ${_step + 1} of ${_steps.length}',
                          style: context.type.labelLarge?.copyWith(color: c.textSecondary)),
                      const SizedBox(height: MangoSpace.s2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MangoRadius.xs),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: (_step + 1) / _steps.length),
                          duration: MangoMotion.duration(context, MangoMotionTokens.base),
                          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, semanticsLabel: 'Progress'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MangoSpace.s4),
              Text(step.title, style: context.type.headlineMedium),
              const SizedBox(height: MangoSpace.s3),
              _GuideCard(title: step.guideTitle, body: step.guide),
              const SizedBox(height: MangoSpace.s4),
              Expanded(
                child: MangoStateSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: SingleChildScrollView(child: _stepBody(context)),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: MangoSpace.s2),
                  child: Text(_error!, style: context.type.bodyMedium?.copyWith(color: c.error)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MangoSpace.s4),
                child: _step < _steps.length - 1
                    ? MangoButton(label: 'Continue', expand: true, onPressed: _canContinue ? _next : null)
                    : MangoButton(
                        label: 'Create Space',
                        icon: Icons.auto_awesome_rounded,
                        expand: true,
                        showSuccess: true,
                        successLabel: 'Space created',
                        onPressed: _create,
                        onError: (e) => setState(() => _error = e.toString()),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          children: [
            for (final t in _templates)
              Padding(
                padding: const EdgeInsets.only(bottom: MangoSpace.s3),
                child: _ChoiceTile(
                  selected: _template == t.id,
                  leading: Text(t.emoji, style: const TextStyle(fontSize: 28)),
                  title: t.title,
                  subtitle: t.blurb,
                  onTap: () => setState(() => _template = t.id),
                ),
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MangoTextField(label: 'Name', controller: _name, required: true, helperText: '3 to 60 characters', onChanged: (_) => setState(() {})),
            const SizedBox(height: MangoSpace.s4),
            MangoTextField(
              label: 'Handle',
              controller: _handle,
              required: true,
              hintText: 'your_space',
              helperText: _checking ? 'Checking…' : (_handleStatus ?? 'Letters, numbers and underscores'),
              errorText: (!_checking && _handleStatus != null && !_handleOk) ? _handleStatus : null,
              onChanged: (_) {
                _handleEdited = true;
                _scheduleCheck();
              },
            ),
            const SizedBox(height: MangoSpace.s4),
            MangoTextField(label: 'Description', controller: _description, maxLines: 3, helperText: 'Optional. What will people find here?'),
          ],
        );
      case 2:
        final cat = _catalog;
        if (cat == null) return const MangoLoadingRegion(label: 'Loading looks', child: MangoSkeleton(height: 160));
        final skins = cat.ofKind(SpaceItemKind.skin).where((i) => i.isFree).toList();
        final icons = cat.ofKind(SpaceItemKind.icon).where((i) => i.isFree).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.md),
              child: SizedBox(
                height: 160,
                child: SpaceSkinBackground(
                  skin: cat[_skinId],
                  child: Center(child: SpaceGlyph(item: cat[_iconId], size: 56, label: 'Preview of your Space')),
                ),
              ),
            ),
            const SizedBox(height: MangoSpace.s4),
            Text('Skin', style: context.type.titleMedium),
            const SizedBox(height: MangoSpace.s2),
            Wrap(spacing: MangoSpace.s3, runSpacing: MangoSpace.s3, children: [
              for (final s in skins)
                _SwatchChoice(
                  selected: _skinId == s.id,
                  label: s.name,
                  onTap: () => setState(() => _skinId = s.id),
                  child: SpaceSkinBackground(skin: s),
                ),
            ]),
            const SizedBox(height: MangoSpace.s4),
            Text('Icon', style: context.type.titleMedium),
            const SizedBox(height: MangoSpace.s2),
            Wrap(spacing: MangoSpace.s3, runSpacing: MangoSpace.s3, children: [
              for (final i in icons)
                _SwatchChoice(
                  selected: _iconId == i.id,
                  label: i.name,
                  onTap: () => setState(() => _iconId = i.id),
                  child: Center(child: SpaceGlyph(item: i, size: 28)),
                ),
            ]),
            const SizedBox(height: MangoSpace.s3),
            Text('More skins, icons and objects are in the shop inside your Space.',
                style: context.type.bodySmall?.copyWith(color: context.colors.textSecondary)),
          ],
        );
      case 3:
        const options = [
          ('public', Icons.public_rounded, 'Public', 'Anyone can enter, look around and leave a message.'),
          ('members', Icons.group_rounded, 'Members', 'Anyone can join; only members see inside.'),
          ('private', Icons.lock_rounded, 'Private', 'Only people you add can enter.'),
        ];
        return Column(children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: MangoSpace.s3),
              child: _ChoiceTile(
                selected: _visibility == o.$1,
                leading: Icon(o.$2, size: 28),
                title: o.$3,
                subtitle: o.$4,
                onTap: () => setState(() => _visibility = o.$1),
              ),
            ),
        ]);
      default:
        final t = _templates.firstWhere((t) => t.id == _template, orElse: () => _templates.first);
        final rows = [
          ('Purpose', t.title, 0),
          ('Name', _name.text.trim(), 1),
          ('Handle', '@${_handle.text.trim()}', 1),
          ('Look', '${_catalog?[_skinId]?.name ?? _skinId} · ${_catalog?[_iconId]?.name ?? _iconId}', 2),
          ('Who can enter', _visibility[0].toUpperCase() + _visibility.substring(1), 3),
        ];
        return Column(children: [
          for (final r in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.$1, style: context.type.labelLarge?.copyWith(color: context.colors.textSecondary)),
              subtitle: Text(r.$2, style: context.type.bodyLarge),
              trailing: TextButton(onPressed: () => setState(() => _step = r.$3), child: const Text('Edit')),
            ),
        ]);
    }
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(MangoSpace.s4),
      decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(MangoRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(Icons.lightbulb_outline_rounded, color: c.textBrand)),
          const SizedBox(width: MangoSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.titleSmall?.copyWith(color: c.textBrand, fontWeight: FontWeight.w600)),
                const SizedBox(height: MangoSpace.s1),
                Text(body, style: context.type.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.leading, required this.title, required this.subtitle, required this.onTap});

  final bool selected;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: MangoPressable(
        onTap: onTap,
        semanticLabel: '$title. $subtitle',
        child: AnimatedContainer(
          duration: MangoMotion.duration(context, MangoMotionTokens.fast),
          padding: const EdgeInsets.all(MangoSpace.s4),
          decoration: BoxDecoration(
            color: selected ? c.surfaceSelected : c.surfaceElevated,
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(color: selected ? c.actionPrimary : c.borderSubtle, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            ExcludeSemantics(child: leading),
            const SizedBox(width: MangoSpace.s4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.type.titleMedium),
                const SizedBox(height: MangoSpace.s1),
                Text(subtitle, style: context.type.bodyMedium?.copyWith(color: c.textSecondary)),
              ]),
            ),
            if (selected) ExcludeSemantics(child: Icon(Icons.check_circle_rounded, color: c.actionPrimary)),
          ]),
        ),
      ),
    );
  }
}

class _SwatchChoice extends StatelessWidget {
  const _SwatchChoice({required this.selected, required this.label, required this.onTap, required this.child});

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      child: MangoPressable(
        onTap: onTap,
        semanticLabel: label,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: MangoMotion.duration(context, MangoMotionTokens.fast),
            width: 72,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              border: Border.all(color: selected ? c.actionPrimary : c.borderSubtle, width: selected ? 3 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          const SizedBox(height: MangoSpace.s1),
          ExcludeSemantics(child: Text(label, style: context.type.bodySmall)),
        ]),
      ),
    );
  }
}
