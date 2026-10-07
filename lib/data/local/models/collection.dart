class GifCollection {
  const GifCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.sortOrder = 0,
    this.isArchived = false,
  });
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int sortOrder;
  final bool isArchived;
}
