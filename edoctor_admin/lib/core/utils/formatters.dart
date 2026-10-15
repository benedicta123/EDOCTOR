import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy à HH:mm');

  static String formatCurrency(num? amount) {
    if (amount == null) return '0 FCFA';
    return '${_currencyFormat.format(amount).replaceAll(',', ' ')} FCFA';
  }

  static String formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return _dateFormat.format(dt);
  }

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return _dateTimeFormat.format(dt);
  }

  static String formatRelative(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return formatDate(dt);
  }
}
