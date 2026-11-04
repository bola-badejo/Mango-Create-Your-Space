import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/space_model.dart';

class MoreOptionsScreen extends StatelessWidget {
  final SpaceModel space;

  const MoreOptionsScreen({Key? key, required this.space}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          "More Options",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).primaryColorLight,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).primaryColorLight),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            
            _buildSpaceInfoCard(context),
            
            const SizedBox(height: 20),
            
            
            _buildSupportSection(context),
            
            const SizedBox(height: 20),
            
            
            _buildLegalSection(context),
            
            const SizedBox(height: 20),
            
            
            _buildAboutSection(context),
            
            const SizedBox(height: 20),
            
            
            _buildAdvancedSection(context),
            
            const SizedBox(height: 30),
            
            
            _buildAppInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.orange),
            ),
            child: Icon(
              Icons.space_dashboard,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  space.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColorLight,
                  ),
                ),
                Text(
                  space.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip('${space.members} members', Icons.people),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      space.price.isEmpty ? 'Free' : '₦${space.price}',
                      Icons.attach_money,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> supportCard = GlobalKey();

    return ExpansionTileCard(
      key: supportCard,
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(
          Icons.help_center,
          size: 18,
          color: Colors.white,
        ),
      ),
      title: Text(
        "Support & Help",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "Get help and support resources",
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: <Widget>[
        const Divider(thickness: 0.10, height: 0.10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            children: [
              _buildOptionItem(
                context,
                Icons.help_outline,
                'Help Center',
                'Browse help articles and guides',
                ()=>_launchHelpCenter(context),
              ),
              _buildOptionItem(
                context,
                Icons.bug_report,
                'Report a Problem',
                'Found a bug or issue? Let us know',
                _reportProblem(context),
              ),
              _buildOptionItem(
                context,
                Icons.feedback,
                'Send Feedback',
                'Share your thoughts and suggestions',
                ()=>_sendFeedback(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegalSection(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> legalCard = GlobalKey();

    return ExpansionTileCard(
      key: legalCard,
      leading: CircleAvatar(
        backgroundColor: Colors.purple,
        child: Icon(
          Icons.gavel,
          size: 18,
          color: Colors.white,
        ),
      ),
      title: Text(
        "Legal",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "Legal documents and policies",
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: <Widget>[
        const Divider(thickness: 0.10, height: 0.10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            children: [
              _buildOptionItem(
                context,
                Icons.security,
                'Privacy Policy',
                'How we protect your data',
                ()=>_showPrivacyPolicy(context),
              ),
              _buildOptionItem(
                context,
                Icons.description,
                'Terms of Service',
                'Our rules and guidelines',
                ()=>_showTermsOfService(context),
              ),
              _buildOptionItem(
                context,
                Icons.groups,
                'Community Guidelines',
                'Expected behavior in spaces',
                ()=>_showCommunityGuidelines(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> aboutCard = GlobalKey();

    return ExpansionTileCard(
      key: aboutCard,
      leading: CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(
          Icons.info,
          size: 18,
          color: Colors.white,
        ),
      ),
      title: Text(
        "About",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "Technical information and details",
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: <Widget>[
        const Divider(thickness: 0.10, height: 0.10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            children: [
              _buildOptionItem(
                context,
                Icons.space_dashboard,
                'Space Details',
                'Technical information about this space',
                _showSpaceDetails(context),
              ),
              _buildOptionItem(
                context,
                Icons.code,
                'Open Source Licenses',
                'Third-party libraries we use',
                ()=>_showLicenses(context),
              ),
              _buildOptionItem(
                context,
                Icons.update,
                'Check for Updates',
                'Update to the latest version',
                ()=>_checkForUpdates(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> advancedCard = GlobalKey();

    return ExpansionTileCard(
      key: advancedCard,
      leading: CircleAvatar(
        backgroundColor: Colors.orange,
        child: Icon(
          Icons.settings,
          size: 18,
          color: Colors.white,
        ),
      ),
      title: Text(
        "Advanced",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "Advanced settings and utilities",
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: <Widget>[
        const Divider(thickness: 0.10, height: 0.10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            children: [
              _buildOptionItem(
                context,
                Icons.storage,
                'Clear Cache',
                'Free up storage space',
                _clearCache(context),
              ),
              _buildOptionItem(
                context,
                Icons.refresh,
                'Refresh Data',
                'Reload all space information',
                ()=>_refreshData(context),
              ),
              _buildOptionItem(
                context,
                Icons.analytics,
                'Debug Information',
                'Technical details for support',
                _showDebugInfo(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionItem(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: MaterialButton(
        onPressed: onTap,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.grey[400], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColorLight,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Mango Spaces',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2024 Mango Team. All rights reserved.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  
  void _launchHelpCenter(context) async {
    const url = 'https://help.mangoapp.com';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      UtilsService().showSnackbar('Error', 'Could not launch help center', context: context);
    }
  }

  _reportProblem(context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report a Problem',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColorLight,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Describe the issue',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: MaterialButton(
                onPressed: () {
                  Get.back();
                  UtilsService().showSnackbar('Success', 'Problem reported successfully', context: context);
                },
                color: Colors.orange,
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendFeedback(context) {
    UtilsService().showSnackbar('Feedback', 'Thank you for your feedback!', context: context);
  }

  void _showPrivacyPolicy(context) {
    UtilsService().showSnackbar('Privacy Policy', 'Opening privacy policy...', context: context);
  }

  void _showTermsOfService(context) {
    UtilsService().showSnackbar('Terms of Service', 'Opening terms of service...', context: context);
  }

  void _showCommunityGuidelines(context) {
    UtilsService().showSnackbar('Community Guidelines', 'Opening community guidelines...', context: context);
  }

  _showSpaceDetails(context) {
    Get.defaultDialog(
      title: "Space Details",
      backgroundColor: Theme.of(context).cardColor,
      titleStyle: TextStyle(color: Theme.of(context).primaryColorLight),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Space ID', space.id),
            _buildDetailRow('Title', space.title),
            _buildDetailRow('Category', space.category),
            _buildDetailRow('Price', space.price.isEmpty ? 'Free' : '₦${space.price}'),
            _buildDetailRow('Members', space.members.toString()),
            _buildDetailRow('Rating', space.rating.isEmpty ? '0.0' : space.rating),
            _buildDetailRow('Creator ID', space.postCreator),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showLicenses(context) {
    UtilsService().showSnackbar('Licenses', 'Showing open source licenses...', context: context);
  }

  void _checkForUpdates(context) {
    UtilsService().showSnackbar('Update Check', 'Your app is up to date!', context: context);
  }

  _clearCache(context) {
    Get.defaultDialog(
      title: "Clear Cache",
      backgroundColor: Theme.of(context).cardColor,
      titleStyle: TextStyle(color: Theme.of(context).primaryColorLight),
      content: Text(
        "This will free up storage space. This action cannot be undone.",
        style: TextStyle(color: Theme.of(context).primaryColorLight),
      ),
      confirm: MaterialButton(
        onPressed: () {
          Get.back();
          UtilsService().showSnackbar('Success', 'Cache cleared successfully', context: context);
        },
        color: Colors.orange,
        child: const Text('Clear'),
      ),
      cancel: MaterialButton(
        onPressed: () => Get.back(),
        child: Text('Cancel'),
      ),
    );
  }

  void _refreshData(context) {
    UtilsService().showSnackbar('Refreshed', 'Space data has been refreshed', context: context);
  }

  _showDebugInfo(context) {
    Get.defaultDialog(
      title: "Debug Information",
      backgroundColor: Theme.of(context).cardColor,
      titleStyle: TextStyle(color: Theme.of(context).primaryColorLight),
      content: SingleChildScrollView(
        child: Text(
          'Space: ${space.title}\n'
          'ID: ${space.id}\n'
          'Category: ${space.category}\n'
          'Members: ${space.members}\n'
          'Price: ${space.price}\n'
          'Rating: ${space.rating}\n'
          'Creator: ${space.postCreator}\n'
          'Features: Music: ${space.hasMusic}, Books: ${space.hasBooks}, Podcast: ${space.hasPodcast}, Vines: ${space.hasVines}, Shop: ${space.hasShop}, Lounge: ${space.hasLounge}',
          style: TextStyle(color: Theme.of(context).primaryColorLight),
        ),
      ),
    );
  }
}