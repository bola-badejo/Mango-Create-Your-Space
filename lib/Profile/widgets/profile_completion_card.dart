// "Finish your profile": shows what's missing and opens settings to add it.
// Matches the server's completeness check (functions/account/service.js);
// hidden once everything is done.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Profile/pages/settings.dart';

class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key});

  static const _steps = <(String, String, IconData)>[
    ('photo', 'Add a photo', Icons.add_a_photo_rounded),
    ('bio', 'Write a short bio', Icons.short_text_rounded),
    ('banner', 'Add a banner', Icons.panorama_rounded),
    ('location', 'Add your location', Icons.place_rounded),
    ('interests', 'Pick interests', Icons.interests_rounded),
  ];

  static bool _done(String key, Map<String, dynamic> u) => switch (key) {
        'photo' => '${u['profileImage'] ?? ''}'.isNotEmpty || '${u['profileImageUrl'] ?? ''}'.isNotEmpty,
        'bio' => '${u['bio'] ?? ''}'.trim().isNotEmpty,
        'banner' => '${u['bannerImage'] ?? ''}'.isNotEmpty || '${u['bannerImageUrl'] ?? ''}'.isNotEmpty,
        'location' => '${u['country'] ?? ''}'.isNotEmpty || '${u['city'] ?? ''}'.isNotEmpty,
        'interests' => (u['hobbies'] is List) && (u['hobbies'] as List).isNotEmpty,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final u = snap.data?.data();
        if (u == null) return const SizedBox.shrink();
        final missing = _steps.where((s) => !_done(s.$1, u)).toList();
        if (missing.isEmpty) return const SizedBox.shrink();
        final percent = ((_steps.length - missing.length) / _steps.length * 100).round();
        final c = context.colors;
        return MangoAppear(
          child: Container(
            margin: const EdgeInsets.fromLTRB(MangoSpace.s4, 0, MangoSpace.s4, MangoSpace.s3),
            padding: const EdgeInsets.all(MangoSpace.s4),
            decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(MangoRadius.lg)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(value: percent / 100, strokeWidth: 4, backgroundColor: c.borderSubtle, semanticsLabel: 'Profile $percent percent complete'),
                    Text('$percent%', style: context.type.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: MangoSpace.s3),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Finish your profile', style: context.type.titleMedium),
                    Text('People are more likely to follow a complete profile.', style: context.type.bodySmall?.copyWith(color: c.textSecondary)),
                  ]),
                ),
              ]),
              const SizedBox(height: MangoSpace.s3),
              Wrap(spacing: MangoSpace.s2, runSpacing: MangoSpace.s2, children: [
                for (final s in missing)
                  ActionChip(
                    avatar: Icon(s.$3, size: 18, color: c.textBrand),
                    label: Text(s.$2),
                    onPressed: () => Get.to(() => AccountSettingsPage()),
                  ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
