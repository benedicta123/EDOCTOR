import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  static String currency(num amount) {
    return _currencyFormat.format(amount).trim();
  }

  static String dateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
    } catch (_) {
      return isoString;
    }
  }

  static String date(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
    } catch (_) {
      return isoString;
    }
  }

  static String time(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm', 'fr_FR').format(date);
    } catch (_) {
      return isoString;
    }
  }
}
