class PaginatedResult<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int total;
  final int from;
  final int to;
  final int perPage;

  const PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.perPage,
  });

  bool get hasPreviousPage => currentPage > 1;
  bool get hasNextPage => currentPage < lastPage;

  static int _toInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawList = (json['data'] as List<dynamic>?) ?? [];
    final items = rawList
        .map((e) => itemParser(e as Map<String, dynamic>))
        .toList();

    return PaginatedResult<T>(
      data: items,
      currentPage: _toInt(json['current_page'], 1),
      lastPage: _toInt(json['last_page'], 1),
      total: _toInt(json['total'], items.length),
      from: _toInt(json['from'], items.isNotEmpty ? 1 : 0),
      to: _toInt(json['to'], items.length),
      perPage: _toInt(json['per_page'], items.isNotEmpty ? items.length : 15),
    );
  }
}
