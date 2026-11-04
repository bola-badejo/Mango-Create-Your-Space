
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@mangoapp.ng',
      query: 'subject=Mango Help Request',
    );
    if (!await launchUrl(emailLaunchUri)) {
      throw 'Could not open email client.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help Center"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _helpCard(
            context,
            title: "Getting Started",
            content:
                "Learn how to create your account, explore courses, and start earning Mango Coins.",
          ),
          _helpCard(
            context,
            title: "Wallet & Payments",
            content:
                "Understand how to withdraw your earnings, manage balance, and handle Mango Coin conversions.",
          ),
          _helpCard(
            context,
            title: "Creator System",
            content:
                "Read about publishing songs, books, and podcasts — plus our community content guidelines.",
          ),
          _helpCard(
            context,
            title: "AI Companions",
            content:
                "Discover how to interact safely with Ollie, Amoye, Adaobi, and Dan Baba.",
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _sendEmail,
              icon: const Icon(Icons.email_outlined, size: 16),
              label: const Text("Contact Support"),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              "support@mangoapp.ng",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpCard(BuildContext context,
      {required String title, required String content}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 11.5)),
            const SizedBox(height: 6),
            Text(
              content,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
