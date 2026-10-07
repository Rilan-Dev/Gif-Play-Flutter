class BrowsingSpace {
  const BrowsingSpace({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.feedType = 'home',
    this.feedPage,
    this.feedStateJson,
    this.searchQuery,
    this.filterStateJson,
    this.scrollOffset,
    this.activeDetailTabId,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String feedType;
  final int? feedPage;
  final String? feedStateJson;
  final String? searchQuery;
  final String? filterStateJson;
  final double? scrollOffset;
  final String? activeDetailTabId;
  final int sortOrder;
}
