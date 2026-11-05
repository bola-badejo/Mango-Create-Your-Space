// A short explainer right after the quick start: three cards, skippable.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MangoExplainer extends StatefulWidget {
  const MangoExplainer({super.key});

  @override
  State<MangoExplainer> createState() => _MangoExplainerState();
}

class _MangoExplainerState extends State<MangoExplainer> {
  final _pages = PageController();
  int _i = 0;

  static const _cards = [
    ('🎧', 'Discover and enjoy', 'Music, podcasts, films and books from creators across Africa and beyond. Mango remembers where you left off.'),
    ('🥭', 'Create, share, earn', 'Post, upload your work, and earn MangoCoin when people listen, watch and read. Open your Creator Studio from your profile.'),
    ('💬', 'Chat and hang out in Spaces', 'Snap and chat with friends. Step into Spaces to meet people, leave messages and join live events.'),
  ];

  void _finish() => Get.offAllNamed(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _i == _cards.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _finish, child: const Text('Skip')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _cards.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final (emoji, title, body) = _cards[i];
                return Padding(
                  padding: const EdgeInsets.all(MangoSpace.s6),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 88))),
                    const SizedBox(height: MangoSpace.s6),
                    Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: context.type.headlineMedium)),
                    const SizedBox(height: MangoSpace.s3),
                    Text(body, textAlign: TextAlign.center, style: context.type.bodyLarge?.copyWith(color: c.textSecondary)),
                  ]),
                );
              },
            ),
          ),
          Semantics(
            label: 'Card ${_i + 1} of ${_cards.length}',
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var d = 0; d < _cards.length; d++)
                AnimatedContainer(
                  duration: MangoMotion.duration(context, MangoMotionTokens.fast),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: d == _i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: d == _i ? c.actionPrimary : c.borderSubtle, borderRadius: BorderRadius.circular(MangoRadius.pill)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(MangoSpace.s6),
            child: MangoButton(
              label: last ? 'Get started' : 'Next',
              expand: true,
              onPressed: () => last ? _finish() : _pages.nextPage(duration: MangoMotion.duration(context, MangoMotionTokens.base), curve: Curves.easeOutCubic),
            ),
          ),
        ]),
      ),
    );
  }
}
