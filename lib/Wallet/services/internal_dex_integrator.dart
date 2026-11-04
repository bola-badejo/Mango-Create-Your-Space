
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, FieldValue;
import 'package:get/get.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/data/trading_engine.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class DEXTradingIntegrator extends GetxService {
  final TradingEngine _tradingEngine = Get.find<TradingEngine>();
  final WalletService _walletService = Get.find<WalletService>();

  Future<DEXTradingIntegrator> init() async {
    print('✅ DEX Trading Integrator Initialized');
    return this;
  }

  
  Future<TradeResult> placeOrder({
    required String userId,
    required String pair,
    required String side, 
    required String orderType, 
    required Decimal quantity,
    required Decimal price, 
  }) async {
    try {
      
      final quantityInt = quantity.toSatoshis().toInt();
      final priceInt = price.toSatoshis().toInt();

      
      final order = Order(
        orderId: _generateOrderId(),
        userId: userId,
        pair: pair,
        side: side,
        orderType: orderType,
        quantity: quantityInt,
        price: priceInt,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        signature: _generateOrderSignature(userId),
      );

      
      final response = _tradingEngine.createOrder(order);

      if (response.success) {
        
        await _recordTradeTransaction(userId, order, response);

        return TradeResult(
          success: true,
          orderId: response.orderId,
          filledQuantity: Decimal.fromInt(response.filledQuantity),
          message: 'Order placed successfully',
        );
      } else {
        return TradeResult(
          success: false,
          error: response.message,
        );
      }
    } catch (e) {
      return TradeResult(
        success: false,
        error: 'Order failed: $e',
      );
    }
  }

  Future<void> _recordTradeTransaction(
    String userId, 
    Order order, 
    OrderResponse response,
  ) async {
    final firestore = FirebaseFirestore.instance;
    
    await firestore.collection('user_trades').add({
      'user_id': userId,
      'order_id': order.orderId,
      'pair': order.pair,
      'side': order.side,
      'order_type': order.orderType,
      'quantity': order.quantity,
      'price': order.price,
      'filled_quantity': response.filledQuantity,
      'status': order.status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  
  Future<List<Order>> getUserOpenOrders(String userId) async {
    return _tradingEngine.getUserOrders(userId)
        .where((order) => order.status == 'PENDING' || order.status == 'PARTIALLY_FILLED')
        .toList();
  }

  
  Future<bool> cancelUserOrder(String userId, String orderId) async {
    final response = _tradingEngine.cancelOrder(orderId, userId);
    return response.success;
  }

  
  Future<Map<String, dynamic>> getMarketData(String pair) async {
    final orderBook = _tradingEngine.getOrderBook(pair);
    
    final bestBid = orderBook.bids.isNotEmpty ? orderBook.bids.first.price : 0;
    final bestAsk = orderBook.asks.isNotEmpty ? orderBook.asks.first.price : 0;
    
    return {
      'pair': pair,
      'best_bid': Decimal.fromInt(bestBid),
      'best_ask': Decimal.fromInt(bestAsk),
      'spread': bestAsk > 0 ? ((bestAsk - bestBid) / bestAsk) * 100 : 0,
      'timestamp': DateTime.now(),
    };
  }

  
  String _generateOrderId() {
    final time = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'order_${time}_$random';
  }

  String _generateOrderSignature(String userId) {
    return 'sig_${userId}_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class TradeResult {
  final bool success;
  final String? orderId;
  final Decimal? filledQuantity;
  final String? message;
  final String? error;

  TradeResult({
    required this.success,
    this.orderId,
    this.filledQuantity,
    this.message,
    this.error,
  });
}