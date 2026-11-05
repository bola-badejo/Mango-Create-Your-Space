import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Terms & Conditions",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0.5,
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 3.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome to Mango",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Mango is more than an app. It is a movement — a decentralized ecosystem where creativity, knowledge, and honest work collide to shape a new digital economy for Africa and the world. Every tap, every creation, every voice contributes to a shared orbit of progress.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              _sectionTitle("1. Acceptance of Orbit"),
              _sectionText(
                "By entering the Mango ecosystem, you consent to operate under principles of integrity, collaboration, and creativity. These terms form the gravitational core of our community.",
              ),

              _sectionTitle("2. Your Digital Identity"),
              _sectionText(
                "Every Mango account is a node in our network — a unique beacon of identity. You are responsible for maintaining the security of your credentials and device.",
              ),

              _sectionTitle("3. Creator System & Cultural Integrity"),
              _sectionText(
                "Creators on Mango hold digital sovereignty. Each upload must be authentic, lawful, and respectful. Plagiarism or exploitation destabilizes the ecosystem.",
              ),

              _sectionTitle("4. Mango Coin & Digital Economy"),
              _sectionText(
                "Mango Coin represents energy exchange — a reward for movement and value creation. Conversion rates or mining algorithms may evolve as Mango grows.",
              ),

              _sectionTitle("5. Revenue, Commission & Trust"),
              _sectionText(
                "Mango’s 20% commission sustains the ecosystem. The remaining 80% belongs to the creator, securely stored and traceable through Mango Wallet.",
              ),

              _sectionTitle("6. Intellectual Property & Creative Ownership"),
              _sectionText(
                "You own your creations. Mango only provides the vessel to display and promote them within the app. Your content remains your property.",
              ),

              _sectionTitle("7. Behavior, Safety & Frequency Alignment"),
              _sectionText(
                "Mango is a sanctuary for creativity. Any attempt to spread hate, misinformation, or cult ideologies will result in immediate suspension.",
              ),

              _sectionTitle("8. Artificial Intelligence & Ethics"),
              _sectionText(
                "Our AI entities — Ollie, Amoye, Adaobi, Dan Baba, and the Maths Solver — assist learning and creativity. Interactions are anonymized and ethically managed.",
              ),

              _sectionTitle("9. Data, Privacy & Transparency"),
              _sectionText(
                "Your data is protected and never sold. Mango uses encryption, layered authentication, and secure protocols for storage and analytics.",
              ),

              _sectionTitle("10. Community & Ecosystem Evolution"),
              _sectionText(
                "Mango’s systems may evolve for better performance and harmony. You’ll be notified of major updates through the app.",
              ),

              _sectionTitle("11. Termination & Balance"),
              _sectionText(
                "Violation of these terms may result in account suspension or termination. This ensures balance within the Mango ecosystem.",
              ),

              _sectionTitle("12. Limitation of Liability"),
              _sectionText(
                "Mango operates as-is. We’re not liable for interruptions, losses, or hardware failures. Usage implies consent to this shared risk.",
              ),

              _sectionTitle("13. Amendments & Updates"),
              _sectionText(
                "Terms may evolve with Mango’s growth. Continued use after updates means you agree to remain in sync with the platform’s vision.",
              ),

              const SizedBox(height: 24),
              Divider(color: MangoPalette.grey500.withOpacity(0.3)),
              const SizedBox(height: 32),

              _quoteText(
                "“Mango is not just an app. It is a garden of minds — where creation, learning, and value grow together.”",
              ),

              const SizedBox(height: 30),
              _footer(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.5,
      ),
    );
  }

  Widget _quoteText(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Text(
            "Last updated • October 2025",
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: Colors.lightGreenAccent.withOpacity(.4),
              ),
              onPressed: () => Get.back(),
              child: const Text(
                "Ok, I get it",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
