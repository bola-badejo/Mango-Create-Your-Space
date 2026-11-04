import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:mango/Wallet/data/block.dart';
import 'package:mango/Wallet/data/transactions.dart';

class TradingEngine {
  final ProductionBlockchain blockchain;
  final Map<String, OrderBook> orderBooks;
  final Map<String, List<Order>> userOrders;
  final Map<String, int> balances;
  final Map<String, int> lockedBalances;
  
  TradingEngine({required this.blockchain})
      : orderBooks = {},
        userOrders = {},
        balances = {},
        lockedBalances = {} {
    _initializeOrderBooks();
  }

  void _initializeOrderBooks() {
    orderBooks['MNG/USDC'] = OrderBook(bids: [], asks: [], pair: 'MNG/USDC');
    orderBooks['MNG/WETH'] = OrderBook(bids: [], asks: [], pair: 'MNG/WETH');
    orderBooks['MNG/MATIC'] = OrderBook(bids: [], asks: [], pair: 'MNG/MATIC');
  }

  OrderResponse createOrder(Order order) {
    if (!_validateOrder(order)) {
      return OrderResponse(success: false, message: 'Invalid order');
    }

    if (!_hasSufficientBalance(order)) {
      return OrderResponse(success: false, message: 'Insufficient balance');
    }

    _lockBalanceForOrder(order);

    final orderBook = orderBooks[order.pair];
    if (orderBook == null) {
      return OrderResponse(success: false, message: 'Invalid trading pair');
    }

    final matches = _matchOrder(order, orderBook);
    if (matches.isNotEmpty) {
      _executeTrades(matches, order);
    }

    if (order.filledQuantity < order.quantity) {
      _addToOrderBook(order, orderBook);
    }

    _updateUserOrders(order);

    return OrderResponse(
      success: true,
      message: 'Order created',
      orderId: order.orderId,
      filledQuantity: order.filledQuantity,
    );
  }

  bool _validateOrder(Order order) {
    if (order.quantity <= 0) return false;
    if (order.price <= 0 && order.orderType != 'MARKET') return false;
    if (!['BUY', 'SELL'].contains(order.side)) return false;
    if (!['LIMIT', 'MARKET'].contains(order.orderType)) return false;
    return true;
  }

  bool _hasSufficientBalance(Order order) {
    final asset = order.side == 'BUY' 
        ? order.pair.split('/')[1] 
        : order.pair.split('/')[0];
    
    final requiredAmount = order.side == 'BUY' 
        ? order.quantity * order.price 
        : order.quantity;

    final availableBalance = (balances[order.userId] ?? 0) - (lockedBalances[order.userId] ?? 0);
    return availableBalance >= requiredAmount;
  }

  void _lockBalanceForOrder(Order order) {
    final asset = order.side == 'BUY' 
        ? order.pair.split('/')[1] 
        : order.pair.split('/')[0];
    
    final amount = order.side == 'BUY' 
        ? order.quantity * order.price 
        : order.quantity;

    lockedBalances[order.userId] = (lockedBalances[order.userId] ?? 0) + amount;
  }

