
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Wallet/components/animated_card.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService walletService = Get.find<WalletService>();
  WalletData? balance;
  List<TransactionRecord> transactions = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final WalletData balanceData = await walletService.getUserBalance();
      final List<TransactionRecord> transactionHistory = await walletService
          .getTransactionHistory();

      if (mounted) {
        setState(() {
          balance = balanceData;
          transactions = transactionHistory;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load wallet: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            'Mango Wallet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDarkMode
            ? Colors.deepOrange.shade800
            : Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: _buildBody(isDarkMode),
      floatingActionButton: _buildFloatingActionButton(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator.adaptive(
      onRefresh: _loadWalletData,
      color: Colors.orange.shade600,
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              _buildBalanceCard(isDarkMode),
              _buildQuickActions(isDarkMode),
              _buildTransactionHistory(isDarkMode),
              _buildRewardsSection(isDarkMode),
              _buildUtilitySection(isDarkMode),
              _buildLegalDisclaimer(),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDarkMode) {
  return AnimatedBalanceCard(
    isDarkMode: isDarkMode,
    balance: balance,
  );
}

  Widget _buildUtilitySection(bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.green.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                'Token Utility',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.green.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildUtilityItem('🎵 Access Premium Music Content'),
          _buildUtilityItem('📚 Unlock Exclusive Books & Articles'),
          _buildUtilityItem('🎬 Watch Premium Videos & Movies'),
          _buildUtilityItem('💬 Join Exclusive Community Spaces'),
          _buildUtilityItem('⭐ Reward Favorite Creators'),
          _buildUtilityItem('🚀 Early Access to New Features'),
        ],
      ),
    );
  }

  Widget _buildUtilityItem(String utility) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Colors.green.shade500,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              utility,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.send_rounded,
            label: 'Send',
            onTap: _showTransferSheet,
            color: Colors.orange.shade600,
            isDarkMode: isDarkMode,
          ),
          _buildActionButton(
            icon: Icons.qr_code_2_rounded,
            label: 'Receive',
            onTap: _showReceiveSheet,
            color: Colors.green.shade600,
            isDarkMode: isDarkMode,
          ),
          _buildActionButton(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: _showTransactionHistory,
            color: Colors.blue.shade600,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  void _showTransactionHistory() {
    
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          FullTransactionHistorySheet(transactions: transactions),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDarkMode,
  }) {
    return Semantics(
      button: true,
      label: '$label Mango tokens',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory(bool isDarkMode) {
    return Container(
      margin: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.grey.shade900,
                ),
              ),
              Spacer(),
              if (transactions.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'View all activity history',
                  child: TextButton(
                    onPressed: _showFullTransactionHistory,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade600,
                    ),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          if (transactions.isEmpty)
            _buildEmptyState(isDarkMode)
          else
            _buildTransactionList(isDarkMode),
        ],
      ),
    );
  }

  
  Widget _buildRewardsSection(bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.black87,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: Colors.orange.shade600,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Earn Rewards',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.purple.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Complete activities to earn Mango tokens',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildRewardButton(
                activity: ActivityType.dailyLogin,
                icon: Icons.calendar_today_rounded,
                label: 'Daily Login',
                isDarkMode: isDarkMode,
              ),
              _buildRewardButton(
                activity: ActivityType.createPost,
                icon: Icons.post_add_rounded,
                label: 'Create Post',
                isDarkMode: isDarkMode,
              ),
              _buildRewardButton(
                activity: ActivityType.likeContent,
                icon: Icons.favorite_rounded,
                label: 'Like Content',
                isDarkMode: isDarkMode,
              ),
              _buildRewardButton(
                activity: ActivityType.shareContent,
                icon: Icons.share_rounded,
                label: 'Share',
                isDarkMode: isDarkMode,
              ),
              _buildRewardButton(
                activity: ActivityType.readArticle,
                icon: Icons.article_rounded,
                label: 'Read Article',
                isDarkMode: isDarkMode,
              ),
              _buildRewardButton(
                activity: ActivityType.watchVideo,
                icon: Icons.play_circle_rounded,
                label: 'Watch Video',
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildStreakInfo(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildRewardButton({
    required ActivityType activity,
    required IconData icon,
    required String label,
    required bool isDarkMode,
  }) {
    final walletService = Get.find<WalletService>();
    final rewardInfo = walletService.getRewardInfo(activity);
    final rewardAmount = rewardInfo['amount'] as Decimal;
    final description = rewardInfo['description'] as String;

    return Semantics(
      button: true,
      label: '$label - Earn ${rewardAmount.toFixed(6)} MNG',
      child: GestureDetector(
        onTap: () => _claimReward(activity),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.purple.shade800 : Colors.purple.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade300.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.purple.shade600, size: 20),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.purple.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2),
              Text(
                '${rewardAmount.toFixed(3)} MNG',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakInfo(bool isDarkMode) {
    final walletService = Get.find<WalletService>();
    final user = FirebaseAuth.instance.currentUser;
    final streak = user != null ? walletService.getUserStreak(user.uid) : 0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.orange.shade900 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: Colors.orange.shade600,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login Streak',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.orange.shade800,
                  ),
                ),
                Text(
                  '$streak days • +${(streak * 10).toString()}% bonus',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode
                        ? Colors.orange.shade300
                        : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (streak > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$streak🔥',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _claimReward(ActivityType activity) async {
    try {
      final result = await walletService.rewardForActivity(activity);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.celebration_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🎉 +${result.amount.toFixed(6)} MNG earned!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          duration: Duration(seconds: 3),
        ),
      );

      
      _loadWalletData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Widget _buildTransactionList(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          ...transactions
              .take(5)
              .map((tx) => _buildTransactionItem(tx, isDarkMode))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionRecord transaction, bool isDarkMode) {
    final isCredit = transaction.isCredit;
    final icon = isCredit
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final color = isCredit ? Colors.green.shade500 : Colors.red.shade500;
    final typeLabel = isCredit ? 'Received' : 'Sent';

    return Semantics(
      button: true,
      label:
          '$typeLabel ${transaction.amount.toFixed(6)} Mango tokens for ${transaction.memo ?? 'transaction'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTransactionDetails(transaction),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.memo ?? 'Platform Activity',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.grey.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'MMM dd, yyyy - HH:mm',
                        ).format(transaction.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.formattedAmount,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Semantics(
            label: 'No activity yet',
            child: Icon(
              Icons.celebration_rounded,
              size: 80,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Activity Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start engaging with content to earn\nyour first Mango tokens!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalDisclaimer() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.blue.shade600,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Important Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Mango tokens (MNG) are utility tokens for platform engagement '
            'and do not represent any financial investment or security. '
            'Tokens have no guaranteed monetary value and are designed '
            'solely for use within the Mango social platform ecosystem.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isDarkMode) {
    return Semantics(
      button: true,
      label: 'Refresh wallet data',
      child: FloatingActionButton(
        onPressed: _loadWalletData,
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        child: Icon(Icons.refresh_rounded, size: 26),
        tooltip: 'Refresh Wallet',
      ),
    );
  }

  
  void _showTransferSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferBottomSheet(walletService: walletService),
    ).then((_) => _loadWalletData());
  }

  void _showReceiveSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiveBottomSheet(
        address: balance?.address ?? 'No address available',
      ),
    );
  }

  void _showTransactionDetails(TransactionRecord transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailsSheet(transaction: transaction),
    );
  }

  void _showFullTransactionHistory() {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening full activity history...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Loading wallet data',
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your wallet...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Error loading wallet',
              child: Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Unable to Load Wallet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _loadWalletData,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade800,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class TransferBottomSheet extends StatefulWidget {
  final WalletService walletService;

  const TransferBottomSheet({required this.walletService});

  @override
  _TransferBottomSheetState createState() => _TransferBottomSheetState();
}

class _TransferBottomSheetState extends State<TransferBottomSheet> {
  final TextEditingController receiverController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  bool isTransferring = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.send_rounded,
                  color: Colors.orange.shade600,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Send Mango Tokens',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 24),
            Semantics(
              textField: true,
              label: 'Enter recipient wallet address',
              child: TextField(
                controller: receiverController,
                decoration: InputDecoration(
                  labelText: 'Recipient Address',
                  hintText: 'Enter wallet address...',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                maxLines: 1,
              ),
            ),
            SizedBox(height: 16),
            Semantics(
              textField: true,
              label: 'Enter amount to send',
              child: TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (MNG)',
                  hintText: '0.000000',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  suffixText: 'MNG',
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Minimum amount: 0.000001 MNG',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isTransferring ? null : _transferCoins,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isTransferring
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            'Send',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transferCoins() async {
    final receiverId = receiverController.text.trim();
    final amountString = amountController.text.trim();

    if (receiverId.isEmpty || amountString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amountDouble = double.tryParse(amountString);
    if (amountDouble == null || amountDouble <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = Decimal.fromDouble(amountDouble);

    setState(() => isTransferring = true);

    try {
      await widget.walletService.transferMangoCoins(
        receiverAddress: receiverId,
        amount: amount,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Transfer completed successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Transfer failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isTransferring = false);
      }
    }
  }
}


class ReceiveBottomSheet extends StatelessWidget {
  final String address;

  const ReceiveBottomSheet({required this.address});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.green.shade600,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Receive Mango Tokens',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Share this address to receive Mango tokens',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Semantics(
                    label:
                        'Your wallet address: ${_formatAddressForSpeech(address)}',
                    child: SelectableText(
                      address,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Monospace',
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.grey.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => _copyToClipboard(context, address),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Copy Address',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Others can send you Mango tokens using this address',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAddressForSpeech(String address) {
    return address
        .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)} ')
        .trim();
  }

  void _copyToClipboard(BuildContext context, String text) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Address copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}


class TransactionDetailsSheet extends StatelessWidget {
  final TransactionRecord transaction;

  const TransactionDetailsSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Transaction Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20),
            
            Text('Transaction details view coming soon...'),
            SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class FullTransactionHistorySheet extends StatelessWidget {
  final List<TransactionRecord> transactions;

  const FullTransactionHistorySheet({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Colors.blue.shade600,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          Expanded(
            child: transactions.isEmpty
                ? _buildEmptyHistory()
                : OptimizedListView(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return _buildHistoryTransactionItem(
                        transaction,
                        isDarkMode,
                        context,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'No Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTransactionItem(
    TransactionRecord transaction,
    bool isDarkMode,
    BuildContext context,
  ) {
    final isCredit = transaction.isCredit;
    final icon = isCredit
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final color = isCredit ? Colors.green.shade500 : Colors.red.shade500;
    final typeLabel = isCredit ? 'Received' : 'Sent';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          transaction.memo ?? 'Transaction',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy - HH:mm').format(transaction.timestamp),
          style: TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.formattedAmount,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 2),
            Text(
              typeLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context); 
          
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                TransactionDetailsSheet(transaction: transaction),
          );
        },
      ),
    );
  }
}


