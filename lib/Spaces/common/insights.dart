import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/animation.dart';
import '../controllers/space_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class SpaceInsightsScreen extends StatelessWidget {
  final SpaceModel space;

  const SpaceInsightsScreen({Key? key, required this.space}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        
        title: Text(
          "Space Insights",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).primaryColorLight,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
        tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: Theme.of(context).primaryColorLight),
          onPressed: () => Get.back(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('spaces')
            .doc(space.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
          }

          final spaceData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          return _buildInsightsContent(context, spaceData);
        },
      ),
    );
  }

  Widget _buildInsightsContent(BuildContext context, Map<String, dynamic> spaceData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          
          _buildOverviewCards(context, spaceData),
          
          const SizedBox(height: 20),
          
          
          _buildGrowthAnalytics(context),
          
          const SizedBox(height: 20),
          
          
          _buildEngagementMetrics(context),
          
          const SizedBox(height: 20),
          
          
          _buildMemberActivity(context),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, Map<String, dynamic> spaceData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MangoPalette.black,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(
                context,
                'Total Members',
                spaceData['members']?.toString() ?? '0',
                Icons.people,
                Colors.blue,
              ),
              _buildMetricItem(
                context,
                'Active Today',
                '24',
                Icons.online_prediction,
                MangoPalette.green500,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(
                context,
                'New This Week',
                '12',
                Icons.trending_up,
                MangoPalette.green500,
              ),
              _buildMetricItem(
                context,
                'Engagement',
                '68%',
                Icons.person,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.circular(MangoRadius.sm),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColorLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: MangoPalette.grey400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthAnalytics(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> growthCard = GlobalKey();

    return ExpansionTileCard(
      elevation: 0,
      key: growthCard,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(
          Icons.trending_up,
          size: 18,
          color: Theme.of(context).primaryColorLight,
        ),
      ),
      title: Text(
        "Growth Analytics",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "Member growth and trends",
        style: TextStyle(
          fontSize: 12,
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
              SizedBox(
                height: 200,
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                    labelStyle: TextStyle(
                      color: Theme.of(context).primaryColorLight.withOpacity(0.6),
                    ),
                  ),
                  primaryYAxis: NumericAxis(
                    labelStyle: TextStyle(
                      color: Theme.of(context).primaryColorLight.withOpacity(0.6),
                    ),
                  ),
                  series: <LineSeries<GrowthData, String>>[
                    LineSeries<GrowthData, String>(
                      dataSource: [
                        GrowthData('Mon', 120),
                        GrowthData('Tue', 135),
                        GrowthData('Wed', 148),
                        GrowthData('Thu', 162),
                        GrowthData('Fri', 175),
                        GrowthData('Sat', 190),
                        GrowthData('Sun', 210),
                      ],
                      xValueMapper: (GrowthData data, _) => data.day,
                      yValueMapper: (GrowthData data, _) => data.members,
                      color: MangoPalette.green500,
                      markerSettings: const MarkerSettings(isVisible: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildAnalyticsRow(context, 'Weekly Growth', '+15%', MangoPalette.green500),
              _buildAnalyticsRow(context, 'Active Rate', '68%', Colors.blue),
              _buildAnalyticsRow(context, 'Retention', '92%', MangoPalette.green500),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColorLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetrics(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> engagementCard = GlobalKey();

    return ExpansionTileCard(
      elevation: 0,
      key: engagementCard,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(
          Icons.analytics,
          size: 18,
          color: Theme.of(context).primaryColorLight,
        ),
      ),
      title: Text(
        "Engagement Metrics",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "User activity and interaction",
        style: TextStyle(
          fontSize: 12,
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
              _buildMetricProgress(context, 'Avg. Session', '24 min', 0.8),
              _buildMetricProgress(context, 'Messages/Day', '156', 0.7),
              _buildMetricProgress(context, 'Content Shared', '42', 0.6),
              _buildMetricProgress(context, 'Active Hours', '6 PM - 10 PM', 0.9),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricProgress(BuildContext context, String label, String value, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColorLight,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColorLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: MangoPalette.grey800,
              borderRadius: BorderRadius.circular(MangoRadius.xs),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: MangoPalette.green500,
                  borderRadius: BorderRadius.circular(MangoRadius.xs),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberActivity(BuildContext context) {
    final GlobalKey<ExpansionTileCardState> activityCard = GlobalKey();

    return ExpansionTileCard(
      elevation: 0,
      key: activityCard,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(
          Icons.people_alt,
          size: 18,
          color: Theme.of(context).primaryColorLight,
        ),
      ),
      title: Text(
        "Top Contributors",
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColorLight,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        "Most active members",
        style: TextStyle(
          fontSize: 12,
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
              _buildMemberRow(context, 'John Doe', '152 messages', 1),
              _buildMemberRow(context, 'Sarah Wilson', '128 messages', 2),
              _buildMemberRow(context, 'Mike Chen', '95 messages', 3),
              _buildMemberRow(context, 'Emma Davis', '87 messages', 4),
              _buildMemberRow(context, 'Alex Kim', '76 messages', 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberRow(BuildContext context, String name, String activity, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MangoPalette.black,
        borderRadius: BorderRadius.circular(MangoRadius.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _getRankColor(rank).withOpacity(0.1),
              borderRadius: BorderRadius.circular(MangoRadius.md),
              border: Border.all(color: _getRankColor(rank)),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  color: _getRankColor(rank),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColorLight,
                  ),
                ),
                Text(
                  activity,
                  style: TextStyle(
                    fontSize: 12,
                    color: MangoPalette.grey400,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: MangoPalette.grey400,
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return MangoPalette.grey500;
      case 3: return MangoPalette.green500;
      default: return Colors.blue;
    }
  }
}

class GrowthData {
  final String day;
  final int members;

  GrowthData(this.day, this.members);
}