  List<Trade> _matchOrder(Order newOrder, OrderBook orderBook) {
    final matches = <Trade>[];
    final oppositeSide = newOrder.side == 'BUY' ? orderBook.asks : orderBook.bids;
    
    oppositeSide.sort((a, b) => newOrder.side == 'BUY' 
        ? a.price.compareTo(b.price) 
        : b.price.compareTo(a.price));

    for (final existingOrder in oppositeSide.toList()) {
      if (_shouldStopMatching(newOrder, existingOrder)) break;
      
      final tradePrice = existingOrder.price;
      final tradeQuantity = min(
        newOrder.quantity - newOrder.filledQuantity,
        existingOrder.quantity - existingOrder.filledQuantity
      );

      if (tradeQuantity > 0) {
        final trade = Trade(
          tradeId: _generateTradeId(),
          pair: newOrder.pair,
          takerOrderId: newOrder.orderId,
          makerOrderId: existingOrder.orderId,
          takerId: newOrder.userId,
          makerId: existingOrder.userId,
          side: newOrder.side,
          quantity: tradeQuantity,
          price: tradePrice,
          fee: _calculateFee(tradeQuantity, tradePrice),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        matches.add(trade);
        
        _updateOrderFill(newOrder, tradeQuantity);
        _updateOrderFill(existingOrder, tradeQuantity);
        
        if (existingOrder.quantity == existingOrder.filledQuantity) {
          oppositeSide.remove(existingOrder);
        }
      }
    }

    return matches;
  }

  bool _shouldStopMatching(Order newOrder, Order existingOrder) {
    if (newOrder.orderType == 'MARKET') return false;
    return newOrder.side == 'BUY' 
        ? existingOrder.price > newOrder.price
        : existingOrder.price < newOrder.price;
  }

  void _executeTrades(List<Trade> trades, Order takerOrder) {
    for (final trade in trades) {
      _settleTrade(trade);
      _recordTrade(trade);
      _addToBlockchain(trade);
    }
  }

  void _settleTrade(Trade trade) {
    final baseAsset = trade.pair.split('/')[0];
    final quoteAsset = trade.pair.split('/')[1];
    
    if (trade.side == 'BUY') {
      _transferBalance(trade.makerId, trade.takerId, baseAsset, trade.quantity);
      _transferBalance(trade.takerId, trade.makerId, quoteAsset, trade.quantity * trade.price);
    } else {
      _transferBalance(trade.takerId, trade.makerId, baseAsset, trade.quantity);
      _transferBalance(trade.makerId, trade.takerId, quoteAsset, trade.quantity * trade.price);
    }
    
    _deductFees(trade);
  }

  void _transferBalance(String from, String to, String asset, int amount) {
    balances[from] = (balances[from] ?? 0) - amount;
    balances[to] = (balances[to] ?? 0) + amount;
  }

  void _deductFees(Trade trade) {
    final fee = trade.fee;
    final feeAsset = trade.side == 'BUY' ? trade.pair.split('/')[0] : trade.pair.split('/')[1];
    
    balances[trade.takerId] = (balances[trade.takerId] ?? 0) - fee;
  }

  void _recordTrade(Trade trade) {
    final tradeDoc = FirebaseFirestore.instance.collection('trades').doc(trade.tradeId);
    tradeDoc.set(trade.toJson());
  }

  void _addToBlockchain(Trade trade) {
    final transaction = MangoTransaction(
      sender: trade.makerId,
      receiver: trade.takerId,
      amount: trade.quantity,
      fee: trade.fee,
      nonce: _getNextNonce(trade.makerId),
      transactionId: trade.tradeId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(trade.timestamp),
    );
    
    blockchain.addTransaction(transaction);
  }

  void _addToOrderBook(Order order, OrderBook orderBook) {
    final side = order.side == 'BUY' ? orderBook.bids : orderBook.asks;
    side.add(order);
    _sortOrderBookSide(side, order.side);
  }

  void _sortOrderBookSide(List<Order> side, String orderSide) {
    side.sort((a, b) => orderSide == 'BUY' 
        ? b.price.compareTo(a.price) 
        : a.price.compareTo(b.price));
  }

  void _updateOrderFill(Order order, int fillQuantity) {
    order.filledQuantity += fillQuantity;
    if (order.filledQuantity >= order.quantity) {
      order.status = 'FILLED';
      _unlockBalanceForOrder(order);
    } else {
      order.status = 'PARTIALLY_FILLED';
    }
  }

  void _unlockBalanceForOrder(Order order) {
    final asset = order.side == 'BUY' 
        ? order.pair.split('/')[1] 
        : order.pair.split('/')[0];
    
    final lockedAmount = order.side == 'BUY' 
        ? order.quantity * order.price 
        : order.quantity;

    lockedBalances[order.userId] = (lockedBalances[order.userId] ?? 0) - lockedAmount;
  }

  void _updateUserOrders(Order order) {
    if (!userOrders.containsKey(order.userId)) {
      userOrders[order.userId] = [];
    }
    userOrders[order.userId]!.add(order);
  }

  int _getNextNonce(String userId) {
    return (blockchain.accountNonces[userId] ?? 0) + 1;
  }

  String _generateTradeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  int _calculateFee(int quantity, int price) {
    final tradeValue = quantity * price;
    return (tradeValue * 2) ~/ 1000;
  }

  OrderResponse cancelOrder(String orderId, String userId) {
    for (final orderBook in orderBooks.values) {
      final order = orderBook.bids.firstWhere((o) => o.orderId == orderId && o.userId == userId, 
          orElse: () => orderBook.asks.firstWhere((o) => o.orderId == orderId && o.userId == userId, 
          orElse: () => Order()));
      
      if (order.orderId.isNotEmpty) {
        orderBook.bids.remove(order);
        orderBook.asks.remove(order);
        _unlockBalanceForOrder(order);
        order.status = 'CANCELLED';
        
        return OrderResponse(success: true, message: 'Order cancelled');
      }
    }
    
    return OrderResponse(success: false, message: 'Order not found');
  }

  OrderBook getOrderBook(String pair) {
    return orderBooks[pair] ?? OrderBook(bids: [], asks: [], pair: pair);
  }

  List<Order> getUserOrders(String userId) {
    return userOrders[userId] ?? [];
  }

  List<Trade> getTradeHistory(String pair, {int limit = 100}) {
    return [];
  }
}

class OrderBook {
  List<Order> bids;
  List<Order> asks;
  String pair;
  
  OrderBook({required this.bids, required this.asks, required this.pair});
}

class Order {
  String orderId;
  String userId;
  String pair;
  String side;
  String orderType;
  int quantity;
  int price;
  int filledQuantity;
  String status;
  int timestamp;
  String signature;
  
  Order({
    this.orderId = '',
    this.userId = '',
    this.pair = '',
    this.side = '',
    this.orderType = '',
    this.quantity = 0,
    this.price = 0,
    this.filledQuantity = 0,
    this.status = 'PENDING',
    this.timestamp = 0,
    this.signature = '',
  });
  
  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'userId': userId,
    'pair': pair,
    'side': side,
    'orderType': orderType,
    'quantity': quantity,
    'price': price,
    'filledQuantity': filledQuantity,
    'status': status,
    'timestamp': timestamp,
    'signature': signature,
  };
}

class Trade {
  String tradeId;
  String pair;
  String takerOrderId;
  String makerOrderId;
  String takerId;
  String makerId;
  String side;
  int quantity;
  int price;
  int fee;
  int timestamp;
  
  Trade({
    required this.tradeId,
    required this.pair,
    required this.takerOrderId,
    required this.makerOrderId,
    required this.takerId,
    required this.makerId,
    required this.side,
    required this.quantity,
    required this.price,
    required this.fee,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'tradeId': tradeId,
    'pair': pair,
    'takerOrderId': takerOrderId,
    'makerOrderId': makerOrderId,
    'takerId': takerId,
    'makerId': makerId,
    'side': side,
    'quantity': quantity,
    'price': price,
    'fee': fee,
    'timestamp': timestamp,
  };
}

class OrderResponse {
  bool success;
  String message;
  String orderId;
  int filledQuantity;
  
  OrderResponse({
    required this.success,
    required this.message,
    this.orderId = '',
    this.filledQuantity = 0,
  });
}

