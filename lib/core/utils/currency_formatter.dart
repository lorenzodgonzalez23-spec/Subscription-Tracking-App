import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static String format(double amount, String code) {
    final symbol = switch (code) {
      'PHP' => '₱',
      'USD' => r'$',
      'EUR' => '€',
      'JPY' => '¥',
      'GBP' => '£',
      'SGD' => 'S\$',
      _ => '$code ',
    };
    return '$symbol${NumberFormat('#,##0.00', 'en_PH').format(amount)}';
  }
}
