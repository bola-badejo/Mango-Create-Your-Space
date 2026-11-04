
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:mango/Wallet/services/wallet_services.dart';
import 'decimal.dart';

class CurrencyService extends GetxService {
  final Map<String, double> _exchangeRates = {};
  final Map<String, String> _currencySymbols = {
    'USD': '\$', 'NGN': '₦', 'EUR': '€', 'GBP': '£', 'MNG': 'MNG',
  };

  
  static const String mangoGasFeeAddress = 'mango_gas_fee_collection';
  
  @override
  Future<void> onInit() async {
    await _fetchPolygonExchangeRates();
    
    
    super.onInit();
  }

  Future<void> _fetchPolygonExchangeRates() async {
    try {
      
      final responses = await Future.wait([
        _fetchMaticPrice(),
        _fetchPolygonGasPrices(),
      ]);

      final maticPrice = responses[0];
      final gasData = responses[1];

      if (maticPrice != null) {
        
        final double mngToMaticRatio = 0.1; 
        
        _exchangeRates['USD'] = (maticPrice['usd'] ?? 0.70) * mngToMaticRatio;
        _exchangeRates['NGN'] = (maticPrice['ngn'] ?? 1050.0) * mngToMaticRatio;
        _exchangeRates['EUR'] = (maticPrice['eur'] ?? 0.65) * mngToMaticRatio;
        _exchangeRates['GBP'] = (maticPrice['gbp'] ?? 0.55) * mngToMaticRatio;
        
        print('Polygon-based exchange rates updated: $_exchangeRates');
      }

    } catch (e) {
      print('Error fetching Polygon rates: $e');
      _setConservativeRates();
    }
  }

  Future<Map<String, double>?> _fetchMaticPrice() async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=matic-network&vs_currencies=usd,ngn,eur,gbp'
      )).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'usd': data['matic-network']['usd']?.toDouble(),
          'ngn': data['matic-network']['ngn']?.toDouble(),
          'eur': data['matic-network']['eur']?.toDouble(),
          'gbp': data['matic-network']['gbp']?.toDouble(),
        };
      }
    } catch (e) {
      print('Matic price fetch failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchPolygonGasPrices() async {
    try {
      final response = await http.get(Uri.parse(
        'https://gasstation-mainnet.matic.network/v2'
      )).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Polygon gas price fetch failed: $e');
    }
    return null;
  }

  void _setConservativeRates() {
    
    _exchangeRates['USD'] = 0.07;   
    _exchangeRates['NGN'] = 105.0;  
    _exchangeRates['EUR'] = 0.065;  
    _exchangeRates['GBP'] = 0.055;  
  }

  
  Decimal calculateGasFee(TransactionType txType) {
    
    switch (txType) {
      case TransactionType.transfer:
        return Decimal.fromDouble(0.001);
      case TransactionType.mining:
        return Decimal.fromDouble(0.0005);
      case TransactionType.trade:
        return Decimal.fromDouble(0.002);
      case TransactionType.nft:
        return Decimal.fromDouble(0.005);
      default:
        return Decimal.fromDouble(0.001);
    }
  }

  
  Future<void> collectGasFee(TransactionType txType, String userId) async {
    final gasFee = calculateGasFee(txType);
    
    
    final walletService = Get.find<WalletService>();
    await walletService.transferMangoCoins(
      receiverAddress: mangoGasFeeAddress,
      amount: gasFee,
      memo: 'Gas fee for ${txType.name}',
    );
  }

  Map<String, String> getCurrencyValues(Decimal mngAmount) {
    if (_exchangeRates.isEmpty) {
      return {
        'MNG': '${mngAmount.toFixed(6)} MNG',
        'USD': 'Fetching rates...',
        'NGN': 'Fetching rates...',
        'EUR': 'Fetching rates...',
        'GBP': 'Fetching rates...',
      };
    }

    return {
      'MNG': '${mngAmount.toFixed(6)} MNG',
      'USD': _formatCurrency(mngAmount, 'USD'),
      'NGN': _formatCurrency(mngAmount, 'NGN'),
      'EUR': _formatCurrency(mngAmount, 'EUR'),
      'GBP': _formatCurrency(mngAmount, 'GBP'),
    };
  }

  String _formatCurrency(Decimal amount, String currency) {
    final symbol = _currencySymbols[currency] ?? currency;
    final rate = _exchangeRates[currency] ?? 1.0;
    final localAmount = amount * Decimal.fromDouble(rate);

    switch (currency) {
      case 'USD':
      case 'EUR':
      case 'GBP':
        return '$symbol${localAmount.toFixed(4)}';
      case 'NGN':
        return '$symbol${localAmount.toFixed(2)}';
      case 'MNG':
        return '${amount.toFixed(6)} $symbol';
      default:
        return '${localAmount.toFixed(2)} $currency';
    }
  }

  
  Map<String, dynamic> getNetworkInfo() {
    return {
      'network': 'Polygon Mainnet',
      'token_standard': 'ERC-20',
      'gas_token': 'MATIC',
      'block_explorer': 'https://polygonscan.com',
      'exchange_rates': _exchangeRates,
    };
  }

  String getValueDisclaimer() {
    return 'Mango tokens (MNG) are utility tokens on Polygon network. '
           'Displayed values are estimates based on MATIC pricing. '
           'Gas fees support network operations and go to Mango ecosystem.';
  }
}