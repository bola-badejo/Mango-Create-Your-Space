// The one-minute quick start: photo (optional), name, @username (suggested
// and checked live), interests (optional). Everything else (bio, banner,
// birthday, location) can be added later from the profile.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Models/cloud/user_services.dart';
import 'package:mango/Onboarding/mango_explainer.dart';

import 'onboarding_service.dart';

const _interests = ['Music', 'Afrobeats', 'Podcasts', 'Books', 'Films', 'Comedy', 'Fashion', 'Art', 'Tech', 'Sports', 'Faith', 'Food', 'Gaming', 'Business'];

class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  final _svc = OnboardingService.instance;
  final _name = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  final _username = TextEditingController();
  final Set<String> _picked = {};
  ComposedMedia? _photo;
  Timer? _debounce;
  bool _checking = false;
  bool _usernameOk = false;
  String? _usernameMsg;
  bool _usernameEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    if (_usernameEdited) return;
    final name = _name.text.trim();
    final s = await _svc.suggestUsername(name.isEmpty ? (FirebaseAuth.instance.currentUser?.email ?? 'mango') : name);
    if (!mounted || _usernameEdited) return;
    _username.text = s;
    _check();
  }

  void _onUsername(String _) {
    _usernameEdited = true;
    _debounce?.cancel();
    setState(() {
      _usernameOk = false;
      _usernameMsg = null;
    });
    _debounce = Timer(const Duration(milliseconds: 400), _check);
  }

  Future<void> _check() async {
    final u = _username.text.trim();
    if (u.length < 3) {
      setState(() => _usernameMsg = 'At least 3 characters');
      return;
    }
    setState(() => _checking = true);
    try {
      final r = await _svc.checkUsername(u);
      if (!mounted || _username.text.trim() != u) return;
      setState(() {
        _usernameOk = r['available'] == true;
        _usernameMsg = _usernameOk ? '@${r['username']} is yours' : '${r['reason'] ?? 'Not available'}';
      });
    } catch (_) {
      if (mounted) setState(() => _usernameMsg = "Couldn't check right now");
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  bool get _ready => _name.text.trim().length >= 2 && _usernameOk && !_checking;

  Future<void> _go() async {
    setState(() => _error = null);
    String? photoUrl;
    if (_photo != null) {
      photoUrl = await UserService().updateProfileImage(_photo!.bytes);
    }
    await _svc.onboard(displayName: _name.text.trim(), username: _username.text.trim(), interests: _picked.toList(), photoUrl: photoUrl);
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(_name.text.trim());
    } catch (_) {}
    if (!mounted) return;
    Get.offAll(() => const MangoExplainer());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: MangoContentWidth(
          maxWidth: 560,
          child: ListView(padding: const EdgeInsets.symmetric(vertical: MangoSpace.s6), children: [
            Text('Let\'s set you up', style: context.type.headlineMedium),
            const SizedBox(height: MangoSpace.s1),
            Text('This takes about a minute. You can add more later in your profile.', style: context.type.bodyMedium?.copyWith(color: c.textSecondary)),
            const SizedBox(height: MangoSpace.s6),
            Center(
              child: MangoPressable(
                semanticLabel: _photo == null ? 'Add a profile photo (optional)' : 'Change profile photo',
                onTap: () async {
                  final m = await MangoComposer.pick(context, crop: CropShape.square, allowCaption: false, actionLabel: 'Use');
                  if (m != null) setState(() => _photo = m);
                },
                child: Stack(children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: c.surfaceSelected,
                    backgroundImage: _photo == null ? null : MemoryImage(_photo!.bytes),
                    child: _photo == null ? Icon(Icons.add_a_photo_rounded, color: c.textBrand, size: 30) : null,
                  ),
                  if (_photo != null)
                    Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 14, backgroundColor: c.actionPrimary, child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white))),
                ]),
              ),
            ),
            const SizedBox(height: MangoSpace.s1),
            Center(child: Text('Photo (optional)', style: context.type.bodySmall?.copyWith(color: c.textSecondary))),
            const SizedBox(height: MangoSpace.s6),
            MangoTextField(
              label: 'Your name',
              controller: _name,
              required: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {});
                if (!_usernameEdited) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), _suggest);
                }
              },
            ),
            const SizedBox(height: MangoSpace.s4),
            MangoTextField(
              label: 'Username',
              controller: _username,
              required: true,
              hintText: 'yourname',
              helperText: _checking ? 'Checking…' : (_usernameOk ? _usernameMsg : null),
              errorText: !_checking && !_usernameOk ? _usernameMsg : null,
              onChanged: _onUsername,
            ),
            const SizedBox(height: MangoSpace.s6),
            Text('What are you into? (optional)', style: context.type.titleSmall),
            const SizedBox(height: MangoSpace.s2),
            Wrap(spacing: MangoSpace.s2, runSpacing: MangoSpace.s2, children: [
              for (final i in _interests)
                FilterChip(label: Text(i), selected: _picked.contains(i), onSelected: (v) => setState(() => v ? _picked.add(i) : _picked.remove(i))),
            ]),
            if (_error != null) ...[
              const SizedBox(height: MangoSpace.s4),
              Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: c.error))),
            ],
            const SizedBox(height: MangoSpace.s8),
            MangoButton(
              label: "Let's go",
              icon: Icons.arrow_forward_rounded,
              expand: true,
              onPressed: _ready ? _go : null,
              onError: (e) => setState(() => _error = e.toString()),
            ),
            const SizedBox(height: MangoSpace.s2),
            Center(
              child: TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Get.offAllNamed('/welcome');
                },
                child: const Text('Use a different account'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
