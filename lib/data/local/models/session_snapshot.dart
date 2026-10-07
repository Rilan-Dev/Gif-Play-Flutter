class SessionSnapshot {
  const SessionSnapshot({
    required this.activeSpaceId,
    required this.activeDetailTabId,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  final String? activeSpaceId;
  final String? activeDetailTabId;
  final DateTime updatedAt;
  final int schemaVersion;
}
