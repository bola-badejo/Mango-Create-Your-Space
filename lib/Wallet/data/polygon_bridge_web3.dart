import 'dart:convert';
import 'dart:typed_data';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class PolygonBridge {
  final Web3Client _web3client;
  final String _rpcUrl;
  final EthereumAddress _tokenAddress;
  final EthereumAddress _routerAddress;
  late DeployedContract _tokenContract;
  late DeployedContract _routerContract;
  final Map<String, Credentials> _userCredentials;
  
  static const String polygonRpcUrl = 'https://polygon-rpc.com';
  static const String mumbaiRpcUrl = 'https://rpc-mumbai.maticvigil.com';
  static const String quickswapRouter = '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff';
  
  final bool testnet;
  
  PolygonBridge({this.testnet = false})
      : _rpcUrl = testnet ? mumbaiRpcUrl : polygonRpcUrl,
        _tokenAddress = EthereumAddress.fromHex('YOUR_TOKEN_ADDRESS_HERE'),
        _routerAddress = EthereumAddress.fromHex(quickswapRouter),
        _userCredentials = {},
        _web3client = Web3Client(testnet ? mumbaiRpcUrl : polygonRpcUrl, http.Client()) {
    _initializeContracts();
  }

  Future<void> _initializeContracts() async {
    _tokenContract = await _loadTokenContract();
    _routerContract = await _loadRouterContract();
  }

  Future<DeployedContract> _loadTokenContract() async {
    final abi = await _loadABI('assets/contracts/MangoToken.json');
    return DeployedContract(abi, _tokenAddress);
  }

  Future<DeployedContract> _loadRouterContract() async {
    final abi = await _loadABI('assets/contracts/IUniswapV2Router.json');
    return DeployedContract(abi, _routerAddress);
  }

  Future<ContractAbi> _loadABI(String path) async {
    try {
      final abiString = await rootBundle.loadString(path);
      final abiJson = jsonDecode(abiString);
      return ContractAbi.fromJson(jsonEncode(abiJson['abi']), 'Contract');
    } catch (e) {
      
      return _getFallbackABI();
    }
  }

  ContractAbi _getFallbackABI() {
    
    return ContractAbi.fromJson('''
      [
        {
          "constant": true,
          "inputs": [{"name": "_owner", "type": "address"}],
          "name": "balanceOf",
          "outputs": [{"name": "balance", "type": "uint256"}],
          "type": "function"
        },
        {
          "constant": false,
          "inputs": [
            {"name": "_to", "type": "address"},
            {"name": "_value", "type": "uint256"}
          ],
          "name": "transfer",
          "outputs": [{"name": "", "type": "bool"}],
          "type": "function"
        },
        {
          "constant": false,
          "inputs": [
            {"name": "_spender", "type": "address"},
            {"name": "_value", "type": "uint256"}
          ],
          "name": "approve",
          "outputs": [{"name": "", "type": "bool"}],
          "type": "function"
        }
      ]
    ''', 'MangoToken');
  }

  Future<String> transferTokens(String privateKey, String toAddress, BigInt amount) async {
    try {
      final credentials = await _getCredentials(privateKey);
      final transferFunction = _tokenContract.function('transfer');
      
      final transaction = Transaction.callContract(
        contract: _tokenContract,
        function: transferFunction,
        parameters: [EthereumAddress.fromHex(toAddress), amount],
      );
      
      final result = await _web3client.sendTransaction(
        credentials,
        transaction,
        chainId: testnet ? 80001 : 137,
      );
      
      await _waitForTransaction(result);
      return result;
    } catch (e) {
      throw Exception('Transfer failed: $e');
    }
  }

  Future<String> approveSpending(String privateKey, String spenderAddress, BigInt amount) async {
    try {
      final credentials = await _getCredentials(privateKey);
      final approveFunction = _tokenContract.function('approve');
      
      final transaction = Transaction.callContract(
        contract: _tokenContract,
        function: approveFunction,
        parameters: [EthereumAddress.fromHex(spenderAddress), amount],
      );
      
      final result = await _web3client.sendTransaction(
        credentials,
        transaction,
        chainId: testnet ? 80001 : 137,
      );
      
      await _waitForTransaction(result);
      return result;
    } catch (e) {
      throw Exception('Approve failed: $e');
    }
  }

  Future<String> addLiquidity(
    String privateKey,
    BigInt amountMNG,
    BigInt amountToken,
    BigInt minMNG,
    BigInt minToken,
    String to,
    int deadline,
  ) async {
    try {
      final credentials = await _getCredentials(privateKey);
      final addLiquidityFunction = _routerContract.function('addLiquidity');
      
      final transaction = Transaction.callContract(
        contract: _routerContract,
        function: addLiquidityFunction,
        parameters: [
          _tokenAddress,
          EthereumAddress.fromHex('TOKEN_ADDRESS_HERE'),
          amountMNG,
          amountToken,
          minMNG,
          minToken,
          EthereumAddress.fromHex(to),
          BigInt.from(deadline),
        ],
      );
      
      final result = await _web3client.sendTransaction(
        credentials,
        transaction,
        chainId: testnet ? 80001 : 137,
      );
      
      await _waitForTransaction(result);
      return result;
    } catch (e) {
      throw Exception('Add liquidity failed: $e');
    }
  }

  Future<String> swapExactTokensForTokens(
    String privateKey,
    BigInt amountIn,
    BigInt amountOutMin,
    List<String> path,
    String to,
    int deadline,
  ) async {
    try {
      final credentials = await _getCredentials(privateKey);
      final swapFunction = _routerContract.function('swapExactTokensForTokens');
      
      final pathAddresses = path.map((addr) => EthereumAddress.fromHex(addr)).toList();
      
      final transaction = Transaction.callContract(
        contract: _routerContract,
        function: swapFunction,
        parameters: [
          amountIn,
          amountOutMin,
          pathAddresses,
          EthereumAddress.fromHex(to),
          BigInt.from(deadline),
        ],
      );
      
      final result = await _web3client.sendTransaction(
        credentials,
        transaction,
        chainId: testnet ? 80001 : 137,
      );
      
      await _waitForTransaction(result);
      return result;
    } catch (e) {
      throw Exception('Swap failed: $e');
    }
  }

  Future<BigInt> getBalance(String address) async {
    try {
      final balanceOfFunction = _tokenContract.function('balanceOf');
      final result = await _web3client.call(
        contract: _tokenContract,
        function: balanceOfFunction,
        params: [EthereumAddress.fromHex(address)],
      );
      
      return result.first as BigInt;
    } catch (e) {
      print('Error getting balance: $e');
      return BigInt.zero;
    }
  }

  Future<BigInt> getPrice(String pairAddress) async {
    try {
      final pairContract = await _getPairContract(pairAddress);
      final getReservesFunction = pairContract.function('getReserves');
      
      final result = await _web3client.call(
        contract: pairContract,
        function: getReservesFunction,
        params: [],
      );
      
      final reserves = result[0] as List<dynamic>;
      final reserve0 = reserves[0] as BigInt;
      final reserve1 = reserves[1] as BigInt;
      
      if (reserve0 == BigInt.zero) return BigInt.zero;
      
      return reserve1 ~/ reserve0;
    } catch (e) {
      print('Error getting price: $e');
      return BigInt.zero;
    }
  }

  Future<DeployedContract> _getPairContract(String pairAddress) async {
    try {
      final abi = await _loadABI('assets/contracts/IUniswapV2Pair.json');
      return DeployedContract(abi, EthereumAddress.fromHex(pairAddress));
    } catch (e) {
      
      final fallbackAbi = ContractAbi.fromJson('''
        [
          {
            "constant": true,
            "inputs": [],
            "name": "getReserves",
            "outputs": [
              {"name": "_reserve0", "type": "uint112"},
              {"name": "_reserve1", "type": "uint112"},
              {"name": "_blockTimestampLast", "type": "uint32"}
            ],
            "type": "function"
          }
        ]
      ''', 'Pair');
      return DeployedContract(fallbackAbi, EthereumAddress.fromHex(pairAddress));
    }
  }

  Future<Credentials> _getCredentials(String privateKey) async {
    if (!_userCredentials.containsKey(privateKey)) {
      _userCredentials[privateKey] = EthPrivateKey.fromHex(privateKey);
    }
    return _userCredentials[privateKey]!;
  }

  Future<void> _waitForTransaction(String txHash) async {
    const maxAttempts = 10;
    const delay = Duration(seconds: 3);
    
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final receipt = await _web3client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status == true) return;
          throw Exception('Transaction failed');
        }
        await Future.delayed(delay);
      } catch (e) {
        print('Error checking transaction: $e');
        await Future.delayed(delay);
      }
    }
    
    throw Exception('Transaction timeout');
  }

  
  Future<BigInt> getGasPrice() async {
    try {
      final etherAmount = await _web3client.getGasPrice();
      return etherAmount.getInWei;
    } catch (e) {
      print('Error getting gas price: $e');
      return BigInt.from(30000000000); 
    }
  }
  
  Future<Map<String, dynamic>> getGasPriceDetailed() async {
    try {
      final gasPriceEther = await _web3client.getGasPrice();
      final gasPriceWei = gasPriceEther.getInWei;
      
      
      final estimatedPriorityFeeWei = gasPriceWei ~/ BigInt.from(10);
      final maxFeePerGasWei = gasPriceWei + estimatedPriorityFeeWei;
      
      return {
        'gasPrice': gasPriceWei,
        'maxFeePerGas': maxFeePerGasWei,
        'maxPriorityFeePerGas': estimatedPriorityFeeWei,
        'gasPriceGwei': _weiToGwei(gasPriceWei),
        'maxFeePerGasGwei': _weiToGwei(maxFeePerGasWei),
        'maxPriorityFeePerGasGwei': _weiToGwei(estimatedPriorityFeeWei),
      };
    } catch (e) {
      print('Error getting detailed gas price: $e');
      final fallbackWei = BigInt.from(30000000000);
      final fallbackPriorityWei = BigInt.from(3000000000);
      return {
        'gasPrice': fallbackWei,
        'maxFeePerGas': fallbackWei + fallbackPriorityWei,
        'maxPriorityFeePerGas': fallbackPriorityWei,
        'gasPriceGwei': _weiToGwei(fallbackWei),
        'maxFeePerGasGwei': _weiToGwei(fallbackWei + fallbackPriorityWei),
        'maxPriorityFeePerGasGwei': _weiToGwei(fallbackPriorityWei),
      };
    }
  }

  
  Future<BigInt> estimateGas({
    required String from,
    required String to,
    required BigInt value,
    required String data,
  }) async {
    try {
      final gasAmount = await _web3client.estimateGas(
        sender: EthereumAddress.fromHex(from),
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.fromUnitAndValue(EtherUnit.wei, value),
        data: Uint8List.fromList(_hexToBytes(data)),
      );
      return gasAmount;
    } catch (e) {
      print('Error estimating gas: $e');
      return BigInt.from(21000); 
    }
  }

  
  List<int> _hexToBytes(String hex) {
    hex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  
  double _weiToGwei(BigInt wei) {
    return wei.toDouble() / 1000000000; 
  }

  
  BigInt _gweiToWei(double gwei) {
    return BigInt.from((gwei * 1000000000).toInt());
  }

  
  BigInt mngToWei(Decimal amount) {
    return BigInt.from(amount.toSatoshis().toInt());
  }

  Decimal weiToMng(BigInt wei) {
    return Decimal.fromBigInt(wei);
  }

  
  Future<String> sendEther(
    String privateKey,
    String toAddress,
    Decimal amount,
  ) async {
    try {
      final credentials = await _getCredentials(privateKey);
      final weiAmount = mngToWei(amount);
      final etherAmount = EtherAmount.fromUnitAndValue(EtherUnit.wei, weiAmount);
      
      final transaction = Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: etherAmount,
      );
      
      final result = await _web3client.sendTransaction(
        credentials,
        transaction,
        chainId: testnet ? 80001 : 137,
      );
      
      await _waitForTransaction(result);
      return result;
    } catch (e) {
      throw Exception('Send ETH failed: $e');
    }
  }

  
  Future<Decimal> getEtherBalance(String address) async {
    try {
      final balance = await _web3client.getBalance(EthereumAddress.fromHex(address));
      return Decimal.fromBigInt(balance.getInWei);
    } catch (e) {
      print('Error getting ETH balance: $e');
      return Decimal.zero;
    }
  }

  
  Future<bool> hasEnoughForGas(String address, {double requiredGwei = 0.01}) async {
    try {
      final ethBalance = await getEtherBalance(address);
      final requiredWei = _gweiToWei(requiredGwei);
      return ethBalance.toSatoshis() >= requiredWei;
    } catch (e) {
      print('Error checking gas balance: $e');
      return false;
    }
  }

  
  Future<Decimal> estimateTransactionCost({
    required BigInt gasLimit,
    required BigInt gasPriceWei,
  }) async {
    final totalWei = gasLimit * gasPriceWei;
    return Decimal.fromBigInt(totalWei);
  }

  
  Future<int> getNetworkId() async {
    try {
      return await _web3client.getNetworkId();
    } catch (e) {
      print('Error getting network ID: $e');
      return testnet ? 80001 : 137;
    }
  }

  
  Future<int> getTransactionCount(String address) async {
    try {
      return await _web3client.getTransactionCount(EthereumAddress.fromHex(address));
    } catch (e) {
      print('Error getting transaction count: $e');
      return 0;
    }
  }

  
  Future<TransactionInformation?> getTransaction(String txHash) async {
    try {
      return await _web3client.getTransactionByHash(txHash);
    } catch (e) {
      print('Error getting transaction: $e');
      return null;
    }
  }

  void dispose() {
    _web3client.dispose();
  }
}


