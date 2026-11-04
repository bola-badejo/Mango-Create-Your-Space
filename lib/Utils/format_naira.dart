import 'package:intl/intl.dart';

String formatNaira(dynamic price) {
  
  final doubleValue = double.tryParse(price.toString()) ?? 0.0;

  
  if (doubleValue == 0) return 'Free';

  
  final formatter = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0, 
  );

  return formatter.format(doubleValue);
}
