class EuniceHelper {
  static const int decimals = 8;
  static const int euniceFactor = 100000000;
  
  static int toEunice(double coins) {
    return (coins * euniceFactor).round();
  }
  
  static double toCoin(int eunices) {
    return eunices / euniceFactor;
  }
  
  static String format(int eunices) {
    return toCoin(eunices).toStringAsFixed(decimals);
  }
  
  static String formatClean(int eunices) {
    String formatted = toCoin(eunices).toStringAsFixed(decimals);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }
  
  static int parse(String coinString) {
    double coins = double.tryParse(coinString) ?? 0.0;
    return toEunice(coins);
  }
}

