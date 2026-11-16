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
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      total: json['total'] as int? ?? items.length,
      from: json['from'] as int? ?? (items.isNotEmpty ? 1 : 0),
      to: json['to'] as int? ?? items.length,
      perPage: json['per_page'] as int? ?? (items.isNotEmpty ? items.length : 15),
    );
  }
}
