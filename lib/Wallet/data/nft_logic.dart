
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/data/currency_service.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class NFTMarketplaceService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late WalletService _walletService;
  late CurrencyService _currencyService;

  
  static final Decimal marketplaceFee = Decimal.fromDouble(0.025); 
  static final Decimal creatorRoyalty = Decimal.fromDouble(0.10); 

  @override
  Future<void> onInit() async {
    _walletService = Get.find<WalletService>();
    _currencyService = Get.find<CurrencyService>();
    super.onInit();
  }

  Future<NFTSaleResult> purchaseNFT({
    required String nftId,
    required String sellerId,
    required String creatorId,
    required Decimal price,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    
    final marketplaceFeeAmount = price * marketplaceFee;
    final creatorRoyaltyAmount = price * creatorRoyalty;
    final sellerAmount = price - marketplaceFeeAmount - creatorRoyaltyAmount;

    try {
      
      final batch = _firestore.batch();

      
      await _walletService.transferMangoCoins(
        receiverAddress: sellerId,
        amount: sellerAmount,
        memo: 'NFT sale: $nftId',
      );

      
      await _walletService.transferMangoCoins(
        receiverAddress: 'mango_marketplace',
        amount: marketplaceFeeAmount,
        memo: 'Marketplace fee for NFT: $nftId',
      );

      
      if (creatorId != sellerId) {
        await _walletService.transferMangoCoins(
          receiverAddress: creatorId,
          amount: creatorRoyaltyAmount,
          memo: 'Creator royalty for NFT: $nftId',
        );
      }

      
      await _currencyService.collectGasFee(TransactionType.nft, user.uid);

      
      final nftRef = _firestore.collection('nfts').doc(nftId);
      batch.update(nftRef, {
        'owner_id': user.uid,
        'previous_owner_id': sellerId,
        'last_sale_price': price.toSatoshis().toInt(),
        'last_sale_time': FieldValue.serverTimestamp(),
        'sale_count': FieldValue.increment(1),
      });

      
      final saleId = _generateSaleId();
      final saleRef = _firestore.collection('nft_sales').doc(saleId);
      batch.set(saleRef, {
        'sale_id': saleId,
        'nft_id': nftId,
        'buyer_id': user.uid,
        'seller_id': sellerId,
        'creator_id': creatorId,
        'price': price.toSatoshis().toInt(),
        'marketplace_fee': marketplaceFeeAmount.toSatoshis().toInt(),
        'creator_royalty': creatorRoyaltyAmount.toSatoshis().toInt(),
        'seller_amount': sellerAmount.toSatoshis().toInt(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      
      await _sendNFTSaleNotifications(
        nftId: nftId,
        buyerId: user.uid,
        sellerId: sellerId,
        creatorId: creatorId,
        price: price,
        marketplaceFee: marketplaceFeeAmount,
        creatorRoyalty: creatorRoyaltyAmount,
      );

      return NFTSaleResult(
        success: true,
        saleId: saleId,
        price: price,
        marketplaceFee: marketplaceFeeAmount,
        creatorRoyalty: creatorRoyaltyAmount,
        sellerAmount: sellerAmount,
      );

    } catch (e) {
      await _recordFailedSale(nftId, user.uid, sellerId, price, e.toString());
      rethrow;
    }
  }

  Future<void> _sendNFTSaleNotifications({
    required String nftId,
    required String buyerId,
    required String sellerId,
    required String creatorId,
    required Decimal price,
    required Decimal marketplaceFee,
    required Decimal creatorRoyalty,
  }) async {
    final notifications = <Map<String, dynamic>>[];

    
    notifications.add({
      'user_id': buyerId,
      'type': 'nft_purchase',
      'title': 'NFT Purchased!',
      'message': 'You bought an NFT for ${price.toFixed(6)} MNG',
      'data': {'nft_id': nftId, 'price': price.toDouble()},
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    
    notifications.add({
      'user_id': sellerId,
      'type': 'nft_sale',
      'title': 'NFT Sold!',
      'message': 'Your NFT sold for ${price.toFixed(6)} MNG',
      'data': {'nft_id': nftId, 'price': price.toDouble()},
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    
    if (creatorId != sellerId) {
      notifications.add({
        'user_id': creatorId,
        'type': 'creator_royalty',
        'title': 'Royalty Earned!',
        'message': 'You earned ${creatorRoyalty.toFixed(6)} MNG from NFT sale',
        'data': {'nft_id': nftId, 'royalty': creatorRoyalty.toDouble()},
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    
    final batch = _firestore.batch();
    for (final notification in notifications) {
      final docId = _firestore.collection('messages').doc().id;
      batch.set(_firestore.collection('messages').doc(docId), notification);
    }
    await batch.commit();
  }

  Future<void> _recordFailedSale(
    String nftId,
    String buyerId,
    String sellerId,
    Decimal price,
    String error,
  ) async {
    await _firestore.collection('failed_nft_sales').add({
      'nft_id': nftId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'price': price.toSatoshis().toInt(),
      'error': error,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _generateSaleId() {
    return 'nft_sale_${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid}';
  }
}

class NFTSaleResult {
  final bool success;
  final String saleId;
  final Decimal price;
  final Decimal marketplaceFee;
  final Decimal creatorRoyalty;
  final Decimal sellerAmount;

  NFTSaleResult({
    required this.success,
    required this.saleId,
    required this.price,
    required this.marketplaceFee,
    required this.creatorRoyalty,
    required this.sellerAmount,
  });
}